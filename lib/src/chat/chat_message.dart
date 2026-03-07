/// A message in a chat conversation.
class ChatMessage {
  /// The role of the message author. Must be one of: system, user, assistant.
  final String role;

  /// The content of the message.
  final String content;

  /// Optional name for the message author (used for multi-turn conversations).
  final String? name;

  const ChatMessage({
    required this.role,
    required this.content,
    this.name,
  });

  factory ChatMessage.system(String content) => ChatMessage(role: 'system', content: content);
  factory ChatMessage.user(String content) => ChatMessage(role: 'user', content: content);
  factory ChatMessage.assistant(String content) => ChatMessage(role: 'assistant', content: content);

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    if (name != null) 'name': name,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      name: json['name'] as String?,
    );
  }

  @override
  String toString() => 'ChatMessage($role: ${content.length > 50 ? "${content.substring(0, 50)}..." : content})';
}
