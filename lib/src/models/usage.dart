/// Token/time usage information from a Mistral API response.
class MistralUsage {
  /// Total audio duration in seconds.
  final double? totalSeconds;

  /// Number of audio segments processed.
  final int? totalSegments;

  const MistralUsage({
    this.totalSeconds,
    this.totalSegments,
  });

  factory MistralUsage.fromJson(Map<String, dynamic> json) {
    return MistralUsage(
      totalSeconds: (json['total_seconds'] as num?)?.toDouble(),
      totalSegments: json['total_segments'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (totalSeconds != null) 'total_seconds': totalSeconds,
        if (totalSegments != null) 'total_segments': totalSegments,
      };
}
