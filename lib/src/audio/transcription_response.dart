import '../models/usage.dart';

/// A single segment from the transcription response.
class TranscriptionSegment {
  /// The transcribed text.
  final String text;

  /// Start time in seconds.
  final double start;

  /// End time in seconds.
  final double end;

  /// Confidence score (0.0 to 1.0).
  final double? confidence;

  const TranscriptionSegment({
    required this.text,
    required this.start,
    required this.end,
    this.confidence,
  });

  factory TranscriptionSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptionSegment(
      text: (json['text'] as String).trim(),
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  /// Duration of this segment in seconds.
  double get durationSeconds => end - start;

  Map<String, dynamic> toJson() => {
        'text': text,
        'start': start,
        'end': end,
        if (confidence != null) 'confidence': confidence,
      };

  @override
  String toString() =>
      'TranscriptionSegment("$text", ${start.toStringAsFixed(2)}s-${end.toStringAsFixed(2)}s)';
}

/// Response from the Mistral audio transcription API.
class TranscriptionResponse {
  /// The model that was used for transcription.
  final String? model;

  /// The full transcribed text.
  final String text;

  /// Detected language code.
  final String? language;

  /// Audio duration in seconds.
  final double? duration;

  /// Individual transcription segments with timing.
  final List<TranscriptionSegment> segments;

  /// API usage information.
  final MistralUsage? usage;

  const TranscriptionResponse({
    this.model,
    required this.text,
    this.language,
    this.duration,
    this.segments = const [],
    this.usage,
  });

  factory TranscriptionResponse.fromJson(Map<String, dynamic> json) {
    final segmentsData = json['segments'] as List<dynamic>?;
    final segments = segmentsData
            ?.map((s) =>
                TranscriptionSegment.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];

    final usageData = json['usage'] as Map<String, dynamic>?;

    return TranscriptionResponse(
      model: json['model'] as String?,
      text: (json['text'] as String?) ?? '',
      language: json['language'] as String?,
      duration: (json['duration'] as num?)?.toDouble(),
      segments: segments,
      usage: usageData != null ? MistralUsage.fromJson(usageData) : null,
    );
  }

  /// Total duration in seconds, derived from the response duration field,
  /// usage data, or the last segment end time.
  double get durationSeconds {
    if (duration != null) return duration!;
    if (usage?.totalSeconds != null) return usage!.totalSeconds!;
    if (segments.isNotEmpty) return segments.last.end;
    return 0.0;
  }
}
