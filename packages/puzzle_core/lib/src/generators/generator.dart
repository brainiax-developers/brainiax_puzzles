import '../api_types.dart';
import '../difficulty/telemetry.dart';
import '../util/seeded_rng.dart';

/// Context shared with puzzle generators.
///
/// Provides the deterministic RNG and generation parameters so that
/// generators remain pure/deterministic functions of their inputs.
class GeneratorContext {
  /// Deterministic RNG seeded from the engine.
  final SeededRng rng;

  /// Original seed string provided by the caller.
  final String seedStr;

  /// 64-bit seed derived from [seedStr].
  final int seed64;

  /// Target size configuration.
  final SizeOpt size;

  /// Requested difficulty bucket.
  final DifficultyRequest difficulty;

  const GeneratorContext({
    required this.rng,
    required this.seedStr,
    required this.seed64,
    required this.size,
    required this.difficulty,
  });
}

/// Difficulty request supplied to the generator prior to the real score.
class DifficultyRequest {
  /// Difficulty label requested by the caller ("easy", "medium", etc.).
  final String level;

  /// Optional numeric hint that engines can use when producing boards.
  final double? hint;

  const DifficultyRequest({
    required this.level,
    this.hint,
  });
}

/// Metadata captured while generating a board.
class GenerationSnapshot {
  /// Telemetry emitted by the generator for downstream consumers.
  final Map<String, Object?> telemetry;

  const GenerationSnapshot({
    this.telemetry = const <String, Object?>{},
  });
}

/// Base class for deterministic puzzle generators.
abstract class PuzzleGenerator<TBoard> {
  const PuzzleGenerator();

  /// Produce a puzzle board for the provided context.
  ///
  /// Implementations must only depend on the values provided through
  /// [context] to guarantee determinism.
  PuzzleGenerationResult<TBoard> generate(GeneratorContext context);
}

/// Combined result of puzzle generation.
class PuzzleGenerationResult<TBoard> {
  final TBoard board;
  final GenerationSnapshot snapshot;

  const PuzzleGenerationResult({
    required this.board,
    this.snapshot = const GenerationSnapshot(),
  });
}
