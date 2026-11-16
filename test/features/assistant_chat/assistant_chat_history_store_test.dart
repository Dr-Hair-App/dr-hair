import 'package:dr_hair/core/storage/app_local_cache.dart';
import 'package:dr_hair/features/assistant_chat/data/assistant_chat_history_store.dart';
import 'package:dr_hair/features/assistant_chat/domain/assistant_chat_message.dart';
import 'package:dr_hair/features/assistant_chat/domain/assistant_chat_thread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async => AppLocalCache.instance.clearAll());

  test('does not store empty or user-only conversations', () async {
    final store = AssistantChatHistoryStore(patientId: 'patient-17');
    final empty = AssistantChatThread(
      id: 'empty',
      title: '',
      updatedAt: DateTime.now(),
      messages: const [],
    );
    final userOnly = AssistantChatThread(
      id: 'incomplete',
      title: 'Unanswered question',
      updatedAt: DateTime.now(),
      messages: const [
        AssistantChatMessage(role: 'user', content: 'Why is my scalp dry?'),
      ],
    );

    await store.save(empty);
    await store.save(userOnly);

    expect(store.load(), isEmpty);
  });

  test(
    'stores replies under the patient and can reopen/delete a thread',
    () async {
      final store = AssistantChatHistoryStore(patientId: 'patient-17');
      final thread = AssistantChatThread(
        id: 'thread-1',
        title: 'Scalp care question',
        updatedAt: DateTime.now(),
        messages: const [
          AssistantChatMessage(role: 'user', content: 'Why is my scalp dry?'),
          AssistantChatMessage(
            role: 'assistant',
            content: 'Dry air can be one possible cause.',
          ),
        ],
      );

      await store.save(thread);
      expect(store.load(), hasLength(1));
      expect(store.find('thread-1')?.messages, hasLength(2));
      expect(
        AppLocalCache.instance.getString('assistant_chat_threads_v1'),
        isNull,
      );

      await store.delete('thread-1');
      expect(store.load(), isEmpty);
    },
  );
}
