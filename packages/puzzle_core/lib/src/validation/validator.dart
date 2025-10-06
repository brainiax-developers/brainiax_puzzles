abstract class PuzzleValidator<TBoard> {
  const PuzzleValidator();
  /// Returns true if the board respects puzzle rules (not necessarily solved)
  bool isValid(TBoard board);
  /// Returns true if the board is a valid unique solution (if applicable)
  bool isSolved(TBoard board);
}
