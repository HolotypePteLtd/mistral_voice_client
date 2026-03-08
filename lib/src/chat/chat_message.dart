/// A message in a chat conversation.
class ChatMessage {
  /// The role of the message author. Must be one of: system, user, assistant.
  final String role;

  /// The content of the message.
  /// Can be a [String] for text-only messages, or a [List] of content parts
  /// for multimodal messages (e.g. audio + text).
  final dynamic content;

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

  /// Creates a multimodal message with a list of content parts.
  ///
  /// Each part is a map like `{"type": "text", "text": "..."}` or
  /// `{"type": "input_audio", "input_audio": "<base64>"}`.
  factory ChatMessage.multimodal({
    required String role,
    required List<Map<String, dynamic>> parts,
    String? name,
  }) =>
      ChatMessage(role: role, content: parts, name: name);

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    if (name != null) 'name': name,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'],
      name: json['name'] as String?,
    );
  }

  @override
  String toString() {
    final preview = content is String
        ? (content.length > 50 ? '${content.substring(0, 50)}...' : content)
        : '[${(content as List).length} parts]';
    return 'ChatMessage($role: $preview)';
  }
}
