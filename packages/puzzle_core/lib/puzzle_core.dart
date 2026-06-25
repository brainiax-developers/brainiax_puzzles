/// Puzzle Core - On-device deterministic puzzle generation system.
///
/// This package provides a stable API for puzzle engines with deterministic
/// generation, registry management, and metadata tracking.
///
/// Key features:
/// - On-device deterministic generation (no network, no wall-clock timings)
/// - 64-bit integer arithmetic for RNG (SplitMix64 seeding + xoroshiro128 core)
/// - Complete metadata tracking for reproducible puzzles
/// - Engine registry for pluggable puzzle types
/// - Daily and random seed formats
library puzzle_core;

// Core API types - the stable public interface
export 'src/api_types.dart';

// Registry implementation
export 'src/registry.dart';

// Engine pipeline template and core building blocks
export 'src/engine/pipeline_engine.dart';
export 'src/generators/generator.dart';
export 'src/solver/solver.dart';
export 'src/validation/validator.dart';
export 'src/difficulty/telemetry.dart';
export 'src/difficulty/difficulty_config.dart';

// Stub engines for testing and validation
export 'src/stub/stub_engine.dart';

// Sudoku engine implementation
export 'src/sudoku/sudoku_board.dart';
export 'src/sudoku/sudoku_move.dart';
export 'src/sudoku/sudoku_engine.dart';

// Nonogram engine implementation
export 'src/nonogram/nonogram_board.dart';
export 'src/nonogram/nonogram_move.dart';
export 'src/nonogram/nonogram_engine.dart';

// Kakuro engine implementation
export 'src/kakuro/kakuro_board.dart';
export 'src/kakuro/kakuro_move.dart';
export 'src/kakuro/kakuro_engine.dart';
export 'src/kakuro/kakuro_format.dart';
export 'src/kakuro/kakuro_solver.dart';
export 'src/kakuro/kakuro_supported_profiles.dart';
export 'src/generators/kakuro/models.dart';
export 'src/generators/kakuro/api.dart';

// Slitherlink engine implementation
export 'src/slitherlink/slitherlink_board.dart';
export 'src/slitherlink/slitherlink_move.dart';
export 'src/slitherlink/slitherlink_engine.dart';
export 'src/models/slitherlink_models.dart';
// Expose solver/generator/validator for tests and advanced usage
export 'src/slitherlink/slitherlink_generator.dart';
export 'src/slitherlink/slitherlink_solver.dart';
export 'src/slitherlink/slitherlink_validator.dart';
export 'src/slitherlink/slitherlink_topology.dart';
export 'src/generators/slitherlink/api.dart';
export 'src/generators/slitherlink/difficulty.dart';
export 'src/generators/slitherlink/quality.dart';

// Mathdoku engine implementation
export 'src/mathdoku/mathdoku_board.dart';
export 'src/mathdoku/mathdoku_move.dart';
export 'src/mathdoku/mathdoku_engine.dart';

// Killer Queens engine implementation
export 'src/killer_queens/killer_queens_board.dart';
export 'src/killer_queens/killer_queens_move.dart';
export 'src/killer_queens/killer_queens_engine.dart';
// Expose solver/generator/validator for tests and advanced usage
export 'src/killer_queens/killer_queens_generator.dart';
export 'src/killer_queens/killer_queens_solver.dart';
export 'src/killer_queens/killer_queens_validator.dart';

// Takuzu engine implementation
export 'src/takuzu/takuzu_board.dart';
export 'src/takuzu/takuzu_move.dart';
export 'src/takuzu/takuzu_engine.dart';

// Legacy exports for backward compatibility (if needed)
export 'src/puzzle_core_base.dart';
export 'src/puzzle_type.dart';

// Utilities needed for testing
export 'src/util/seeded_rng.dart' show Seed, SeededRng;

// Note: Utility classes are intentionally not exported to maintain API stability.
// Engines should import utilities directly from their internal implementations.
