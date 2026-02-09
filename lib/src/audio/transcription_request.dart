import 'dart:typed_data';

import '../exceptions.dart';

/// Request model for the Mistral audio transcription API.
class TranscriptionRequest {
  /// The model to use for transcription.
  final String model;

  /// Raw audio file bytes. Exactly one of [fileBytes], [fileUrl], or [fileId] must be set.
  final Uint8List? fileBytes;

  /// Filename for the uploaded file (used with [fileBytes]).
  final String? fileName;

  /// URL of an audio file to transcribe.
  final String? fileUrl;

  /// ID of a previously uploaded file.
  final String? fileId;

  /// Language hint (e.g., 'en', 'fr').
  final String? language;

  /// Sampling temperature (0.0 to 1.0).
  final double? temperature;

  /// Whether to enable speaker diarization.
  final bool? diarize;

  /// Context bias terms to improve recognition.
  final List<String>? contextBias;

  /// Timestamp granularity levels (e.g., ['segment']).
  final List<String>? timestampGranularities;

  const TranscriptionRequest({
    this.model = 'voxtral-mini-latest',
    this.fileBytes,
    this.fileName,
    this.fileUrl,
    this.fileId,
    this.language,
    this.temperature,
    this.diarize,
    this.contextBias,
    this.timestampGranularities,
  });

  /// Validate the request has exactly one file source.
  ///
  /// Throws [MistralException] if validation fails.
  void validate() {
    final sources = [
      fileBytes != null,
      fileUrl != null,
      fileId != null,
    ].where((v) => v).length;

    if (sources == 0) {
      throw const MistralException(
        'Exactly one file source required: fileBytes, fileUrl, or fileId',
      );
    }
    if (sources > 1) {
      throw const MistralException(
        'Exactly one file source required, but multiple were provided',
      );
    }

    if (fileBytes != null && (fileName == null || fileName!.isEmpty)) {
      throw const MistralException(
        'fileName is required when providing fileBytes',
      );
    }
  }
}
