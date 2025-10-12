class FutoshikiInequality {
  const FutoshikiInequality({required this.lesser, required this.greater})
      : assert(lesser >= 0, 'Cell indices must be non-negative'),
        assert(greater >= 0, 'Cell indices must be non-negative'),
        assert(lesser != greater, 'Inequality cannot reference the same cell twice');

  factory FutoshikiInequality.fromJson(Map<String, dynamic> json) {
    return FutoshikiInequality(
      lesser: json['lesser'] as int,
      greater: json['greater'] as int,
    );
  }

  final int lesser;
  final int greater;

  bool involves(int index) => index == lesser || index == greater;

  FutoshikiInequality reversed() =>
      FutoshikiInequality(lesser: greater, greater: lesser);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lesser': lesser,
        'greater': greater,
      };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FutoshikiInequality &&
            runtimeType == other.runtimeType &&
            lesser == other.lesser &&
            greater == other.greater;
  }

  @override
  int get hashCode => Object.hash(lesser, greater);

  @override
  String toString() => 'FutoshikiInequality($lesser < $greater)';
}

class FutoshikiBoard {
  FutoshikiBoard({
    required this.size,
    required List<int> cells,
    required List<bool> fixed,
    required List<FutoshikiInequality> inequalities,
  })  : cells = List<int>.unmodifiable(cells),
        fixed = List<bool>.unmodifiable(fixed),
        inequalities = List<FutoshikiInequality>.unmodifiable(inequalities) {
    if (size <= 0) {
      throw ArgumentError('Futoshiki board must have positive size');
    }
    final int cellCount = size * size;
    if (cells.length != cellCount) {
      throw ArgumentError('Expected $cellCount cells, got ${cells.length}');
    }
    if (fixed.length != cellCount) {
      throw ArgumentError('Expected $cellCount fixed flags, got ${fixed.length}');
    }
    for (int i = 0; i < cellCount; i++) {
      final int value = cells[i];
      if (value < 0 || value > size) {
        throw ArgumentError('Cell values must be in range 0..$size');
      }
      if (fixed[i] && value == 0) {
        throw ArgumentError('Fixed cells must contain non-zero values');
      }
    }
    for (final FutoshikiInequality inequality in inequalities) {
      if (inequality.lesser < 0 || inequality.lesser >= cellCount) {
        throw ArgumentError(
            'Inequality references invalid cell ${inequality.lesser}');
      }
      if (inequality.greater < 0 || inequality.greater >= cellCount) {
        throw ArgumentError(
            'Inequality references invalid cell ${inequality.greater}');
      }
      final int delta = (inequality.lesser - inequality.greater).abs();
      if (delta != 1 && delta != size) {
        throw ArgumentError(
          'Inequalities must connect orthogonal neighbours: $inequality',
        );
      }
      final int rowA = inequality.lesser ~/ size;
      final int colA = inequality.lesser % size;
      final int rowB = inequality.greater ~/ size;
      final int colB = inequality.greater % size;
      if (rowA != rowB && colA != colB) {
        throw ArgumentError(
          'Inequalities must connect orthogonal neighbours: $inequality',
        );
      }
    }
  }

  factory FutoshikiBoard.empty({
    required int size,
    List<FutoshikiInequality> inequalities = const <FutoshikiInequality>[],
  }) {
    final int cellCount = size * size;
    return FutoshikiBoard(
      size: size,
      cells: List<int>.filled(cellCount, 0),
      fixed: List<bool>.filled(cellCount, false),
      inequalities: inequalities,
    );
  }

  factory FutoshikiBoard.fromJson(Map<String, dynamic> json) {
    final int size = json['size'] as int;
    final List<int> cells = (json['cells'] as List<dynamic>).cast<int>();
    final List<bool> fixed =
        (json['fixed'] as List<dynamic>).map((dynamic v) => v as bool).toList();
    final List<dynamic> inequalityJson = json['inequalities'] as List<dynamic>;
    final List<FutoshikiInequality> inequalities = inequalityJson
        .map((dynamic entry) => FutoshikiInequality.fromJson(
            Map<String, dynamic>.from(entry as Map<dynamic, dynamic>)))
        .toList(growable: false);
    return FutoshikiBoard(
      size: size,
      cells: cells,
      fixed: fixed,
      inequalities: inequalities,
    );
  }

  final int size;
  final List<int> cells;
  final List<bool> fixed;
  final List<FutoshikiInequality> inequalities;

  int get cellCount => size * size;

  int cellAt(int row, int col) => cells[row * size + col];

  bool isFixed(int row, int col) => fixed[row * size + col];

  bool get isComplete => cells.every((int value) => value != 0);

  FutoshikiBoard setCell(int row, int col, int value, {bool? markFixed}) {
    final int index = row * size + col;
    final List<int> updatedCells = List<int>.from(cells);
    updatedCells[index] = value;
    final List<bool> updatedFixed = List<bool>.from(fixed);
    if (markFixed != null) {
      updatedFixed[index] = markFixed;
    }
    return FutoshikiBoard(
      size: size,
      cells: updatedCells,
      fixed: updatedFixed,
      inequalities: inequalities,
    );
  }

  FutoshikiBoard withInequalities(List<FutoshikiInequality> updated) {
    return FutoshikiBoard(
      size: size,
      cells: cells,
      fixed: fixed,
      inequalities: updated,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'size': size,
        'cells': cells,
        'fixed': fixed,
        'inequalities': inequalities.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FutoshikiBoard &&
            runtimeType == other.runtimeType &&
            size == other.size &&
            _listEquals(cells, other.cells) &&
            _listEquals(fixed, other.fixed) &&
            _listEquals(inequalities, other.inequalities);
  }

  @override
  int get hashCode =>
      Object.hash(size, Object.hashAll(cells), Object.hashAll(fixed), Object.hashAll(inequalities));

  @override
  String toString() => 'FutoshikiBoard(size: $size, cells: $cells)';
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
