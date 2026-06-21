import 'package:flutter/material.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

core.PuzzleMetadata _metadataFor({
  required String size,
  required String difficulty,
}) {
  final parts = size.split('x');
  final width = int.parse(parts.first);
  final height = parts.length > 1 ? int.parse(parts[1]) : width;
  return core.PuzzleMetadata(
    engineVersion: 'test',
    rngId: 'test',
    size: core.SizeOpt(
      id: size,
      description: size,
      width: width,
      height: height,
    ),
    difficulty: core.DifficultyScore(value: 0.3, level: difficulty),
    seedStr: 'test:$size:$difficulty',
    seed64: size.hashCode ^ difficulty.hashCode,
  );
}

List<int> _flatten(List<List<int>> matrix) => [
  for (final row in matrix) ...row,
];

core.SudokuBoard _sudokuBoardFromMatrix(List<List<int>> matrix) {
  final cells = _flatten(matrix);
  final fixed = <bool>[];
  for (final value in cells) {
    fixed.add(value != 0);
  }
  return core.SudokuBoard(cells: cells, fixed: fixed);
}

final List<List<int>> _sudokuSolutionMatrix = <List<int>>[
  <int>[5, 3, 4, 6, 7, 8, 9, 1, 2],
  <int>[6, 7, 2, 1, 9, 5, 3, 4, 8],
  <int>[1, 9, 8, 3, 4, 2, 5, 6, 7],
  <int>[8, 5, 9, 7, 6, 1, 4, 2, 3],
  <int>[4, 2, 6, 8, 5, 3, 7, 9, 1],
  <int>[7, 1, 3, 9, 2, 4, 8, 5, 6],
  <int>[9, 6, 1, 5, 3, 7, 2, 8, 4],
  <int>[2, 8, 7, 4, 1, 9, 6, 3, 5],
  <int>[3, 4, 5, 2, 8, 6, 1, 7, 9],
];

final core.SudokuBoard _sudokuSolutionBoard = _sudokuBoardFromMatrix(
  _sudokuSolutionMatrix,
);

core.SudokuBoard buildSudokuPuzzleBoard() {
  final cleared = <Offset>[
    const Offset(0, 0),
    const Offset(1, 0),
    const Offset(4, 0),
    const Offset(0, 1),
    const Offset(3, 1),
    const Offset(5, 1),
    const Offset(4, 2),
    const Offset(7, 2),
    const Offset(8, 2),
  ];
  core.SudokuBoard board = _sudokuSolutionBoard;
  for (final position in cleared) {
    board = board.setCell(position.dy.toInt(), position.dx.toInt(), 0);
  }
  return board;
}

core.GeneratedPuzzle<core.SudokuBoard> buildSudokuPuzzle({
  bool solved = false,
  String difficulty = 'easy',
}) {
  final board = solved ? _sudokuSolutionBoard : buildSudokuPuzzleBoard();
  return core.GeneratedPuzzle<core.SudokuBoard>(
    state: board,
    meta: _metadataFor(size: '9x9', difficulty: difficulty),
  );
}

class TestSudokuEngine
    implements core.PuzzleEngine<core.SudokuBoard, core.SudokuMove> {
  TestSudokuEngine({this.engineId = 'sudoku_classic'})
    : _fixedCells = _deriveFixedCells(buildSudokuPuzzleBoard());

  final String engineId;
  final Set<int> _fixedCells;

  core.SudokuBoard get _solution => _sudokuSolutionBoard;
  core.SudokuBoard get _puzzle => buildSudokuPuzzleBoard();

  static Set<int> _deriveFixedCells(core.SudokuBoard board) {
    final fixed = <int>{};
    for (int row = 0; row < core.SudokuBoard.side; row++) {
      for (int col = 0; col < core.SudokuBoard.side; col++) {
        if (board.isFixed(row, col)) {
          fixed.add(row * core.SudokuBoard.side + col);
        }
      }
    }
    return fixed;
  }

  @override
  String get id => engineId;

  @override
  String get name => 'Test Sudoku Engine';

  @override
  String get version => '1.0.0';

  @override
  core.PuzzleCapabilities get capabilities =>
      const core.PuzzleCapabilities(supportsHints: false);

  @override
  core.PuzzleHint? requestHint({
    required core.SudokuBoard currentState,
    core.PuzzleHintRequest? request,
  }) {
    return null;
  }

  @override
  core.GeneratedPuzzle<core.SudokuBoard> generate({
    required String seedStr,
    required int seed64,
    required core.SizeOpt size,
    required core.DifficultyScore difficulty,
  }) {
    return core.GeneratedPuzzle<core.SudokuBoard>(
      state: _puzzle,
      meta: _metadataFor(
        size: '${size.width}x${size.height}',
        difficulty: difficulty.level,
      ),
    );
  }

  @override
  core.MoveResult<core.SudokuBoard> validateMove({
    required core.SudokuBoard currentState,
    required core.SudokuMove move,
  }) {
    final int index = move.row * core.SudokuBoard.side + move.col;
    if (_fixedCells.contains(index)) {
      return core.MoveResult.failure('Cell is fixed');
    }

    if (move.digit != 0 && _solution.cellAt(move.row, move.col) != move.digit) {
      return core.MoveResult.failure('Incorrect digit');
    }

    final updated = currentState.setCell(move.row, move.col, move.digit);
    return core.MoveResult.success(updated);
  }

  @override
  bool isSolved(core.SudokuBoard state) {
    for (int i = 0; i < state.cells.length; i++) {
      if (state.cells[i] != _solution.cells[i]) {
        return false;
      }
    }
    return true;
  }
}

