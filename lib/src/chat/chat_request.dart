import 'chat_message.dart';

/// Request model for the Mistral chat completions API.
class ChatRequest {
  /// The model to use for completion (e.g., 'mistral-small-latest', 'mistral-large-latest').
  final String model;

  /// The list of messages in the conversation.
  final List<ChatMessage> messages;

  /// Sampling temperature (0.0 to 1.0). Higher values make output more random.
  final double? temperature;

  /// Maximum number of tokens to generate.
  final int? maxTokens;

  /// Response format: `true` for json_object, or a `Map` for json_schema.
  /// Example: `{'type': 'json_schema', 'json_schema': {...}}`
  final Object? responseFormat;

  /// Top-p sampling (nucleus sampling).
  final double? topP;

  /// Seed for deterministic sampling.
  final int? seed;

  const ChatRequest({
    required this.model,
    required this.messages,
    this.temperature,
    this.maxTokens,
    this.responseFormat,
    this.topP,
    this.seed,
  });

  /// Creates a simple request with system and user messages.
  factory ChatRequest.simple({
    required String model,
    required String systemPrompt,
    required String userMessage,
    double? temperature,
    bool jsonMode = false,
  }) {
    return ChatRequest(
      model: model,
      messages: [
        ChatMessage.system(systemPrompt),
        ChatMessage.user(userMessage),
      ],
      temperature: temperature,
      responseFormat: jsonMode ? true : null,
    );
  }

  /// Creates a request with JSON schema enforcement.
  factory ChatRequest.withSchema({
    required String model,
    required List<ChatMessage> messages,
    required String schemaName,
    required Map<String, dynamic> schema,
    double? temperature,
  }) {
    return ChatRequest(
      model: model,
      messages: messages,
      temperature: temperature,
      responseFormat: {
        'type': 'json_schema',
        'json_schema': {
          'name': schemaName,
          'strict': true,
          'schema': schema,
        },
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'model': model,
    'messages': messages.map((m) => m.toJson()).toList(),
    if (temperature != null) 'temperature': temperature,
    if (maxTokens != null) 'max_tokens': maxTokens,
    if (responseFormat != null)
      'response_format': responseFormat is bool
          ? {'type': 'json_object'}
          : responseFormat,
    if (topP != null) 'top_p': topP,
    if (seed != null) 'seed': seed,
  };
}
