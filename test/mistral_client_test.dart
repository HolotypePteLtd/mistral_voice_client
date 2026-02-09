import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:mistral_client/mistral_client.dart';
import 'package:test/test.dart';

void main() {
  group('MistralClient.transcribeAudio', () {
    test('sends correct multipart request and parses response', () async {
      String? capturedModel;
      String? capturedAuth;
      List<String> capturedGranularityFileNames = [];
      String? capturedFileName;
      String? capturedLanguage;

      final mockClient =
          http_testing.MockClient.streaming((request, bodyStream) async {
        capturedAuth = request.headers['Authorization'];

        if (request is http.MultipartRequest) {
          capturedModel = request.fields['model'];
          capturedLanguage = request.fields['language'];
          for (final file in request.files) {
            if (file.field == 'timestamp_granularities[]') {
              final bytes = await file.finalize().toBytes();
              capturedGranularityFileNames.add(utf8.decode(bytes));
            } else if (file.field == 'file') {
              capturedFileName = file.filename;
            }
          }
        }

        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'model': 'voxtral-mini-latest',
            'text': 'Hello world. How are you?',
            'language': 'en',
            'duration': 5.5,
            'segments': [
              {
                'text': ' Hello world.',
                'start': 0.0,
                'end': 2.5,
                'confidence': 0.95,
              },
              {
                'text': ' How are you?',
                'start': 2.5,
                'end': 5.5,
                'confidence': 0.88,
              },
            ],
            'usage': {
              'total_seconds': 5.5,
              'total_segments': 2,
            },
          }))),
          200,
        );
      });

      final client = MistralClient(
        apiKey: 'test-api-key',
        httpClient: mockClient,
      );

      final request = TranscriptionRequest(
        fileBytes: utf8.encode('fake audio data'),
        fileName: 'test.wav',
        language: 'en',
        timestampGranularities: ['segment'],
      );

      final response = await client.transcribeAudio(request);

      // Verify request
      expect(capturedAuth, equals('Bearer test-api-key'));
      expect(capturedModel, equals('voxtral-mini-latest'));
      expect(capturedGranularityFileNames, equals(['segment']));
      expect(capturedFileName, equals('test.wav'));
      expect(capturedLanguage, equals('en'));

      // Verify response
      expect(response.model, equals('voxtral-mini-latest'));
      expect(response.text, equals('Hello world. How are you?'));
      expect(response.language, equals('en'));
      expect(response.durationSeconds, equals(5.5));
      expect(response.segments, hasLength(2));
      expect(response.segments[0].text, equals('Hello world.'));
      expect(response.segments[0].start, equals(0.0));
      expect(response.segments[0].end, equals(2.5));
      expect(response.segments[0].confidence, equals(0.95));
      expect(response.segments[1].text, equals('How are you?'));
      expect(response.usage?.totalSeconds, equals(5.5));
      expect(response.usage?.totalSegments, equals(2));

      client.dispose();
    });

    test('throws MistralApiException on 401 with error message', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'Unauthorized: Invalid API key',
          }),
          401,
        );
      });

      final client = MistralClient(
        apiKey: 'bad-key',
        httpClient: mockClient,
      );

      final request = TranscriptionRequest(
        fileBytes: utf8.encode('fake audio'),
        fileName: 'test.wav',
      );

      try {
        await client.transcribeAudio(request);
        fail('Expected MistralApiException');
      } on MistralApiException catch (e) {
        expect(e.statusCode, equals(401));
        expect(e.apiErrorMessage, equals('Unauthorized: Invalid API key'));
        expect(e.rawBody, isNotNull);
      }

      client.dispose();
    });

    test('throws MistralApiException with nested error format', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'message': 'Model not found',
              'type': 'invalid_request_error',
            },
          }),
          400,
        );
      });

      final client = MistralClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final request = TranscriptionRequest(
        fileBytes: utf8.encode('fake audio'),
        fileName: 'test.wav',
      );

      try {
        await client.transcribeAudio(request);
        fail('Expected MistralApiException');
      } on MistralApiException catch (e) {
        expect(e.statusCode, equals(400));
        expect(e.apiErrorMessage, equals('Model not found'));
      }

      client.dispose();
    });

    test('throws MistralNetworkException on SocketException', () async {
      final mockClient = http_testing.MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final client = MistralClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final request = TranscriptionRequest(
        fileBytes: utf8.encode('fake audio'),
        fileName: 'test.wav',
      );

      try {
        await client.transcribeAudio(request);
        fail('Expected MistralNetworkException');
      } on MistralNetworkException catch (e) {
        expect(e.message, contains('Failed to connect'));
        expect(e.cause, isA<SocketException>());
      }

      client.dispose();
    });

    test('reports progress via callback', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            'text': 'Hello',
            'segments': [],
          }),
          200,
        );
      });

      final client = MistralClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final request = TranscriptionRequest(
        fileBytes: utf8.encode('fake audio'),
        fileName: 'test.wav',
      );

      final progressValues = <double>[];
      await client.transcribeAudio(
        request,
        onProgress: progressValues.add,
      );

      expect(progressValues, equals([0.3, 0.7, 0.9, 1.0]));

      client.dispose();
    });

    test('uses custom base URL', () async {
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({'text': '', 'segments': []}),
          200,
        );
      });

      final client = MistralClient(
        apiKey: 'test-key',
        baseUrl: 'https://custom.api.example.com',
        httpClient: mockClient,
      );

      final request = TranscriptionRequest(
        fileBytes: utf8.encode('fake audio'),
        fileName: 'test.wav',
      );

      await client.transcribeAudio(request);

      expect(
        capturedUri.toString(),
        equals('https://custom.api.example.com/v1/audio/transcriptions'),
      );

      client.dispose();
    });
  });

  group('TranscriptionRequest.validate', () {
    test('throws when no file source is provided', () {
      const request = TranscriptionRequest();

      expect(
        () => request.validate(),
        throwsA(isA<MistralException>().having(
          (e) => e.message,
          'message',
          contains('Exactly one file source required'),
        )),
      );
    });

    test('throws when multiple file sources are provided', () {
      final request = TranscriptionRequest(
        fileBytes: utf8.encode('data'),
        fileName: 'test.wav',
        fileUrl: 'https://example.com/audio.wav',
      );

      expect(
        () => request.validate(),
        throwsA(isA<MistralException>().having(
          (e) => e.message,
          'message',
          contains('multiple were provided'),
        )),
      );
    });

    test('throws when fileBytes provided without fileName', () {
      final request = TranscriptionRequest(
        fileBytes: utf8.encode('data'),
      );

      expect(
        () => request.validate(),
        throwsA(isA<MistralException>().having(
          (e) => e.message,
          'message',
          contains('fileName is required'),
        )),
      );
    });

    test('passes with valid fileBytes and fileName', () {
      final request = TranscriptionRequest(
        fileBytes: utf8.encode('data'),
        fileName: 'test.wav',
      );

      expect(() => request.validate(), returnsNormally);
    });

    test('passes with fileUrl only', () {
      const request = TranscriptionRequest(
        fileUrl: 'https://example.com/audio.wav',
      );

      expect(() => request.validate(), returnsNormally);
    });

    test('passes with fileId only', () {
      const request = TranscriptionRequest(
        fileId: 'file-abc123',
      );

      expect(() => request.validate(), returnsNormally);
    });
  });
}
