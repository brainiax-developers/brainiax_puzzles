import '../util/kakuro_dictionary.dart';
import '../validation/validator.dart';
import 'kakuro_board.dart';

class KakuroValidator extends PuzzleValidator<KakuroBoard> {
  const KakuroValidator();

  @override
  ValidationSummary validatePuzzle(KakuroBoard board) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    for (int i = 0; i < board.cellCount; i++) {
      if (!board.isPlayableIndex(i)) {
        continue;
      }
      final int value = board.values[i];
      if (value < 0 || value > 9) {
        issues.add('value_out_of_range:$i');
      }
    }

    _validateStructure(board, issues);

    for (final KakuroEntry entry in board.entries) {
      if (!_entryCellsUsable(board, entry)) {
        continue;
      }
      final Set<int> seen = <int>{};
      int partialSum = 0;
      bool isComplete = true;
      bool invalidDuplicate = false;
      for (final int index in entry.cells) {
        final int value = board.values[index];
        if (value == 0) {
          isComplete = false;
          continue;
        }
        if (value < 1 || value > 9) {
          issues.add('invalid_digit:${entry.id}:$index');
          isComplete = false;
          continue;
        }
        if (!seen.add(value)) {
          invalidDuplicate = true;
          break;
        }
        partialSum += value;
      }
      if (invalidDuplicate) {
        issues.add('duplicate_digit:${entry.id}');
        continue;
      }
      if (partialSum > entry.sum) {
        issues.add('sum_exceeded:${entry.id}');
        continue;
      }
      if (seen.isEmpty) {
        continue;
      }
      if (isComplete && partialSum != entry.sum) {
        issues.add('entry_sum:${entry.id}');
      }
    }

    stopwatch.stop();
    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  ValidationSummary validateSolution(KakuroBoard board, KakuroBoard solution) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    if (board.width != solution.width || board.height != solution.height) {
      issues.add('dimension_mismatch');
    }

    _validateStructure(board, issues);

    for (int i = 0; i < board.cellCount; i++) {
      if (!board.isPlayableIndex(i)) {
        continue;
      }
      final int original = board.values[i];
      final int solved = solution.values[i];
      if (solved < 1 || solved > 9) {
        issues.add('invalid_digit:$i');
      }
      if (original != 0 && original != solved) {
        issues.add('fixed_mismatch:$i');
      }
    }

    for (final KakuroEntry entry in board.entries) {
      final Set<int> seen = <int>{};
      int sum = 0;
      for (final int index in entry.cells) {
        final int value = solution.values[index];
        if (value < 1 || value > 9 || !seen.add(value)) {
          issues.add('entry_violation:${entry.id}');
          break;
        }
        sum += value;
      }
      if (sum != entry.sum) {
        issues.add('entry_sum:${entry.id}');
      }
    }

    stopwatch.stop();
    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  bool isSolved(KakuroBoard board) {
    final List<String> structuralIssues = <String>[];
    _validateStructure(board, structuralIssues);
    if (structuralIssues.isNotEmpty) {
      return false;
    }

    for (int i = 0; i < board.cellCount; i++) {
      if (!board.isPlayableIndex(i)) {
        continue;
      }
      final int value = board.values[i];
      if (value < 1 || value > 9) {
        return false;
      }
    }
    for (final KakuroEntry entry in board.entries) {
      final Set<int> seen = <int>{};
      int sum = 0;
      for (final int index in entry.cells) {
        final int value = board.values[index];
        if (value < 1 || value > 9 || !seen.add(value)) {
          return false;
        }
        sum += value;
      }
      if (sum != entry.sum) {
        return false;
      }
    }
    return true;
  }

  static void _validateStructure(KakuroBoard board, List<String> issues) {
    final List<int> acrossMembership = List<int>.filled(board.cellCount, 0);
    final List<int> downMembership = List<int>.filled(board.cellCount, 0);

    for (final KakuroEntry entry in board.entries) {
      if (entry.cells.length < 2 || entry.cells.length > 9) {
        issues.add('entry_length:${entry.id}');
      }
      if (!KakuroDictionary.hasCombinations(entry.cells.length, entry.sum)) {
        issues.add('invalid_clue:${entry.id}');
      }
      _validateEntryCells(
        board,
        entry,
        issues,
        acrossMembership,
        downMembership,
      );
    }

    for (int i = 0; i < board.cellCount; i++) {
      if (!board.isPlayableIndex(i)) {
        continue;
      }
      _validateCellEntryMap(
        board: board,
        issues: issues,
        cellIndex: i,
        expectedDirection: KakuroDirection.across,
        entryId: board.acrossEntryForCell[i],
      );
      _validateCellEntryMap(
        board: board,
        issues: issues,
        cellIndex: i,
        expectedDirection: KakuroDirection.down,
        entryId: board.downEntryForCell[i],
      );

      if (acrossMembership[i] != 1) {
        issues.add('across_membership_count:$i:${acrossMembership[i]}');
      }
      if (downMembership[i] != 1) {
        issues.add('down_membership_count:$i:${downMembership[i]}');
      }
    }
  }

  static void _validateEntryCells(
    KakuroBoard board,
    KakuroEntry entry,
    List<String> issues,
    List<int> acrossMembership,
    List<int> downMembership,
  ) {
    for (int offset = 0; offset < entry.cells.length; offset++) {
      final int index = entry.cells[offset];
      if (index < 0 || index >= board.cellCount) {
        issues.add('entry_cell_out_of_bounds:${entry.id}:$index');
        continue;
      }
      if (!board.isPlayableIndex(index)) {
        issues.add('entry_cell_not_playable:${entry.id}:$index');
      }
      if (entry.direction == KakuroDirection.across) {
        acrossMembership[index]++;
      } else {
        downMembership[index]++;
      }
      if (offset == 0) {
        continue;
      }
      final int previous = entry.cells[offset - 1];
      if (previous < 0 || previous >= board.cellCount) {
        continue;
      }
      if (!_isExpectedStep(board, previous, index, entry.direction)) {
        issues.add('entry_not_contiguous:${entry.id}');
      }
    }
  }

  static bool _isExpectedStep(
    KakuroBoard board,
    int from,
    int to,
    KakuroDirection direction,
  ) {
    final int fromRow = from ~/ board.width;
    final int fromCol = from % board.width;
    final int toRow = to ~/ board.width;
    final int toCol = to % board.width;
    if (direction == KakuroDirection.across) {
      return fromRow == toRow && toCol == fromCol + 1;
    }
    return fromCol == toCol && toRow == fromRow + 1;
  }

  static void _validateCellEntryMap({
    required KakuroBoard board,
    required List<String> issues,
    required int cellIndex,
    required KakuroDirection expectedDirection,
    required int entryId,
  }) {
    final String directionName = expectedDirection.name;
    if (entryId < 0 || entryId >= board.entries.length) {
      issues.add('missing_${directionName}_entry:$cellIndex');
      return;
    }
    final KakuroEntry entry = board.entries[entryId];
    if (entry.direction != expectedDirection) {
      issues.add('wrong_${directionName}_entry_direction:$cellIndex');
      return;
    }
    if (!entry.cells.contains(cellIndex)) {
      issues.add('${directionName}_entry_map_mismatch:$cellIndex');
    }
  }

  static bool _entryCellsUsable(KakuroBoard board, KakuroEntry entry) {
    for (final int index in entry.cells) {
      if (index < 0 || index >= board.cellCount) {
        return false;
      }
      if (!board.isPlayableIndex(index)) {
        return false;
      }
    }
    return true;
  }
}
