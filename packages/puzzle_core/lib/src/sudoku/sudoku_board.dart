/// Representation of a classic 9x9 Sudoku board.
///
/// The board stores values as integers in the range [0, 9] where 0 represents
/// an empty cell. The [fixed] mask tracks the original clues that cannot be
/// modified by player moves.
class SudokuBoard {
  static const int side = 9;
  static const int cellCount = side * side;

  final List<int> _cells;
  final List<bool> _fixed;

  SudokuBoard._(this._cells, this._fixed);

  /// Create a board from cell values and fixed mask.
  factory SudokuBoard({required List<int> cells, required List<bool> fixed}) {
    if (cells.length != cellCount) {
      throw ArgumentError.value(cells.length, 'cells', 'Must be $cellCount');
    }
    if (fixed.length != cellCount) {
      throw ArgumentError.value(fixed.length, 'fixed', 'Must be $cellCount');
    }
    final List<int> normalised = List<int>.from(cells);
    final List<bool> fixedCopy = List<bool>.from(fixed);
    for (int i = 0; i < cellCount; i++) {
      final int value = normalised[i];
      if (value < 0 || value > 9) {
        throw ArgumentError.value(value, 'cells[$i]', 'Must be between 0 and 9');
      }
      if (value == 0) {
        fixedCopy[i] = false;
      }
    }
    return SudokuBoard._(List<int>.unmodifiable(normalised), List<bool>.unmodifiable(fixedCopy));
  }

  /// Construct an empty board.
  factory SudokuBoard.empty() => SudokuBoard(
        cells: List<int>.filled(cellCount, 0),
        fixed: List<bool>.filled(cellCount, false),
      );

  /// Create a board from a solution string of 81 digits.
  factory SudokuBoard.fromSolutionString(String solution) {
    if (solution.length != cellCount) {
      throw ArgumentError('Solution string must have length $cellCount');
    }
    final List<int> cells = List<int>.filled(cellCount, 0);
    for (int i = 0; i < solution.length; i++) {
      final int value = solution.codeUnitAt(i) - 48;
      if (value < 0 || value > 9) {
        throw ArgumentError('Solution contains invalid character at index $i');
      }
      cells[i] = value;
    }
    final List<bool> fixed = List<bool>.filled(cellCount, true);
    for (int i = 0; i < cellCount; i++) {
      if (cells[i] == 0) {
        fixed[i] = false;
      }
    }
    return SudokuBoard(cells: cells, fixed: fixed);
  }

  /// Parse from JSON.
  factory SudokuBoard.fromJson(Map<String, dynamic> json) {
    final List<dynamic> cellJson = (json['cells'] as List).cast<dynamic>();
    final List<dynamic> fixedJson = (json['fixed'] as List).cast<dynamic>();
    return SudokuBoard(
      cells: cellJson.map<int>((dynamic value) => value as int).toList(),
      fixed: fixedJson.map<bool>((dynamic value) => value == true).toList(),
    );
  }

