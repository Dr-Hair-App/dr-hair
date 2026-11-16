import 'package:dr_hair/core/storage/app_local_cache.dart';
import 'package:dr_hair/features/assistant_chat/data/assistant_chat_api.dart';
import 'package:dr_hair/features/assistant_chat/domain/assistant_chat_message.dart';
import 'package:dr_hair/features/assistant_chat/presentation/views/assistant_chat_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAssistantChatClient implements AssistantChatClient {
  List<AssistantChatMessage>? lastMessages;

  @override
  Stream<AssistantChatEvent> streamReply(
    List<AssistantChatMessage> messages,
  ) async* {
    lastMessages = messages;
    yield const AssistantChatTextDelta('A few common causes can include ');
    yield const AssistantChatTextDelta('dry air and irritating hair products.');
  }
}

class _FailOnceAssistantChatClient implements AssistantChatClient {
  int calls = 0;
  List<AssistantChatMessage>? lastMessages;

  @override
  Stream<AssistantChatEvent> streamReply(
    List<AssistantChatMessage> messages,
  ) async* {
    calls += 1;
    lastMessages = messages;
    if (calls == 1) {
      throw const AssistantChatException('Temporary assistant error');
    }
    yield const AssistantChatTextDelta('I am back.');
  }
}

void main() {
  setUp(() async {
    await AppLocalCache.instance.clearAll();
  });
  testWidgets(
    'assistant sheet streams replies and supports suggested questions',
    (tester) async {
      final client = _FakeAssistantChatClient();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showAssistantChatSheet(context, client: client),
                child: const Text('Open assistant'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open assistant'));
      await tester.pumpAndSettle();
      expect(find.text('Dr. Hair Assistant'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/WhiteLogo.png',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('not a diagnosis or prescription'),
        findsOneWidget,
      );

      await tester.drag(find.byType(ListView), const Offset(0, -150));
      await tester.pumpAndSettle();

      await tester.tap(find.text('What can cause dry scalp?'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('What can cause dry scalp?'), findsOneWidget);
      expect(
        find.text(
          'A few common causes can include dry air and irritating hair products.',
        ),
        findsOneWidget,
      );
      expect(client.lastMessages?.last.role, 'user');
    },
  );

  testWidgets('assistant text can be sent from the composer', (tester) async {
    final client = _FakeAssistantChatClient();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AssistantChatView(client: client)),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'Suggest a simple hair routine',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Suggest a simple hair routine'), findsOneWidget);
    expect(
      find.textContaining('dry air and irritating hair products'),
      findsOneWidget,
    );
    expect(
      client.lastMessages?.single.content,
      'Suggest a simple hair routine',
    );
  });

  testWidgets(
    'failed replies can be retried without duplicating the question',
    (tester) async {
      final client = _FailOnceAssistantChatClient();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AssistantChatView(client: client)),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Can I ask again?');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Temporary assistant error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(client.calls, 2);
      expect(client.lastMessages, hasLength(1));
      expect(client.lastMessages!.single.content, 'Can I ask again?');
      expect(find.text('I am back.'), findsOneWidget);
    },
  );

  testWidgets(
    'a new question after a failed reply keeps the conversation valid',
    (tester) async {
      final client = _FailOnceAssistantChatClient();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AssistantChatView(client: client)),
        ),
      );

      await tester.enterText(find.byType(TextField), 'First question');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Temporary assistant error'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'A different question');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(client.calls, 2);
      expect(client.lastMessages, hasLength(1));
      expect(client.lastMessages!.single.role, 'user');
      expect(client.lastMessages!.single.content, 'A different question');
      expect(find.text('I am back.'), findsOneWidget);
    },
  );

  testWidgets(
    'chat composer remains usable on a narrow screen with keyboard inset',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantChatView(client: _FakeAssistantChatClient()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Send message'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'allows switching language to Hindi and sends language directive in request',
    (tester) async {
      final client = _FakeAssistantChatClient();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AssistantChatView(client: client)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preferred Language / पसंदीदा भाषा'), findsOneWidget);
      expect(find.text('🇮🇳 हिंदी'), findsWidgets);

      // Tap Hindi option in language selector bar
      await tester.tap(find.text('🇮🇳 हिंदी').first);
      await tester.pumpAndSettle();

      // Suggestions should now be in Hindi
      expect(
        find.text('सूखी खोपड़ी (dry scalp) और डैंड्रफ के क्या कारण हैं?'),
        findsOneWidget,
      );

      // Tap suggestion
      await tester.tap(
        find.text('सूखी खोपड़ी (dry scalp) और डैंड्रफ के क्या कारण हैं?'),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        client.lastMessages?.last.content,
        contains('[Reply strictly in Hindi (हिंदी)]'),
      );
      expect(
        client.lastMessages?.last.content,
        contains('सूखी खोपड़ी (dry scalp) और डैंड्रफ के क्या कारण हैं?'),
      );
    },
  );

  testWidgets(
    'restores previous chat history from local cache and renders messages',
    (tester) async {
      final client = _FakeAssistantChatClient();
      // Seed memory store in AppLocalCache
      final seededHistory =
          '[{"role":"user","content":"Previous question"},{"role":"assistant","content":"Previous answer"}]';
      await AppLocalCache.instance.put(
        'assistant_chat_history_v1',
        seededHistory,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AssistantChatView(client: client)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Previous question'), findsOneWidget);
      expect(find.text('Previous answer'), findsOneWidget);
    },
  );
}
