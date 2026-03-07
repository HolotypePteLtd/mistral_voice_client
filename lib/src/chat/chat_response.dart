import '../models/usage.dart';
import 'chat_message.dart';

/// A single choice in the chat completion response.
class ChatChoice {
  /// The index of this choice.
  final int index;

  /// The generated message.
  final ChatMessage message;

  /// Reason for finishing (e.g., 'stop', 'length').
  final String? finishReason;

  const ChatChoice({
    required this.index,
    required this.message,
    this.finishReason,
  });

  factory ChatChoice.fromJson(Map<String, dynamic> json) {
    final messageData = json['message'] as Map<String, dynamic>;
    return ChatChoice(
      index: json['index'] as int,
      message: ChatMessage.fromJson(messageData),
      finishReason: json['finish_reason'] as String?,
    );
  }
}

/// Response from the Mistral chat completions API.
class ChatResponse {
  /// The ID of the response.
  final String id;

  /// The object type (e.g., 'chat.completion').
  final String object;

  /// Unix timestamp of when the response was created.
  final int created;

  /// The model used for completion.
  final String model;

  /// The list of choices (generated messages).
  final List<ChatChoice> choices;

  /// API usage information.
  final MistralUsage? usage;

  const ChatResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
    this.usage,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    final choicesData = json['choices'] as List<dynamic>;
    final choices = choicesData
        .map((c) => ChatChoice.fromJson(c as Map<String, dynamic>))
        .toList();

    final usageData = json['usage'] as Map<String, dynamic>?;

    return ChatResponse(
      id: json['id'] as String,
      object: json['object'] as String,
      created: json['created'] as int,
      model: json['model'] as String,
      choices: choices,
      usage: usageData != null ? MistralUsage.fromJson(usageData) : null,
    );
  }

  /// Gets the first choice's message content, or empty string if no choices.
  String get content => choices.isNotEmpty ? choices.first.message.content : '';
}
