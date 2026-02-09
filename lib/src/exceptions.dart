/// Base exception for Mistral API errors.
class MistralException implements Exception {
  /// Human-readable error message.
  final String message;

  /// The underlying cause, if any.
  final Object? cause;

  const MistralException(this.message, {this.cause});

  @override
  String toString() => 'MistralException: $message';
}

/// Exception thrown when the Mistral API returns an error response.
class MistralApiException extends MistralException {
  /// HTTP status code from the API response.
  final int statusCode;

  /// Error message extracted from the API response body.
  final String? apiErrorMessage;

  /// Raw response body.
  final String? rawBody;

  const MistralApiException(
    super.message, {
    required this.statusCode,
    this.apiErrorMessage,
    this.rawBody,
  });

  @override
  String toString() {
    final parts = ['MistralApiException: $message (HTTP $statusCode)'];
    if (apiErrorMessage != null) {
      parts.add('API error: $apiErrorMessage');
    }
    return parts.join(', ');
  }
}

/// Exception thrown when a network error occurs communicating with the API.
class MistralNetworkException extends MistralException {
  const MistralNetworkException(super.message, {super.cause});

  @override
  String toString() {
    if (cause != null) {
      return 'MistralNetworkException: $message (cause: $cause)';
    }
    return 'MistralNetworkException: $message';
  }
}
