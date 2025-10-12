import 'dart:convert';

class NonogramBoard {
  final int width;
  final int height;
  final List<List<int>> rowClues;
  final List<List<int>> columnClues;
  final List<int?> cells;

  NonogramBoard({
    required this.width,
    required this.height,
    required List<List<int>> rowClues,
    required List<List<int>> columnClues,
    required List<int?> cells,
  })  : rowClues =
            List<List<int>>.unmodifiable(rowClues.map((c) => List<int>.unmodifiable(c))),
        columnClues = List<List<int>>.unmodifiable(
          columnClues.map((c) => List<int>.unmodifiable(c)),
        ),
        cells = List<int?>.unmodifiable(List<int?>.from(cells));

  factory NonogramBoard.empty({
    required int width,
    required int height,
    required List<List<int>> rowClues,
    required List<List<int>> columnClues,
  }) {
    final List<int?> cells = List<int?>.filled(width * height, null);
    return NonogramBoard(
      width: width,
      height: height,
      rowClues: rowClues,
      columnClues: columnClues,
      cells: cells,
    );
  }

  int get cellCount => width * height;

  int indexOf(int row, int col) => row * width + col;

  int? cellAt(int row, int col) => cells[indexOf(row, col)];

  bool get isComplete => cells.every((int? value) => value != null);

  NonogramBoard copyWith({List<int?>? cells}) {
    return NonogramBoard(
      width: width,
      height: height,
      rowClues: rowClues,
      columnClues: columnClues,
      cells: cells ?? this.cells,
    );
  }

  List<int?> rowValues(int row) {
    final int start = row * width;
    return List<int?>.generate(width, (int offset) => cells[start + offset]);
  }

  List<int?> columnValues(int col) {
    return List<int?>.generate(height, (int row) => cells[row * width + col]);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'width': width,
        'height': height,
        'rowClues': rowClues,
        'columnClues': columnClues,
        'cells': cells,
      };

  factory NonogramBoard.fromJson(Map<String, dynamic> json) {
    return NonogramBoard(
      width: json['width'] as int,
      height: json['height'] as int,
      rowClues: (json['rowClues'] as List<dynamic>)
          .map((dynamic line) => List<int>.from(line as List))
          .toList(growable: false),
      columnClues: (json['columnClues'] as List<dynamic>)
          .map((dynamic line) => List<int>.from(line as List))
          .toList(growable: false),
      cells: List<int?>.from(json['cells'] as List),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! NonogramBoard) {
      return false;
    }
    return width == other.width &&
        height == other.height &&
        _listOfListEquals(rowClues, other.rowClues) &&
        _listOfListEquals(columnClues, other.columnClues) &&
        _listEquals(cells, other.cells);
  }

  @override
  int get hashCode => Object.hash(
        width,
        height,
        _listOfListHash(rowClues),
        _listOfListHash(columnClues),
        Object.hashAll(cells),
      );

  @override
  String toString() => jsonEncode(toJson());

  static bool _listEquals(List<Object?> a, List<Object?> b) {
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

  static bool _listOfListEquals(List<List<Object?>> a, List<List<Object?>> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (!_listEquals(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }

  static int _listOfListHash(List<List<Object?>> value) {
    return Object.hashAll(value.map(Object.hashAll));
  }
}
