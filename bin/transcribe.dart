#!/usr/bin/env dart

import 'dart:io';
import 'package:mistral_client/mistral_client.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart bin/transcribe.dart <api-key> <audio-file-path>');
    stderr.writeln('   or: dart bin/transcribe.dart <api-key> --url <audio-url>');
    exit(1);
  }

  final apiKey = args[0];
  String? audioFilePath;
  String? audioUrl;

  if (args.length >= 2) {
    if (args[1] == '--url' && args.length >= 3) {
      audioUrl = args[2];
    } else {
      audioFilePath = args[1];
    }
  }

  if (audioFilePath == null && audioUrl == null) {
    stderr.writeln('Error: Please provide either an audio file path or --url <audio-url>');
    exit(1);
  }

  final client = MistralClient(apiKey: apiKey);

  TranscriptionRequest? request;

  try {
    print('Transcribing...');
    if (audioFilePath != null) {
      print('File: $audioFilePath');
      final file = File(audioFilePath);
      if (!file.existsSync()) {
        stderr.writeln('Error: File not found: $audioFilePath');
        exit(1);
      }
      final bytes = await file.readAsBytes();
      final fileName = audioFilePath.split(Platform.pathSeparator).last;
      request = TranscriptionRequest(
        model: 'voxtral-mini-latest',
        fileBytes: bytes,
        fileName: fileName,
      );
    } else {
      print('URL: $audioUrl');
      request = TranscriptionRequest(
        model: 'voxtral-mini-latest',
        fileUrl: audioUrl,
      );
    }

    final response = await client.transcribeAudio(request);

    print('\n=== Transcription Result ===');
    print('Text: ${response.text}');
    if (response.language != null) {
      print('Language: ${response.language}');
    }
    if (response.duration != null) {
      print('Duration: ${response.duration}s');
    }
    if (response.segments.isNotEmpty) {
      print('\nSegments (${response.segments.length}):');
      for (final segment in response.segments) {
        print('  [${segment.start}s - ${segment.end}s] ${segment.text}');
      }
    }
  } on MistralException catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  } finally {
    client.dispose();
  }
}