core.GeneratedPuzzle<core.NonogramBoard> buildNonogramPuzzle() {
  final board = core.NonogramBoard(
    width: 5,
    height: 5,
    rowClues: const <List<int>>[
      <int>[5],
      <int>[1, 1],
      <int>[5],
      <int>[1, 1],
      <int>[5],
    ],
    columnClues: const <List<int>>[
      <int>[5],
      <int>[3],
      <int>[5],
      <int>[3],
      <int>[5],
    ],
    cells: List<int?>.generate(25, (index) => index.isEven ? 1 : null),
  );
  return core.GeneratedPuzzle<core.NonogramBoard>(
    state: board,
    meta: _metadataFor(size: '5x5', difficulty: 'easy'),
  );
}

core.GeneratedPuzzle<core.KakuroBoard> buildKakuroPuzzle() {
  final kinds = <core.KakuroCellKind>[
    core.KakuroCellKind.value,
    core.KakuroCellKind.value,
    core.KakuroCellKind.value,
    core.KakuroCellKind.value,
  ];
  final entries = <core.KakuroEntry>[
    const core.KakuroEntry(
      id: 0,
      direction: core.KakuroDirection.across,
      cells: <int>[0, 1],
      sum: 10,
    ),
    const core.KakuroEntry(
      id: 1,
      direction: core.KakuroDirection.across,
      cells: <int>[2, 3],
      sum: 7,
    ),
    const core.KakuroEntry(
      id: 2,
      direction: core.KakuroDirection.down,
      cells: <int>[0, 2],
      sum: 9,
    ),
    const core.KakuroEntry(
      id: 3,
      direction: core.KakuroDirection.down,
      cells: <int>[1, 3],
      sum: 8,
    ),
  ];
  final board = core.KakuroBoard(
    width: 2,
    height: 2,
    kinds: kinds,
    values: const <int>[1, 0, 4, 3],
    acrossClues: List<int?>.filled(4, null),
    downClues: List<int?>.filled(4, null),
    entries: entries,
    acrossEntryForCell: const <int>[0, 0, 1, 1],
    downEntryForCell: const <int>[2, 3, 2, 3],
  );
  return core.GeneratedPuzzle<core.KakuroBoard>(
    state: board,
    meta: _metadataFor(size: '2x2', difficulty: 'easy'),
  );
}

core.GeneratedPuzzle<core.SlitherlinkBoard> buildSlitherlinkPuzzle() {
  final base = core.SlitherlinkBoard.empty(
    width: 4,
    height: 4,
    clues: List<int?>.filled(16, null),
  );
  final solutionEdges = List<int>.filled(
    base.topology.edgeCount,
    core.SlitherlinkBoard.edgeOn,
  );
  final board = base.copyWith(edges: solutionEdges);
  return core.GeneratedPuzzle<core.SlitherlinkBoard>(
    state: board,
    meta: _metadataFor(size: '4x4', difficulty: 'easy'),
  );
}

core.GeneratedPuzzle<core.MathdokuBoard> buildMathdokuPuzzle() {
  const size = 4;
  final cages = <core.MathdokuCage>[
    for (int index = 0; index < size * size; index++)
      core.MathdokuCage(
        id: index,
        cells: <int>[index],
        operation: core.MathdokuOperation.equality,
        target: (index % size) + 1,
      ),
  ];
  final board = core.MathdokuBoard(
    size: size,
    cells: List<int>.generate(size * size, (index) => (index % size) + 1),
    cages: cages,
  );
  return core.GeneratedPuzzle<core.MathdokuBoard>(
    state: board,
    meta: _metadataFor(size: '4x4', difficulty: 'easy'),
  );
}

core.GeneratedPuzzle<core.KillerQueensBoard> buildKillerQueensPuzzle() {
  const size = 6;
  final List<core.KillerQueensCage> cages = <core.KillerQueensCage>[];
  for (int row = 0; row < size; row++) {
    for (int col = 0; col < size; col += 2) {
      final int index = row * size + col;
      final List<int> cageCells = <int>[index];
      if (col + 1 < size) {
        cageCells.add(index + 1);
      }
      cages.add(core.KillerQueensCage(cells: cageCells));
    }
  }

  final List<int> cells = List<int>.filled(size * size, 0);
  final List<bool> fixed = List<bool>.filled(size * size, false);
  final List<int> queenPositions = <int>[1, 9, 17, 18, 26, 34];
  final Set<int> givens = <int>{1, 26};

  for (final int index in queenPositions) {
    cells[index] = 1;
  }
  for (final int index in givens) {
    fixed[index] = true;
  }

  final board = core.KillerQueensBoard(
    size: size,
    cells: cells,
    fixed: fixed,
    cages: cages,
  );

  return core.GeneratedPuzzle<core.KillerQueensBoard>(
    state: board,
    meta: _metadataFor(size: '6x6', difficulty: 'easy'),
  );
}

core.GeneratedPuzzle<core.TakuzuBoard> buildTakuzuPuzzle() {
  const size = 4;
  final solution = <int>[0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1];
  final fixed = <bool>[
    true,
    true,
    true,
    true,
    true,
    false,
    false,
    false,
    false,
    false,
    true,
    true,
    true,
    true,
    false,
    false,
  ];
  final board = core.TakuzuBoard(size: size, cells: solution, fixed: fixed);
  return core.GeneratedPuzzle<core.TakuzuBoard>(
    state: board,
    meta: _metadataFor(size: '4x4', difficulty: 'easy'),
  );
}
