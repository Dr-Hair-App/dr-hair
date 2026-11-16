import 'assistant_chat_message.dart';

class AssistantChatThread {
  const AssistantChatThread({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final List<AssistantChatMessage> messages;

  bool get hasAssistantReply => messages.any(
    (message) => !message.isUser && message.content.trim().isNotEmpty,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((message) => message.toStorageJson()).toList(),
  };

  factory AssistantChatThread.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final messages = rawMessages is List
        ? rawMessages
              .whereType<Map>()
              .map(
                (item) => AssistantChatMessage.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((message) => message.content.trim().isNotEmpty)
              .toList(growable: false)
        : const <AssistantChatMessage>[];
    return AssistantChatThread(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Hair care chat',
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      messages: messages,
    );
  }
}
