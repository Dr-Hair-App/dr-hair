import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dr_hair/features/assistant_chat/data/assistant_chat_api.dart';
import 'package:dr_hair/features/assistant_chat/domain/assistant_chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedResponseAdapter implements HttpClientAdapter {
  _FixedResponseAdapter(this.statusCode, this.body, {this.contentType});

  final int statusCode;
  final String body;
  final String? contentType;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final responseHeaders = <String, List<String>>{};
    if (contentType != null) {
      responseHeaders[Headers.contentTypeHeader] = [contentType!];
    }
    return ResponseBody.fromString(body, statusCode, headers: responseHeaders);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWithAdapter(HttpClientAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://assistant.test',
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2),
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

const _messages = [
  AssistantChatMessage(role: 'user', content: 'Could my scalp be dry?'),
];

void main() {
  test(
    'decodes server-sent event chunks and posts bounded conversation data',
    () async {
      final adapter = _FixedResponseAdapter(
        200,
        ': assistant stream ready\r\n\r\n'
        'data: {"type":"delta","text":"A little "}\r\n\r\n'
        'data: {"type":"delta","text":"at a time."}\r\n\r\n'
        'data: {"type":"done"}\r\n\r\n',
        contentType: 'text/event-stream',
      );
      final api = AssistantChatApi(dio: _dioWithAdapter(adapter));

      final chunks = await api.streamReply(_messages).toList();

      expect(
        chunks.map((event) => (event as AssistantChatTextDelta).text).toList(),
        ['A little ', 'at a time.'],
      );
      expect(adapter.lastRequest?.method, 'POST');
      expect(adapter.lastRequest?.path, '/api/v1/patient/assistant/chat');
      expect(adapter.lastRequest?.headers['Accept'], 'text/event-stream');
      expect(adapter.lastRequest?.data, {
        'messages': [
          {'role': 'user', 'content': 'Could my scalp be dry?'},
        ],
      });
    },
  );

  test('decodes user-confirmed AI app action proposals', () async {
    final adapter = _FixedResponseAdapter(
      200,
      'data: {"type":"action","action":{"kind":"navigate","screen":"settings","message":"I can open settings."}}\n\n'
      'data: {"type":"done"}\n\n',
      contentType: 'text/event-stream',
    );
    final events = await AssistantChatApi(dio: _dioWithAdapter(adapter))
        .streamReply(_messages)
        .toList();

    expect(events, hasLength(1));
    expect(events.single, isA<AssistantChatActionProposal>());
    expect(
      (events.single as AssistantChatActionProposal).action['screen'],
      'settings',
    );
  });

  test('turns SSE error events into a safe chat exception', () async {
    final adapter = _FixedResponseAdapter(
      200,
      'data: {"type":"error","message":"The assistant is temporarily unavailable."}\n\n',
      contentType: 'text/event-stream',
    );
    final api = AssistantChatApi(dio: _dioWithAdapter(adapter));

    await expectLater(
      api.streamReply(_messages).toList(),
      throwsA(
        isA<AssistantChatException>().having(
          (error) => error.message,
          'message',
          'The assistant is temporarily unavailable.',
        ),
      ),
    );
  });

  test('reports an interrupted stream instead of treating partial text as complete', () async {
    final adapter = _FixedResponseAdapter(
      200,
      'data: {"type":"delta","text":"Partial answer"}\n\n',
      contentType: 'text/event-stream',
    );
    final api = AssistantChatApi(dio: _dioWithAdapter(adapter));

    await expectLater(
      api.streamReply(_messages).toList(),
      throwsA(
        isA<AssistantChatException>().having(
          (error) => error.message,
          'message',
          contains('ended early'),
        ),
      ),
    );
  });

  test('maps per-patient rate limits to a retry-later message', () async {
    final adapter = _FixedResponseAdapter(
      429,
      '{"status":"error","message":"Rate limited"}',
      contentType: 'application/json',
    );
    final api = AssistantChatApi(dio: _dioWithAdapter(adapter));

    await expectLater(
      api.streamReply(_messages).toList(),
      throwsA(
        isA<AssistantChatException>().having(
          (error) => error.message,
          'message',
          contains('wait a minute'),
        ),
      ),
    );
  });
}
