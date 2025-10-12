import '../util/seeded_rng.dart';

/// Context for solver invocations.
class SolverContext {
  final SeededRng rng;
  final int maxSolutions;

  const SolverContext({
    required this.rng,
    this.maxSolutions = 1,
  });
}

/// Result of running a solver.
class SolverResult<TBoard> {
  final List<TBoard> solutions;
  final Duration elapsed;
  final Map<String, Object?> telemetry;

  const SolverResult({
    required this.solutions,
    required this.elapsed,
    this.telemetry = const <String, Object?>{},
  });

  bool get hasSolution => solutions.isNotEmpty;
  bool get isUnique => solutions.length == 1;
}

/// Base class for puzzle solvers.
abstract class PuzzleSolver<TBoard> {
  const PuzzleSolver();

  /// Attempt to solve the given board.
  ///
  /// Implementations must respect [context.maxSolutions] to support
  /// uniqueness checking performed by the engine template.
  SolverResult<TBoard> solve(TBoard board, SolverContext context);
}
