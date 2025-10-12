class ValidationSummary {
  final bool isValid;
  final Duration elapsed;
  final List<String> issues;

  const ValidationSummary({
    required this.isValid,
    required this.elapsed,
    this.issues = const <String>[],
  });

  factory ValidationSummary.success(Duration elapsed) =>
      ValidationSummary(isValid: true, elapsed: elapsed);

  factory ValidationSummary.failure(Duration elapsed, List<String> issues) =>
      ValidationSummary(isValid: false, elapsed: elapsed, issues: issues);
}

abstract class PuzzleValidator<TBoard> {
  const PuzzleValidator();

  /// Validate that the provided puzzle configuration obeys the base rules.
  ValidationSummary validatePuzzle(TBoard board);

  /// Validate that [solution] solves [board].
  ValidationSummary validateSolution(TBoard board, TBoard solution);

  /// Lightweight solved check reused by the engine.
  bool isSolved(TBoard board);
}