  /// Convert to JSON representation.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'cells': _cells,
        'fixed': _fixed,
      };

  /// List of cell values.
  List<int> get cells => _cells;

  /// Fixed clue mask.
  List<bool> get fixed => _fixed;

  /// Get the value at [row], [col].
  int cellAt(int row, int col) => _cells[row * side + col];

  /// Whether the cell at [row], [col] is fixed.
  bool isFixed(int row, int col) => _fixed[row * side + col];

  /// Return a new board with the cell updated.
  SudokuBoard setCell(int row, int col, int value, {bool markFixed = false}) {
    if (value < 0 || value > 9) {
      throw ArgumentError.value(value, 'value', 'Must be between 0 and 9');
    }
    final int index = row * side + col;
    final List<int> newCells = List<int>.from(_cells);
    final List<bool> newFixed = List<bool>.from(_fixed);
    newCells[index] = value;
    newFixed[index] = markFixed && value != 0;
    return SudokuBoard(cells: newCells, fixed: newFixed);
  }

  /// Count the number of filled cells.
  int get clueCount => _cells.where((int value) => value != 0).length;

  /// Number of empty cells.
  int get emptyCount => cellCount - clueCount;

  /// Returns whether the board is completely filled.
  bool get isComplete => _cells.every((int value) => value != 0);

  /// Provides a canonical puzzle signature for telemetry/debugging.
  String get signature => _cells.join();

  /// Iterate all peers (row, column, and box) for the given index.
  static Iterable<int> peersOfIndex(int index) sync* {
    final int row = index ~/ side;
    final int col = index % side;
    for (int c = 0; c < side; c++) {
      final int idx = row * side + c;
      if (idx != index) {
        yield idx;
      }
    }
    for (int r = 0; r < side; r++) {
      final int idx = r * side + col;
      if (idx != index) {
        yield idx;
      }
    }
    final int boxRow = (row ~/ 3) * 3;
    final int boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        final int idx = r * side + c;
        if (idx != index && idx ~/ side != row && idx % side != col) {
          yield idx;
        }
      }
    }
  }

  /// Returns all row indices for [row].
  static List<int> rowIndices(int row) =>
      List<int>.generate(side, (int col) => row * side + col, growable: false);

  /// Returns all column indices for [col].
  static List<int> columnIndices(int col) =>
      List<int>.generate(side, (int row) => row * side + col, growable: false);

  /// Returns indices for the 3x3 box containing [row], [col].
  static List<int> boxIndices(int row, int col) {
    final int startRow = (row ~/ 3) * 3;
    final int startCol = (col ~/ 3) * 3;
    return List<int>.generate(9, (int i) {
      final int r = startRow + (i ~/ 3);
      final int c = startCol + (i % 3);
      return r * side + c;
    }, growable: false);
  }

  /// Provide an iterable of all unit index lists (rows, columns, boxes).
  static final List<List<int>> allUnits = <List<int>>[
    for (int r = 0; r < side; r++) rowIndices(r),
    for (int c = 0; c < side; c++) columnIndices(c),
    for (int br = 0; br < side; br += 3)
      for (int bc = 0; bc < side; bc += 3)
        boxIndices(br, bc),
  ];

  /// Provide an iterable over the peers per cell (cached for reuse).
  static final List<Set<int>> peers = List<Set<int>>.generate(cellCount, (int i) {
    return Set<int>.from(peersOfIndex(i));
  }, growable: false);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SudokuBoard &&
            runtimeType == other.runtimeType &&
            _cells.length == other._cells.length &&
            _fixed.length == other._fixed.length &&
            _cells.everyIndexed((int index, int value) => value == other._cells[index]) &&
            _fixed.everyIndexed((int index, bool value) => value == other._fixed[index]);
  }

  @override
  int get hashCode => Object.hashAll(_cells) ^ Object.hashAll(_fixed);

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer();
    for (int r = 0; r < side; r++) {
      if (r % 3 == 0 && r != 0) {
        buffer.writeln('------+-------+------');
      }
      for (int c = 0; c < side; c++) {
        if (c % 3 == 0 && c != 0) {
          buffer.write('| ');
        }
        final int value = cellAt(r, c);
        buffer.write(value == 0 ? '. ' : '$value ');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}

extension _ListEveryIndexed<T> on List<T> {
  bool everyIndexed(bool Function(int index, T value) test) {
    for (int i = 0; i < length; i++) {
      if (!test(i, this[i])) {
        return false;
      }
    }
    return true;
  }
}

/// Convenience for building boards from row major matrices.
SudokuBoard boardFromMatrix(List<List<int>> rows) {
  if (rows.length != SudokuBoard.side) {
    throw ArgumentError('Must provide ${SudokuBoard.side} rows');
  }
  final List<int> cells = <int>[];
  for (final List<int> row in rows) {
    if (row.length != SudokuBoard.side) {
      throw ArgumentError('Each row must have length ${SudokuBoard.side}');
    }
    cells.addAll(row);
  }
  return SudokuBoard(
    cells: cells,
    fixed: cells.map((int value) => value != 0).toList(growable: false),
  );
}
