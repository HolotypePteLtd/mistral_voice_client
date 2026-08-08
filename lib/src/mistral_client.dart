import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'audio/transcription_request.dart';
import 'audio/transcription_response.dart';
import 'chat/chat_request.dart';
import 'chat/chat_response.dart';
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

    _log.info('POST $uri (model=${request.model})');

    // Build the multipart body by hand rather than via [http.MultipartRequest].
    // MultipartRequest emits each list value as a part carrying a
    // `content-type` header, which the transcription API merges across
    // repeated `timestamp_granularities` fields into a single concatenated
    // value (e.g. "segmentword") and rejects with HTTP 422. Plain form fields
    // (no content-type), as curl's `--form` produces, are parsed correctly as
    // a list.
    final boundary = 'mistral-${DateTime.now().microsecondsSinceEpoch}';
    final body = _buildTranscriptionBody(request, boundary);

    final httpRequest = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer $_apiKey'
      ..headers['Content-Type'] = 'multipart/form-data; boundary=$boundary'
      ..bodyBytes = body;

    onProgress?.call(0.3);

    // Send request
    final stopwatch = Stopwatch()..start();
    final http.Response response;
    try {
      final streamedResponse = await _httpClient.send(httpRequest);
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

    stopwatch.stop();
    _log.info(
      'Response ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms',
    );

    onProgress?.call(0.7);

    if (response.statusCode != 200) {
      final apiErrorMessage = _parseErrorMessage(response.body);
      _log.warning(
        'Transcription API error ${response.statusCode}: $apiErrorMessage',
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

  /// Build the `multipart/form-data` body for a transcription request.
  ///
  /// Each field becomes a plain form part (no `content-type` header), and
  /// `timestamp_granularities` is emitted once per value so the API receives a
  /// proper list rather than a single concatenated string. The audio file is
  /// appended as a binary part when present.
  Uint8List _buildTranscriptionBody(
    TranscriptionRequest request,
    String boundary,
  ) {
    final parts = <List<int>>[];
    final sep = utf8.encode('--$boundary\r\n');
    const crlf = [13, 10];

    void field(String name, String value) {
      parts
        ..add(sep)
        ..add(utf8.encode(
            'content-disposition: form-data; name="$name"\r\n\r\n'))
        ..add(utf8.encode(value))
        ..add(crlf);
    }

    field('model', request.model);
    if (request.language != null) field('language', request.language!);
    if (request.temperature != null) {
      field('temperature', request.temperature!.toString());
    }
    if (request.diarize != null) field('diarize', request.diarize!.toString());
    if (request.timestampGranularities != null) {
      for (final granularity in request.timestampGranularities!) {
        field('timestamp_granularities', granularity);
      }
    }

    if (request.fileBytes != null) {
      parts
        ..add(sep)
        ..add(utf8.encode(
            'content-disposition: form-data; name="file"; '
            'filename="${request.fileName}"\r\n'
            'content-type: application/octet-stream\r\n\r\n'))
        ..add(request.fileBytes!)
        ..add(crlf);
    } else if (request.fileUrl != null) {
      field('file_url', request.fileUrl!);
    } else if (request.fileId != null) {
      field('file_id', request.fileId!);
    }

    parts.add(utf8.encode('--$boundary--\r\n'));

    final length = parts.fold<int>(0, (n, p) => n + p.length);
    final body = Uint8List(length);
    var offset = 0;
    for (final p in parts) {
      body.setRange(offset, offset + p.length, p);
      offset += p.length;
    }
    return body;
  }

  /// Send a chat completion request to the Mistral API.
  ///
  /// [request] - The chat request with model, messages, and optional parameters.
  ///
  /// Returns a [ChatResponse] with the generated completion.
  /// Throws [MistralApiException] on API errors.
  /// Throws [MistralNetworkException] on connection errors.
  Future<ChatResponse> chat(ChatRequest request) async {
    final uri = Uri.parse('$_baseUrl/v1/chat/completions');

    _log.info('POST $uri (model=${request.model})');

    final stopwatch = Stopwatch()..start();
    final response = await _httpClient.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    stopwatch.stop();
    _log.info(
      'Response ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms',
    );

    if (response.statusCode != 200) {
      final apiErrorMessage = _parseErrorMessage(response.body);
      _log.warning(
        'Chat API error ${response.statusCode}: $apiErrorMessage',
      );
      throw MistralApiException(
        'Chat API request failed',
        statusCode: response.statusCode,
        apiErrorMessage: apiErrorMessage,
        rawBody: response.body,
      );
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final result = ChatResponse.fromJson(responseData);

    _log.info('Chat complete: ${result.choices.length} choices');

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
