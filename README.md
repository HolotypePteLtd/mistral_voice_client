# mistral_client

A Dart client library for the [Mistral AI API](https://mistral.ai/), covering
chat completions and audio transcription.

## Features

- **Chat completions** — `chat()` with system/user/assistant messages,
  multimodal content parts, JSON mode (`response_format`), temperature,
  max tokens, top-p, and seed.
- **Audio transcription** — `transcribeAudio()` with multipart file upload,
  file URLs, or file IDs; language, temperature, and diarization options;
  timestamp granularity for per-segment and per-word timings; progress
  callbacks; confidence scores.
- **Structured errors** — `MistralApiException` (API errors with status code
  and message), `MistralNetworkException` (connection failures), and
  `MistralException` (validation errors).
- **Testable** — accepts an injected `http.Client` and overridable `baseUrl`.

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  mistral_client:
    git:
      url: https://github.com/HolotypePteLtd/mistral_voice_client.git
```

> The package is not yet published to pub.dev; once it is, you'll be able to
> use `mistral_client: ^0.1.0`.

## Usage

### Chat completions

```dart
import 'package:mistral_client/mistral_client.dart';

final client = MistralClient(apiKey: 'YOUR_API_KEY');

final response = await client.chat(ChatRequest.simple(
  model: 'mistral-small-latest',
  systemPrompt: 'You are a helpful assistant.',
  userMessage: 'What is the capital of France?',
));

print(response.choices.first.message.content);
client.dispose();
```

For structured output, enable JSON mode:

```dart
final response = await client.chat(ChatRequest.simple(
  model: 'mistral-small-latest',
  systemPrompt: 'Return JSON.',
  userMessage: 'List three colors as a JSON array.',
  jsonMode: true,
));
```

### Audio transcription

```dart
final client = MistralClient(apiKey: 'YOUR_API_KEY');

final file = File('recording.mp3');
final response = await client.transcribeAudio(
  TranscriptionRequest(
    model: 'voxtral-mini-latest',
    fileBytes: await file.readAsBytes(),
    fileName: file.path,
  ),
  onProgress: (progress) => print('${(progress * 100).toStringAsFixed(0)}%'),
);

print(response.text);

// Timed segments:
for (final segment in response.segments) {
  print('[${segment.start}s - ${segment.end}s] ${segment.text}');
}

// Per-word timings (request with timestampGranularities: ['word']):
for (final word in response.words) {
  print('${word.text} ${word.start}-${word.end}s');
}

client.dispose();
```

### Command-line transcription

A small CLI is included for quick testing:

```bash
dart run bin/transcribe.dart <api-key> <audio-file-path>
dart run bin/transcribe.dart <api-key> --url <audio-url>
```

## Development

```bash
dart pub get
dart test
```

## License

[MIT](LICENSE)
