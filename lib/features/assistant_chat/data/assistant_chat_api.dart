import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../domain/assistant_chat_message.dart';

abstract interface class AssistantChatClient {
  Stream<AssistantChatEvent> streamReply(List<AssistantChatMessage> messages);
}

sealed class AssistantChatEvent {
  const AssistantChatEvent();
}

class AssistantChatTextDelta extends AssistantChatEvent {
  const AssistantChatTextDelta(this.text);
  final String text;
}

class AssistantChatActionProposal extends AssistantChatEvent {
  const AssistantChatActionProposal(this.action);
  final Map<String, dynamic> action;
}

class AssistantChatException implements Exception {
  const AssistantChatException(this.message, {this.retryAfter});

  final String message;
  final Duration? retryAfter;

  @override
  String toString() => message;
}

class AssistantChatApi implements AssistantChatClient {
  AssistantChatApi({Dio? dio})
    : _dio =
          dio ??
          DioClient(
            customDio: Dio(
              BaseOptions(
                baseUrl: ApiEndpoints.backendBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 65),
                sendTimeout: const Duration(seconds: 15),
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'text/event-stream',
                },
              ),
            ),
            enableDebugLogging: false,
          ).dio;

  final Dio _dio;

  @override
  Stream<AssistantChatEvent> streamReply(
    List<AssistantChatMessage> messages,
  ) async* {
    final cancelToken = CancelToken();
    var completed = false;
    try {
      final response = await _dio.post<ResponseBody>(
        ApiEndpoints.patientAssistantChat,
        data: {
          'messages': messages
              .map((message) => message.toJson())
              .toList(growable: false),
        },
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: const {'Accept': 'text/event-stream'},
          extra: const {'silent': true},
        ),
      );
      final body = response.data;
      if (body == null) {
        throw const AssistantChatException(
          'The assistant returned an empty response. Please try again.',
        );
      }

      await for (final line
          in utf8.decoder.bind(body.stream).transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final rawEvent = line.substring(5).trim();
        if (rawEvent.isEmpty || rawEvent == '[DONE]') continue;

        final dynamic event;
        try {
          event = jsonDecode(rawEvent);
        } on FormatException {
          continue;
        }
        if (event is! Map) continue;
        switch (event['type']) {
          case 'delta':
            final text = event['text'];
            if (text is String && text.isNotEmpty) {
              yield AssistantChatTextDelta(text);
            }
          case 'action':
            final action = event['action'];
            if (action is Map) {
              yield AssistantChatActionProposal(
                Map<String, dynamic>.from(action),
              );
            }
          case 'done':
            completed = true;
          case 'error':
            final retryAfterSeconds = event['retryAfterSeconds'];
            throw AssistantChatException(
              event['message']?.toString() ?? 'The assistant could not finish this reply. Please try again.',
              retryAfter: retryAfterSeconds is num
                  ? Duration(seconds: retryAfterSeconds.toInt())
                  : null,
            );
        }
      }
      if (!completed) {
        throw const AssistantChatException(
          'The chat stream ended early. Please retry your message.',
        );
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      final status = error.response?.statusCode;
      if (status == 429) {
        throw const AssistantChatException(
          'You have sent several messages. Please wait a minute and try again.',
          retryAfter: Duration(minutes: 1),
        );
      }
      if (status == 401 || status == 403) {
        throw const AssistantChatException(
          'Please sign in again to use the assistant.',
        );
      }
      throw const AssistantChatException(
        'The assistant is temporarily unavailable. Check your connection and retry.',
      );
    } finally {
      if (!cancelToken.isCancelled) cancelToken.cancel('Chat stream finished.');
    }
  }
}
