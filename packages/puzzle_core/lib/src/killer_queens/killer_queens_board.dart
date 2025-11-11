class KillerQueensCage {
  const KillerQueensCage({required this.cells});

  factory KillerQueensCage.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawCells = json['cells'] as List<dynamic>;
    return KillerQueensCage(
      cells: List<int>.unmodifiable(
        rawCells.map((dynamic value) => (value as num).toInt()),
      ),
    );
  }

  final List<int> cells;

  Map<String, dynamic> toJson() => <String, dynamic>{'cells': cells};

  @override
  bool operator ==(Object other) =>
      other is KillerQueensCage && _listEquals(cells, other.cells);

  @override
  int get hashCode => cells.hashCode;

  static bool _listEquals(List<int> a, List<int> b) {
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
}

class KillerQueensBoard {
  KillerQueensBoard({
    required this.size,
    required List<int> cells,
    required List<bool> fixed,
    required List<KillerQueensCage> cages,
  }) : cells = List<int>.unmodifiable(cells),
       fixed = List<bool>.unmodifiable(fixed),
       cages = List<KillerQueensCage>.unmodifiable(cages),
       _cageByCell = buildCageByCell(size, cages) {
    if (size <= 0) {
      throw ArgumentError('Killer Queens board must have positive size');
    }
    final int cellCount = size * size;
    if (this.cells.length != cellCount) {
      throw ArgumentError(
        'Expected $cellCount cells for $size x $size board; got '
        '${this.cells.length}',
      );
    }
    if (this.fixed.length != cellCount) {
      throw ArgumentError('Fixed flags must match cell count');
    }

    for (int i = 0; i < cellCount; i++) {
      final int value = this.cells[i];
      if (value != 0 && value != 1 && value != 2) {
        throw ArgumentError('Cell values must be 0, 1, or 2; found $value');
      }
      if (this.fixed[i] && value != 1) {
        throw ArgumentError('Fixed cells must contain a queen');
      }
    }

    _queenCount = this.cells.where((int value) => value == 1).length;
  }

  factory KillerQueensBoard.empty({
    required int size,
    List<KillerQueensCage> cages = const <KillerQueensCage>[],
  }) {
    final int cellCount = size * size;
    return KillerQueensBoard(
      size: size,
      cells: List<int>.filled(cellCount, 0, growable: false),
      fixed: List<bool>.filled(cellCount, false, growable: false),
      cages: cages,
    );
  }

