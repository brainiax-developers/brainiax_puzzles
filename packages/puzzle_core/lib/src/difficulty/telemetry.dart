import 'dart:convert';

/// Telemetry emitted by the difficulty scorer.
class DifficultyTelemetry {
  final double rawScore;
  final String bucket;
  final Map<String, num> metrics;

  const DifficultyTelemetry({
    required this.rawScore,
    required this.bucket,
    this.metrics = const <String, num>{},
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rawScore': rawScore,
        'bucket': bucket,
        'metrics': metrics,
      };

  factory DifficultyTelemetry.fromJson(Map<String, dynamic> json) {
    final rawMetrics = json['metrics'];
    Map<String, num> metrics = const <String, num>{};
    if (rawMetrics is Map) {
      metrics = rawMetrics.map(
        (key, value) => MapEntry(key.toString(), (value as num)),
      );
    }
    return DifficultyTelemetry(
      rawScore: (json['rawScore'] as num).toDouble(),
      bucket: json['bucket'] as String,
      metrics: metrics,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}

/// Input context for difficulty scoring.
class DifficultyContext {
  final Map<String, Object?> generatorTelemetry;
  final Map<String, Object?> solverTelemetry;

  const DifficultyContext({
    this.generatorTelemetry = const <String, Object?>{},
    this.solverTelemetry = const <String, Object?>{},
  });
}

/// Base class for difficulty scorers.
abstract class DifficultyScorer<TBoard> {
  const DifficultyScorer();

  DifficultyTelemetry score({
    required TBoard puzzle,
    required TBoard solution,
    required DifficultyContext context,
  });
}
