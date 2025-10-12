/// Supported cage operations for Mathdoku puzzles.
enum MathdokuOperation {
  addition,
  subtraction,
  multiplication,
  division,
  equality,
}

extension MathdokuOperationJson on MathdokuOperation {
  String get jsonValue {
    switch (this) {
      case MathdokuOperation.addition:
        return 'add';
      case MathdokuOperation.subtraction:
        return 'subtract';
      case MathdokuOperation.multiplication:
        return 'multiply';
      case MathdokuOperation.division:
        return 'divide';
      case MathdokuOperation.equality:
        return 'equal';
    }
  }

  String get symbol {
    switch (this) {
      case MathdokuOperation.addition:
        return '+';
      case MathdokuOperation.subtraction:
        return '-';
      case MathdokuOperation.multiplication:
        return '×';
      case MathdokuOperation.division:
        return '÷';
      case MathdokuOperation.equality:
        return '=';
    }
  }

  static MathdokuOperation fromJson(String value) {
    switch (value) {
      case 'add':
        return MathdokuOperation.addition;
      case 'subtract':
        return MathdokuOperation.subtraction;
      case 'multiply':
        return MathdokuOperation.multiplication;
      case 'divide':
        return MathdokuOperation.division;
      case 'equal':
        return MathdokuOperation.equality;
      default:
        throw ArgumentError('Unknown Mathdoku operation: $value');
    }
  }
}

/// Description of a cage within a Mathdoku puzzle.
class MathdokuCage {
  final int id;
  final List<int> cells;
  final MathdokuOperation operation;
  final int target;

  MathdokuCage({
    required this.id,
    required List<int> cells,
    required this.operation,
    required this.target,
  }) : cells = List<int>.unmodifiable(cells) {
    if (cells.isEmpty) {
      throw ArgumentError('Cage $id must contain at least one cell');
    }
    for (final int index in cells) {
      if (index < 0) {
        throw ArgumentError('Cage $id contains invalid cell index: $index');
      }
    }
  }

  factory MathdokuCage.fromJson(Map<String, dynamic> json) {
    return MathdokuCage(
      id: json['id'] as int,
      cells: (json['cells'] as List<dynamic>).cast<int>(),
      operation: MathdokuOperationJson.fromJson(json['operation'] as String),
      target: json['target'] as int,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'cells': cells,
        'operation': operation.jsonValue,
        'target': target,
      };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MathdokuCage &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            target == other.target &&
            operation == other.operation &&
            _listEquals(cells, other.cells);
  }

  @override
  int get hashCode => Object.hash(id, target, operation, Object.hashAll(cells));

  @override
  String toString() =>
      'MathdokuCage(id: $id, target: $target, op: ${operation.jsonValue}, cells: $cells)';
}

/// Immutable representation of a Mathdoku board.
class MathdokuBoard {
  MathdokuBoard({
    required this.size,
    required List<int> cells,
    required List<MathdokuCage> cages,
  })  : cells = List<int>.unmodifiable(cells),
        cages = List<MathdokuCage>.unmodifiable(cages),
        _cageIndexByCell = _buildCageIndex(size, cells.length, cages) {
    final int expectedCellCount = size * size;
    if (expectedCellCount <= 0) {
      throw ArgumentError('Mathdoku board must have positive dimensions');
    }
    if (cells.length != expectedCellCount) {
      throw ArgumentError('Expected $expectedCellCount cells, got ${cells.length}');
    }
    for (final int value in cells) {
      if (value < 0 || value > size) {
        throw ArgumentError('Cell values must be in range 0..$size');
      }
    }
    if (cages.isEmpty) {
      throw ArgumentError('Mathdoku board must contain at least one cage');
    }
    final Set<int> seen = <int>{};
    for (final MathdokuCage cage in cages) {
      for (final int index in cage.cells) {
        if (index < 0 || index >= expectedCellCount) {
          throw ArgumentError('Cage ${cage.id} references invalid cell $index');
        }
        if (!seen.add(index)) {
          throw ArgumentError('Cell $index appears in multiple cages');
        }
      }
    }
    if (seen.length != expectedCellCount) {
      throw ArgumentError('Some cells are not covered by any cage');
    }
  }

  factory MathdokuBoard.empty({
    required int size,
    required List<MathdokuCage> cages,
  }) {
    final List<int> cells = List<int>.filled(size * size, 0);
    return MathdokuBoard(size: size, cells: cells, cages: cages);
  }

  factory MathdokuBoard.fromJson(Map<String, dynamic> json) {
    final int size = json['size'] as int;
    final List<int> cells = (json['cells'] as List<dynamic>).cast<int>();
    final List<dynamic> cageJson = json['cages'] as List<dynamic>;
    final List<MathdokuCage> cages = cageJson
        .map((dynamic entry) => MathdokuCage.fromJson(
            Map<String, dynamic>.from(entry as Map<dynamic, dynamic>)))
        .toList(growable: false);
    return MathdokuBoard(size: size, cells: cells, cages: cages);
  }

  final int size;
  final List<int> cells;
  final List<MathdokuCage> cages;
  final List<int> _cageIndexByCell;

  int get cellCount => size * size;

  MathdokuCage cageForCellIndex(int index) => cages[_cageIndexByCell[index]];

  MathdokuCage cageAt(int row, int col) => cageForCellIndex(row * size + col);

  int cellAt(int row, int col) => cells[row * size + col];

  bool get isComplete => cells.every((int value) => value != 0);

  MathdokuBoard setCell(int row, int col, int value) {
    final int index = row * size + col;
    final List<int> updated = List<int>.from(cells);
    updated[index] = value;
    return MathdokuBoard(size: size, cells: updated, cages: cages);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'size': size,
        'cells': cells,
        'cages': cages.map((MathdokuCage cage) => cage.toJson()).toList(),
      };

  Iterable<int> rowIndices(int row) sync* {
    for (int col = 0; col < size; col++) {
      yield row * size + col;
    }
  }

  Iterable<int> columnIndices(int col) sync* {
    for (int row = 0; row < size; row++) {
      yield row * size + col;
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MathdokuBoard &&
            runtimeType == other.runtimeType &&
            size == other.size &&
            _listEquals(cells, other.cells) &&
            _listEquals(cages, other.cages);
  }

  @override
  int get hashCode => Object.hash(size, Object.hashAll(cells), Object.hashAll(cages));

  static List<int> _buildCageIndex(
    int size,
    int cellLength,
    List<MathdokuCage> cages,
  ) {
    final List<int> mapping = List<int>.filled(cellLength, -1);
    for (int i = 0; i < cages.length; i++) {
      for (final int index in cages[i].cells) {
        if (index < 0 || index >= cellLength) {
          throw ArgumentError('Cage ${cages[i].id} references invalid cell $index');
        }
        if (mapping[index] != -1) {
          throw ArgumentError('Cell $index belongs to multiple cages');
        }
        mapping[index] = i;
      }
    }
    if (mapping.contains(-1)) {
      throw ArgumentError('All cells must be assigned to a cage');
    }
    return List<int>.unmodifiable(mapping);
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