  factory KillerQueensBoard.fromJson(Map<String, dynamic> json) {
    final int size = (json['size'] as num).toInt();
    final List<dynamic> rawCells = json['cells'] as List<dynamic>;
    final List<dynamic> rawFixed = json['fixed'] as List<dynamic>;
    final List<dynamic> rawCages =
        json['cages'] as List<dynamic>? ?? const <dynamic>[];

    return KillerQueensBoard(
      size: size,
      cells: rawCells.map((dynamic value) => (value as num).toInt()).toList(),
      fixed: rawFixed.map((dynamic value) => value as bool).toList(),
      cages: rawCages
          .map(
            (dynamic entry) => KillerQueensCage.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
    );
  }

  final int size;
  final List<int> cells;
  final List<bool> fixed;
  final List<KillerQueensCage> cages;
  final List<int> _cageByCell;
  late final int _queenCount;

  int get cellCount => cells.length;
  int get queenCount => _queenCount;

  List<int> get cageByCell => _cageByCell;

  int indexFor(int row, int col) => row * size + col;

  int valueAt(int row, int col) => cells[indexFor(row, col)];

  KillerQueensBoard setCell(int row, int col, int value, {bool? markFixed}) {
    if (row < 0 || row >= size || col < 0 || col >= size) {
      throw RangeError('Cell out of range');
    }
    if (value != 0 && value != 1 && value != 2) {
      throw ArgumentError('Value must be 0, 1, or 2');
    }
    final int index = indexFor(row, col);
    final List<int> updatedCells = List<int>.from(cells);
    final List<bool> updatedFixed = List<bool>.from(fixed);
    updatedCells[index] = value;
    if (markFixed != null) {
      updatedFixed[index] = markFixed;
    }
    return KillerQueensBoard(
      size: size,
      cells: updatedCells,
      fixed: updatedFixed,
      cages: cages,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'size': size,
    'cells': cells,
    'fixed': fixed,
    'cages': cages.map((KillerQueensCage cage) => cage.toJson()).toList(),
  };

  List<int> queenPositions() {
    final List<int> indices = <int>[];
    for (int i = 0; i < cells.length; i++) {
      if (cells[i] == 1) {
        indices.add(i);
      }
    }
    return indices;
  }

  static List<int> buildCageByCell(int size, List<KillerQueensCage> cages) {
    final int cellCount = size * size;
    final List<int> cageByCell = List<int>.filled(cellCount, -1);
    for (int cageIndex = 0; cageIndex < cages.length; cageIndex++) {
      final KillerQueensCage cage = cages[cageIndex];
      for (final int cell in cage.cells) {
        if (cell < 0 || cell >= cellCount) {
          throw ArgumentError('Cage cell out of range: $cell');
        }
        if (cageByCell[cell] != -1) {
          throw ArgumentError('Cell $cell assigned to multiple cages');
        }
        cageByCell[cell] = cageIndex;
      }
    }

    for (int i = 0; i < cellCount; i++) {
      if (cageByCell[i] == -1) {
        throw ArgumentError('Cell $i missing cage assignment');
      }
    }
    return List<int>.unmodifiable(cageByCell);
  }

  @override
  bool operator ==(Object other) {
    return other is KillerQueensBoard &&
        size == other.size &&
        _listEquals(cells, other.cells) &&
        _listEqualsBool(fixed, other.fixed) &&
        _listEqualsInt(cageByCell, other.cageByCell);
  }

  @override
  int get hashCode => Object.hash(
    size,
    Object.hashAll(cells),
    Object.hashAll(fixed),
    Object.hashAll(cageByCell),
  );

  static bool _listEquals(List<int> a, List<int> b) {
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

  static bool _listEqualsBool(List<bool> a, List<bool> b) {
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

  static bool _listEqualsInt(List<int> a, List<int> b) => _listEquals(a, b);

  KillerQueensBoard clearNonFixedQueens() {
    final List<int> updatedCells = List<int>.from(cells);
    for (int i = 0; i < updatedCells.length; i++) {
      if (!fixed[i]) {
        updatedCells[i] = 0;
      }
    }
    return KillerQueensBoard(
      size: size,
      cells: updatedCells,
      fixed: fixed,
      cages: cages,
    );
  }

  KillerQueensBoard copyWith({List<int>? cells, List<bool>? fixed}) {
    return KillerQueensBoard(
      size: size,
      cells: cells ?? this.cells,
      fixed: fixed ?? this.fixed,
      cages: cages,
    );
  }

  KillerQueensBoard placeQueens(
    List<int> queenIndices, {
    bool markFixed = false,
  }) {
    final List<int> updatedCells = List<int>.from(cells);
    final List<bool> updatedFixed = List<bool>.from(fixed);
    for (int i = 0; i < updatedCells.length; i++) {
      final bool hasQueen = queenIndices.contains(i);
      updatedCells[i] = hasQueen ? 1 : 0;
      if (markFixed) {
        updatedFixed[i] = hasQueen;
      }
    }
    return KillerQueensBoard(
      size: size,
      cells: updatedCells,
      fixed: updatedFixed,
      cages: cages,
    );
  }

  List<int> neighborsChebyshev(int index) {
    final int row = index ~/ size;
    final int col = index % size;
    final List<int> neighbors = <int>[];
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) {
          continue;
        }
        final int nr = row + dr;
        final int nc = col + dc;
        if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
          neighbors.add(indexFor(nr, nc));
        }
      }
    }
    return neighbors;
  }

  @override
  String toString() {
    return 'KillerQueensBoard(size: $size, cells: $cells, fixed: $fixed, cages: $cages)';
  }
}
