import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'audio/transcription_request.dart';
import 'audio/transcription_response.dart';
import 'exceptions.dart';

final _log = Logger('MistralClient');

/// Client for the Mistral AI API.
class MistralClient {
  static const String _defaultBaseUrl = 'https://api.mistral.ai';

  final String _apiKey;
  final String _baseUrl;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  /// Create a new [MistralClient].
  ///
  /// [apiKey] - Mistral API key (required).
  /// [baseUrl] - Override the base URL (default: https://api.mistral.ai).
  /// [httpClient] - Inject an HTTP client for testing.
  MistralClient({
    required String apiKey,
    String? baseUrl,
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl ?? _defaultBaseUrl,
        _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null;

  /// Transcribe audio using the Mistral transcription API.
  ///
  /// [request] - The transcription request parameters.
  /// [onProgress] - Optional callback for progress updates (0.0 to 1.0).
  ///
  /// Returns a [TranscriptionResponse] with the transcription result.
  /// Throws [MistralApiException] on API errors.
  /// Throws [MistralNetworkException] on connection errors.
  /// Throws [MistralException] on validation errors.
  Future<TranscriptionResponse> transcribeAudio(
    TranscriptionRequest request, {
    void Function(double)? onProgress,
  }) async {
    request.validate();

    final uri = Uri.parse('$_baseUrl/v1/audio/transcriptions');

    _log.info('Starting transcription request to $uri');

    final multipartRequest = http.MultipartRequest('POST', uri);
    multipartRequest.headers['Authorization'] = 'Bearer $_apiKey';

    // Required field
    multipartRequest.fields['model'] = request.model;

    // Optional fields
    if (request.language != null) {
      multipartRequest.fields['language'] = request.language!;
    }
    if (request.temperature != null) {
      multipartRequest.fields['temperature'] =
          request.temperature!.toString();
    }
    if (request.diarize != null) {
      multipartRequest.fields['diarize'] = request.diarize!.toString();
    }
    if (request.timestampGranularities != null) {
      for (final granularity in request.timestampGranularities!) {
        multipartRequest.files.add(http.MultipartFile.fromString(
          'timestamp_granularities[]',
          granularity,
        ));
      }
    }

    // File source
    if (request.fileBytes != null) {
      multipartRequest.files.add(http.MultipartFile.fromBytes(
        'file',
        request.fileBytes!,
        filename: request.fileName!,
      ));
    } else if (request.fileUrl != null) {
      multipartRequest.fields['file_url'] = request.fileUrl!;
    } else if (request.fileId != null) {
      multipartRequest.fields['file_id'] = request.fileId!;
    }

    onProgress?.call(0.3);

    // Send request
    final http.Response response;
    try {
      final streamedResponse = await _httpClient.send(multipartRequest);
      response = await http.Response.fromStream(streamedResponse);
    } on SocketException catch (e) {
      throw MistralNetworkException(
        'Failed to connect to Mistral API',
        cause: e,
      );
    } on HttpException catch (e) {
      throw MistralNetworkException(
        'HTTP error communicating with Mistral API',
        cause: e,
      );
    }

    onProgress?.call(0.7);

    _log.info('API response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      final apiErrorMessage = _parseErrorMessage(response.body);
      _log.warning(
        'API error ${response.statusCode}: $apiErrorMessage',
      );
      throw MistralApiException(
        'Transcription API request failed',
        statusCode: response.statusCode,
        apiErrorMessage: apiErrorMessage,
        rawBody: response.body,
      );
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;

    onProgress?.call(0.9);

    final result = TranscriptionResponse.fromJson(responseData);

    _log.info(
      'Transcription complete: ${result.segments.length} segments, '
      '${result.durationSeconds.toStringAsFixed(1)}s duration',
    );

    onProgress?.call(1.0);

    return result;
  }

  /// Parse error message from API response body.
  ///
  /// Handles both Mistral formats:
  /// - `{"message": "..."}`
  /// - `{"error": {"message": "..."}}`
  String? _parseErrorMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      // Format: {"error": {"message": "..."}}
      final error = json['error'];
      if (error is Map<String, dynamic>) {
        return error['message'] as String?;
      }
      // Format: {"message": "..."}
      final message = json['message'] as String?;
      if (message != null) return message;
    } catch (_) {
      // Not valid JSON
    }
    return body.isNotEmpty ? body : null;
  }

  /// Close the HTTP client and release resources.
  ///
  /// Only closes the client if it was created internally (not injected).
  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}
