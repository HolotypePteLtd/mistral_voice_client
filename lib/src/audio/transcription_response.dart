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

/// A single word with timing from the transcription response.
///
/// Emitted when the request includes `'word'` in
/// `timestamp_granularities`. Unlike [TranscriptionSegment], words carry no
/// confidence and are not grouped; consumers align them to text by index.
class TranscriptionWord {
  /// The transcribed word (trimmed of surrounding whitespace).
  final String text;

  /// Start time in seconds.
  final double start;

  /// End time in seconds.
  final double end;

  const TranscriptionWord({
    required this.text,
    required this.start,
    required this.end,
  });

  factory TranscriptionWord.fromJson(Map<String, dynamic> json) {
    return TranscriptionWord(
      text: (json['word'] as String? ?? '').trim(),
      start: (json['start'] as num? ?? 0).toDouble(),
      end: (json['end'] as num? ?? 0).toDouble(),
    );
  }

  /// Duration of this word in seconds.
  double get durationSeconds => end - start;

  Map<String, dynamic> toJson() => {
        'word': text,
        'start': start,
        'end': end,
      };

  @override
  String toString() =>
      'TranscriptionWord("$text", ${start.toStringAsFixed(2)}s-${end.toStringAsFixed(2)}s)';
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

  /// Per-word timings, present only when the request asked for `'word'`
  /// granularity. Words are flat across the whole clip (not grouped by
  /// segment); align them to text by index.
  final List<TranscriptionWord> words;

  /// API usage information.
  final MistralUsage? usage;

  const TranscriptionResponse({
    this.model,
    required this.text,
    this.language,
    this.duration,
    this.segments = const [],
    this.words = const [],
    this.usage,
  });

  factory TranscriptionResponse.fromJson(Map<String, dynamic> json) {
    final segmentsData = json['segments'] as List<dynamic>?;
    final segments = segmentsData
            ?.map((s) =>
                TranscriptionSegment.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];

    final wordsData = json['words'] as List<dynamic>?;
    final words = wordsData
            ?.map((w) =>
                TranscriptionWord.fromJson(w as Map<String, dynamic>))
            .toList() ??
        <TranscriptionWord>[];

    final usageData = json['usage'] as Map<String, dynamic>?;

    return TranscriptionResponse(
      model: json['model'] as String?,
      text: (json['text'] as String?) ?? '',
      language: json['language'] as String?,
      duration: (json['duration'] as num?)?.toDouble(),
      segments: segments,
      words: words,
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
