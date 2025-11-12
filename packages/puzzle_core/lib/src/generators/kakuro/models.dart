import '../../difficulty/telemetry.dart';
import '../../util/seeded_rng.dart';
import '../../kakuro/kakuro_board.dart';

enum KakuroGenerationStrategy { solutionFirst, bottomUp }

class KakuroDifficultyProfile {
  const KakuroDifficultyProfile({
    this.maxBacktrackNodes = 14,
    this.minForcedRatio = 0.14,
    this.maxSearchDepth = 24,
    this.maxPropagationRounds = 120,
  });

  final int maxBacktrackNodes;
  final double minForcedRatio;
  final int maxSearchDepth;
  final int maxPropagationRounds;

  KakuroDifficultyProfile merge(KakuroDifficultyProfile? other) {
    if (other == null) return this;
    return KakuroDifficultyProfile(
      maxBacktrackNodes: other.maxBacktrackNodes,
      minForcedRatio: other.minForcedRatio,
      maxSearchDepth: other.maxSearchDepth,
      maxPropagationRounds: other.maxPropagationRounds,
    );
  }
}

class GenerateKakuroRequest {
  GenerateKakuroRequest({
    required this.width,
    required this.height,
    required this.difficulty,
    this.seed,
    this.profile = const KakuroDifficultyProfile(),
    this.timeBudget = const Duration(milliseconds: 250),
    this.maxRestarts = 40,
    this.strategy = KakuroGenerationStrategy.solutionFirst,
  });

  final int width;
  final int height;
  final String difficulty;
  final int? seed;
  final KakuroDifficultyProfile profile;
  final Duration timeBudget;
  final int maxRestarts;
  final KakuroGenerationStrategy strategy;

  SeededRng rng() => SeededRng(seed ?? DateTime.now().microsecondsSinceEpoch);
}

class KakuroPuzzle {
  KakuroPuzzle({
    required this.board,
    required this.difficultyBucket,
    required this.telemetry,
    required this.difficultyTelemetry,
    this.seed,
    this.strategy = KakuroGenerationStrategy.solutionFirst,
    this.timeToGenerate = Duration.zero,
    this.restartCount = 0,
  });

  final KakuroBoard board;
  final String difficultyBucket;
  final Map<String, Object?> telemetry;
  final DifficultyTelemetry difficultyTelemetry;
  final int? seed;
  final KakuroGenerationStrategy strategy;
  final Duration timeToGenerate;
  final int restartCount;

  int get width => board.width;
  int get height => board.height;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'board': board.toJson(),
        'difficultyBucket': difficultyBucket,
        'telemetry': telemetry,
        'difficultyTelemetry': difficultyTelemetry.toJson(),
        'seed': seed,
        'strategy': strategy.name,
        'timeToGenerateMs': timeToGenerate.inMilliseconds,
        'restartCount': restartCount,
      };

  factory KakuroPuzzle.fromJson(Map<String, dynamic> json) {
    final strategyName = json['strategy'] as String? ?? 'solutionFirst';
    return KakuroPuzzle(
      board: KakuroBoard.fromJson(Map<String, dynamic>.from(json['board'] as Map)),
      difficultyBucket: json['difficultyBucket'] as String? ?? 'unknown',
      telemetry: Map<String, Object?>.from(json['telemetry'] as Map? ?? const {}),
      difficultyTelemetry: DifficultyTelemetry.fromJson(
        Map<String, dynamic>.from(json['difficultyTelemetry'] as Map? ?? const {}),
      ),
      seed: json['seed'] as int?,
      strategy: KakuroGenerationStrategy.values.firstWhere(
        (s) => s.name == strategyName,
        orElse: () => KakuroGenerationStrategy.solutionFirst,
      ),
      timeToGenerate: Duration(
        milliseconds: (json['timeToGenerateMs'] as num?)?.toInt() ?? 0,
      ),
      restartCount: (json['restartCount'] as num?)?.toInt() ?? 0,
    );
  }
}
