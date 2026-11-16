class AssistantChatMessage {
  const AssistantChatMessage({
    required this.role,
    required this.content,
    this.action,
  });

  final String role;
  final String content;
  final Map<String, dynamic>? action;

  bool get isUser => role == 'user';

  Map<String, String> toJson() => {'role': role, 'content': content};

  Map<String, dynamic> toStorageJson() => {
    ...toJson(),
    if (action != null) 'action': action,
  };

  factory AssistantChatMessage.fromJson(Map<String, dynamic> json) =>
      AssistantChatMessage(
        role: json['role']?.toString() ?? 'user',
        content: json['content']?.toString() ?? '',
        action: json['action'] is Map
            ? Map<String, dynamic>.from(json['action'] as Map)
            : null,
      );
}
