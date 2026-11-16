import 'dart:convert';

import '../../../../core/storage/app_local_cache.dart';
import '../domain/assistant_chat_message.dart';
import '../domain/assistant_chat_thread.dart';

class AssistantChatHistoryStore {
  AssistantChatHistoryStore({required this.patientId});

  final String patientId;

  String get _threadsKey =>
      AppLocalCache.patientKey(patientId, 'assistant_chat_threads_v1');

  String get _legacyKey =>
      AppLocalCache.patientKey(patientId, 'assistant_chat_history_v1');

  List<AssistantChatThread> load() {
    try {
      final raw = AppLocalCache.instance.getString(_threadsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map(
                (item) => AssistantChatThread.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((thread) => thread.hasAssistantReply)
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        }
      }

      final legacy = AppLocalCache.instance.getString(_legacyKey);
      if (legacy == null || legacy.isEmpty) return const [];
      final decodedLegacy = jsonDecode(legacy);
      if (decodedLegacy is! List) return const [];
      final messages = decodedLegacy
          .whereType<Map>()
          .map(
            (item) =>
                AssistantChatMessage.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((message) => message.content.trim().isNotEmpty)
          .toList(growable: false);
      if (!messages.any((message) => !message.isUser)) return const [];
      return [
        AssistantChatThread(
          id: 'legacy-${DateTime.now().millisecondsSinceEpoch}',
          title: _titleFrom(messages),
          updatedAt: DateTime.now(),
          messages: messages,
        ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(AssistantChatThread thread) async {
    if (!thread.hasAssistantReply) return;
    final threads =
        load().where((saved) => saved.id != thread.id).toList(growable: true)
          ..insert(0, thread)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final bounded = threads.take(30).map((item) => item.toJson()).toList();
    await AppLocalCache.instance.put(_threadsKey, jsonEncode(bounded));
    await AppLocalCache.instance.remove(_legacyKey);
  }

  Future<void> delete(String id) async {
    final remaining = load().where((thread) => thread.id != id).toList();
    await AppLocalCache.instance.put(
      _threadsKey,
      jsonEncode(remaining.map((thread) => thread.toJson()).toList()),
    );
  }

  AssistantChatThread? find(String id) {
    for (final thread in load()) {
      if (thread.id == id) return thread;
    }
    return null;
  }

  static String _titleFrom(List<AssistantChatMessage> messages) {
    final firstQuestion = messages.firstWhere(
      (message) => message.isUser,
      orElse: () => const AssistantChatMessage(role: 'user', content: ''),
    );
    final title = firstQuestion.content.trim().replaceAll(RegExp(r'\s+'), ' ');
    return title.length > 54 ? '${title.substring(0, 51)}…' : title;
  }
}
