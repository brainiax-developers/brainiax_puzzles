class TakuzuBoard {
  static const int emptyValue = -1;

  TakuzuBoard({
    required this.size,
    required List<int> cells,
    required List<bool> fixed,
  })  : cells = List<int>.unmodifiable(List<int>.from(cells)),
        fixed = List<bool>.unmodifiable(List<bool>.from(fixed)) {
    if (size <= 0 || size.isOdd) {
      throw ArgumentError('Takuzu board size must be a positive even number');
    }
    final int expected = size * size;
    if (this.cells.length != expected) {
      throw ArgumentError('Expected $expected cells but got ${this.cells.length}');
    }
    if (this.fixed.length != expected) {
      throw ArgumentError('Expected $expected fixed flags but got ${this.fixed.length}');
    }
    for (int i = 0; i < expected; i++) {
      final int value = this.cells[i];
      if (value != emptyValue && value != 0 && value != 1) {
        throw ArgumentError('Takuzu cell values must be -1, 0 or 1');
      }
      if (this.fixed[i] && value == emptyValue) {
        throw ArgumentError('Fixed cells must contain a value');
      }
    }
  }

  factory TakuzuBoard.empty(int size) {
    final int cellCount = size * size;
    return TakuzuBoard(
      size: size,
      cells: List<int>.filled(cellCount, emptyValue),
      fixed: List<bool>.filled(cellCount, false),
    );
  }

  factory TakuzuBoard.fromJson(Map<String, dynamic> json) {
    final int size = json['size'] as int;
    final List<int> cells = List<int>.from(json['cells'] as List<dynamic>);
    final List<bool> fixed =
        (json['fixed'] as List<dynamic>).map((dynamic v) => v as bool).toList();
    return TakuzuBoard(size: size, cells: cells, fixed: fixed);
  }

  final int size;
  final List<int> cells;
  final List<bool> fixed;

  int get cellCount => size * size;

  int cellIndex(int row, int col) => row * size + col;

  int cellAt(int row, int col) => cells[cellIndex(row, col)];

  bool isFixed(int row, int col) => fixed[cellIndex(row, col)];

  bool get isComplete => !cells.contains(emptyValue);

  TakuzuBoard setCell(int row, int col, int value, {bool? markFixed}) {
    final int index = cellIndex(row, col);
    final List<int> updatedCells = List<int>.from(cells);
    updatedCells[index] = value;
    final List<bool> updatedFixed = List<bool>.from(fixed);
    if (markFixed != null) {
      updatedFixed[index] = markFixed;
    }
    return TakuzuBoard(size: size, cells: updatedCells, fixed: updatedFixed);
  }

  TakuzuBoard copyWith({List<int>? cells, List<bool>? fixed}) {
    return TakuzuBoard(
      size: size,
      cells: cells ?? this.cells,
      fixed: fixed ?? this.fixed,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'size': size,
        'cells': cells,
        'fixed': fixed,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! TakuzuBoard) {
      return false;
    }
    return size == other.size &&
        _listEquals(cells, other.cells) &&
        _listEquals(fixed, other.fixed);
  }

  @override
  int get hashCode => Object.hash(size, Object.hashAll(cells), Object.hashAll(fixed));

  @override
  String toString() => 'TakuzuBoard(size: $size, cells: $cells)';
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
