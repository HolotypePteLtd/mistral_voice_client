import 'package:mistral_client/mistral_client.dart';
import 'package:test/test.dart';

void main() {
  group('TranscriptionResponse.fromJson', () {
    test('parses full response with all fields', () {
      final json = {
        'model': 'voxtral-mini-latest',
        'text': 'Hello world.',
        'language': 'en',
        'duration': 3.2,
        'segments': [
          {
            'text': ' Hello world.',
            'start': 0.0,
            'end': 3.2,
            'confidence': 0.97,
          },
        ],
        'usage': {
          'total_seconds': 3.2,
          'total_segments': 1,
        },
      };

      final response = TranscriptionResponse.fromJson(json);

      expect(response.model, equals('voxtral-mini-latest'));
      expect(response.text, equals('Hello world.'));
      expect(response.language, equals('en'));
      expect(response.duration, equals(3.2));
      expect(response.durationSeconds, equals(3.2));
      expect(response.segments, hasLength(1));
      expect(response.segments[0].text, equals('Hello world.'));
      expect(response.segments[0].start, equals(0.0));
      expect(response.segments[0].end, equals(3.2));
      expect(response.segments[0].confidence, equals(0.97));
      expect(response.usage?.totalSeconds, equals(3.2));
      expect(response.usage?.totalSegments, equals(1));
    });

    test('parses response with empty segments', () {
      final json = {
        'text': '',
        'segments': <dynamic>[],
      };

      final response = TranscriptionResponse.fromJson(json);

      expect(response.text, equals(''));
      expect(response.segments, isEmpty);
      expect(response.durationSeconds, equals(0.0));
    });

    test('parses response with missing optional fields', () {
      final json = {
        'text': 'Hello',
      };

      final response = TranscriptionResponse.fromJson(json);

      expect(response.model, isNull);
      expect(response.text, equals('Hello'));
      expect(response.language, isNull);
      expect(response.duration, isNull);
      expect(response.segments, isEmpty);
      expect(response.usage, isNull);
    });

    test('durationSeconds falls back to usage total_seconds', () {
      final json = {
        'text': 'Hello',
        'usage': {
          'total_seconds': 4.5,
        },
      };

      final response = TranscriptionResponse.fromJson(json);

      expect(response.duration, isNull);
      expect(response.durationSeconds, equals(4.5));
    });

    test('durationSeconds falls back to last segment end time', () {
      final json = {
        'text': 'Hello world',
        'segments': [
          {'text': 'Hello', 'start': 0.0, 'end': 1.0},
          {'text': 'world', 'start': 1.0, 'end': 2.8},
        ],
      };

      final response = TranscriptionResponse.fromJson(json);

      expect(response.duration, isNull);
      expect(response.durationSeconds, equals(2.8));
    });

    test('segment text is trimmed', () {
      final json = {
        'text': 'Hello',
        'segments': [
          {'text': ' Hello ', 'start': 0.0, 'end': 1.0},
        ],
      };

      final response = TranscriptionResponse.fromJson(json);

      expect(response.segments[0].text, equals('Hello'));
    });

    test('segment without confidence', () {
      final json = {
        'text': 'Hello',
        'segments': [
          {'text': 'Hello', 'start': 0.0, 'end': 1.0},
        ],
      };

      final response = TranscriptionResponse.fromJson(json);

      expect(response.segments[0].confidence, isNull);
    });

    test('multiple segments parsed correctly', () {
      final json = {
        'text': 'One two three',
        'duration': 9.0,
        'segments': [
          {'text': 'One', 'start': 0.0, 'end': 3.0, 'confidence': 0.9},
          {'text': 'two', 'start': 3.0, 'end': 6.0, 'confidence': 0.85},
          {'text': 'three', 'start': 6.0, 'end': 9.0, 'confidence': 0.92},
        ],
      };

      final response = TranscriptionResponse.fromJson(json);

      expect(response.segments, hasLength(3));
      expect(response.segments[0].durationSeconds, equals(3.0));
      expect(response.segments[1].text, equals('two'));
      expect(response.segments[2].end, equals(9.0));
    });
  });

  group('TranscriptionSegment', () {
    test('durationSeconds is calculated correctly', () {
      const segment = TranscriptionSegment(
        text: 'Hello',
        start: 1.5,
        end: 4.2,
      );

      expect(segment.durationSeconds, closeTo(2.7, 0.001));
    });

    test('toJson round-trips with fromJson', () {
      const original = TranscriptionSegment(
        text: 'Hello',
        start: 1.0,
        end: 2.5,
        confidence: 0.95,
      );

      final json = original.toJson();
      final restored = TranscriptionSegment.fromJson(json);

      expect(restored.text, equals(original.text));
      expect(restored.start, equals(original.start));
      expect(restored.end, equals(original.end));
      expect(restored.confidence, equals(original.confidence));
    });
  });

  group('MistralUsage', () {
    test('fromJson parses correctly', () {
      final json = {
        'total_seconds': 10.5,
        'total_segments': 3,
      };

      final usage = MistralUsage.fromJson(json);

      expect(usage.totalSeconds, equals(10.5));
      expect(usage.totalSegments, equals(3));
    });

    test('fromJson handles missing fields', () {
      final json = <String, dynamic>{};

      final usage = MistralUsage.fromJson(json);

      expect(usage.totalSeconds, isNull);
      expect(usage.totalSegments, isNull);
    });
  });

  group('Exceptions', () {
    test('MistralApiException toString includes status and message', () {
      const exception = MistralApiException(
        'Request failed',
        statusCode: 401,
        apiErrorMessage: 'Invalid API key',
      );

      final str = exception.toString();
      expect(str, contains('401'));
      expect(str, contains('Invalid API key'));
    });

    test('MistralNetworkException toString includes cause', () {
      const exception = MistralNetworkException(
        'Connection failed',
        cause: 'timeout',
      );

      final str = exception.toString();
      expect(str, contains('Connection failed'));
      expect(str, contains('timeout'));
    });

    test('MistralException is the base type', () {
      const apiEx = MistralApiException('test', statusCode: 400);
      const netEx = MistralNetworkException('test');

      expect(apiEx, isA<MistralException>());
      expect(netEx, isA<MistralException>());
    });
  });
}
