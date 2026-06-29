/// Kakuro puzzle board representation.
///
/// Stores cell types, values, and clue sums.
class KakuroBoard {
  static const int cellBlack = 0;
  static const int cellClue = 1;
  static const int cellWhite = 2;

  final int width;
  final int height;

  /// Cell type: 0=black, 1=clue, 2=white
  final List<int> _cellTypes;

  /// Cell value: 0=unassigned, 1..9 for white cells
  final List<int> _cellValues;

  /// Across sum for clue cells. 0 if none.
  final List<int> _acrossClues;

  /// Down sum for clue cells. 0 if none.
  final List<int> _downClues;

  KakuroBoard._(
    this.width,
    this.height,
    this._cellTypes,
    this._cellValues,
    this._acrossClues,
    this._downClues,
  );

  factory KakuroBoard({
    required int width,
    required int height,
    required List<int> cellTypes,
    required List<int> cellValues,
    required List<int> acrossClues,
    required List<int> downClues,
  }) {
    final int cellCount = width * height;
    if (cellTypes.length != cellCount ||
        cellValues.length != cellCount ||
        acrossClues.length != cellCount ||
        downClues.length != cellCount) {
      throw ArgumentError('All board arrays must have length width * height');
    }
    return KakuroBoard._(
      width,
      height,
      List<int>.unmodifiable(cellTypes),
      List<int>.unmodifiable(cellValues),
      List<int>.unmodifiable(acrossClues),
      List<int>.unmodifiable(downClues),
    );
  }

  factory KakuroBoard.empty(int width, int height) {
    final int cellCount = width * height;
    return KakuroBoard(
      width: width,
      height: height,
      cellTypes: List<int>.filled(cellCount, cellBlack),
      cellValues: List<int>.filled(cellCount, 0),
      acrossClues: List<int>.filled(cellCount, 0),
      downClues: List<int>.filled(cellCount, 0),
    );
  }

  factory KakuroBoard.fromJson(Map<String, dynamic> json) {
    return KakuroBoard(
      width: json['width'] as int,
      height: json['height'] as int,
      cellTypes: (json['cellTypes'] as List).cast<int>(),
      cellValues: (json['cellValues'] as List).cast<int>(),
      acrossClues: (json['acrossClues'] as List).cast<int>(),
      downClues: (json['downClues'] as List).cast<int>(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'width': width,
        'height': height,
        'cellTypes': _cellTypes,
        'cellValues': _cellValues,
        'acrossClues': _acrossClues,
        'downClues': _downClues,
      };

  int get cellCount => width * height;

  List<int> get cellTypes => _cellTypes;
  List<int> get cellValues => _cellValues;
  List<int> get acrossClues => _acrossClues;
  List<int> get downClues => _downClues;

  bool isWhite(int index) => _cellTypes[index] == cellWhite;
  bool isClue(int index) => _cellTypes[index] == cellClue;
  bool isBlack(int index) => _cellTypes[index] == cellBlack;

  int getValue(int index) => _cellValues[index];

  KakuroBoard setCellValue(int index, int value) {
    if (value < 0 || value > 9) {
      throw ArgumentError.value(value, 'value', 'Must be between 0 and 9');
    }
    final List<int> newValues = List<int>.from(_cellValues);
    newValues[index] = value;
    return KakuroBoard(
      width: width,
      height: height,
      cellTypes: _cellTypes,
      cellValues: newValues,
      acrossClues: _acrossClues,
      downClues: _downClues,
    );
  }
}

/// Represents a single run of white cells and its required sum.
class KakuroRun {
  final List<int> cells;
  final int length;
  int sum;
  int usedMask;

  KakuroRun({
    required this.cells,
    required this.sum,
  })  : length = cells.length,
        usedMask = 0;
}
