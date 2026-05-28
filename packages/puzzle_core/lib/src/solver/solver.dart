import '../util/seeded_rng.dart';

/// Explicit outcome status for solver runs.
enum SolverStatus {
  noSolution,
  unique,
  multiple,
  unknown,
}

/// Context for solver invocations.
class SolverContext {
  final SeededRng rng;
  final int maxSolutions;
  // Optional: preferred edge values (for grid/edge-based puzzles) to bias search.
  // Interpreted as per-puzzle board semantics; solvers may ignore this.
  final List<int>? preferredEdgeValues;
  // Optional: cap on speculative steps (branching decisions) to bound runtime.
  final int? speculativeStepBudget;

  const SolverContext({
    required this.rng,
    this.maxSolutions = 1,
    this.preferredEdgeValues,
    this.speculativeStepBudget,
  });
}

/// Result of running a solver.
class SolverResult<TBoard> {
  final List<TBoard> solutions;
  final Duration elapsed;
  final Map<String, Object?> telemetry;
  final SolverStatus? status;

  const SolverResult({
    required this.solutions,
    required this.elapsed,
    this.telemetry = const <String, Object?>{},
    this.status,
  });

  SolverStatus get solutionStatus {
    if (status != null) {
      return status!;
    }
    if (solutions.isEmpty) {
      return SolverStatus.noSolution;
    }
    if (solutions.length == 1) {
      return SolverStatus.unique;
    }
    return SolverStatus.multiple;
  }

  bool get hasSolution => solutions.isNotEmpty;
  bool get isUnique => solutionStatus == SolverStatus.unique;
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
