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
      List<String> capturedGranularities = [];
      String? capturedFileName;
      String? capturedLanguage;

      final mockClient =
          http_testing.MockClient.streaming((request, bodyStream) async {
        capturedAuth = request.headers['authorization'];

        // The body is now a hand-built multipart/form-data payload on an
        // http.Request (not a MultipartRequest), so parse it directly.
        final body = latin1.decode((request as http.Request).bodyBytes);
        final boundary = RegExp(r'boundary=([^\r\n;]+)')
            .firstMatch(request.headers['content-type'] ?? '')!
            .group(1)!;
        for (final raw in body.split('--$boundary')) {
          final headerEnd = raw.indexOf('\r\n\r\n');
          if (headerEnd < 0) continue;
          final headers = raw.substring(0, headerEnd);
          final value =
              raw.substring(headerEnd + 4, raw.length - 2); // strip \r\n
          final name =
              RegExp(r'name="([^"]+)"').firstMatch(headers)?.group(1);
          if (name == null) continue;
          switch (name) {
            case 'model':
              capturedModel = value;
            case 'language':
              capturedLanguage = value;
            case 'timestamp_granularities':
              capturedGranularities.add(value);
            case 'file':
              capturedFileName =
                  RegExp(r'filename="([^"]+)"').firstMatch(headers)?.group(1);
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
      expect(capturedGranularities, equals(['segment']));
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

    test('sends multiple timestamp_granularities as separate plain fields',
        () async {
      // Regression: emitting the values as content-typed file parts made the
      // API merge them into a single "segmentword" value. They must instead be
      // distinct plain form fields (no content-type), one per value.
      String? rawBody;
      String? contentType;

      final mockClient =
          http_testing.MockClient.streaming((request, bodyStream) async {
        rawBody = latin1.decode((request as http.Request).bodyBytes);
        contentType = request.headers['content-type'];
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'model': 'voxtral-mini-latest',
            'text': 'Hello world.',
            'segments': [
              {'text': 'Hello world.', 'start': 0.0, 'end': 1.0},
            ],
          }))),
          200,
        );
      });

      final client = MistralClient(apiKey: 'k', httpClient: mockClient);
      await client.transcribeAudio(TranscriptionRequest(
        fileBytes: utf8.encode('audio'),
        fileName: 'a.wav',
        timestampGranularities: ['segment', 'word'],
      ));

      final boundary =
          RegExp(r'boundary=([^\r\n;]+)').firstMatch(contentType!)!.group(1)!;
      final granularityParts = rawBody!
          .split('--$boundary')
          .where((p) => p.contains('name="timestamp_granularities"'))
          .toList();

      expect(granularityParts, hasLength(2),
          reason: 'each granularity must be its own part');
      // Plain form fields carry no content-type header.
      for (final part in granularityParts) {
        expect(part.toLowerCase(), isNot(contains('content-type')));
      }
      expect(granularityParts[0], contains('\r\n\r\nsegment'));
      expect(granularityParts[1], contains('\r\n\r\nword'));

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
