import 'dart:convert';

enum KakuroDirection { across, down }

enum KakuroCellKind { block, value }

class KakuroEntry {
  const KakuroEntry({
    required this.id,
    required this.direction,
    required this.cells,
    required this.sum,
  });

  final int id;
  final KakuroDirection direction;
  final List<int> cells;
  final int sum;

  KakuroEntry copyWith({int? sum}) => KakuroEntry(
        id: id,
        direction: direction,
        cells: cells,
        sum: sum ?? this.sum,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'direction': direction.index,
        'cells': cells,
        'sum': sum,
      };

  factory KakuroEntry.fromJson(Map<String, dynamic> json) => KakuroEntry(
        id: json['id'] as int,
        direction: KakuroDirection.values[json['direction'] as int],
        cells: List<int>.from(json['cells'] as List),
        sum: json['sum'] as int,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KakuroEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          direction == other.direction &&
          _listEquals(cells, other.cells) &&
          sum == other.sum;

  @override
  int get hashCode => Object.hash(id, direction, Object.hashAll(cells), sum);

  static bool _listEquals(List<int> a, List<int> b) {
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
}

class KakuroBoard {
  KakuroBoard({
    required this.width,
    required this.height,
    required List<KakuroCellKind> kinds,
    required List<int> values,
    required List<int?> acrossClues,
    required List<int?> downClues,
    required List<KakuroEntry> entries,
    required List<int> acrossEntryForCell,
    required List<int> downEntryForCell,
  })  : kinds = List<KakuroCellKind>.unmodifiable(kinds),
        values = List<int>.unmodifiable(values),
        acrossClues = List<int?>.unmodifiable(acrossClues),
        downClues = List<int?>.unmodifiable(downClues),
        entries = List<KakuroEntry>.unmodifiable(entries),
        acrossEntryForCell = List<int>.unmodifiable(acrossEntryForCell),
        downEntryForCell = List<int>.unmodifiable(downEntryForCell) {
    if (this.values.length != cellCount) {
      throw ArgumentError('values length mismatch: expected $cellCount');
    }
    if (this.kinds.length != cellCount) {
      throw ArgumentError('kinds length mismatch: expected $cellCount');
    }
    if (this.acrossClues.length != cellCount || this.downClues.length != cellCount) {
      throw ArgumentError('clue arrays must match cell count');
    }
    if (this.acrossEntryForCell.length != cellCount ||
        this.downEntryForCell.length != cellCount) {
      throw ArgumentError('entry maps must match cell count');
    }
  }

  final int width;
  final int height;
  final List<KakuroCellKind> kinds;
  final List<int> values;
  final List<int?> acrossClues;
  final List<int?> downClues;
  final List<KakuroEntry> entries;
  final List<int> acrossEntryForCell;
  final List<int> downEntryForCell;

  int get cellCount => width * height;

  bool isPlayableIndex(int index) => kinds[index] == KakuroCellKind.value;

  bool isPlayable(int row, int col) => isPlayableIndex(indexOf(row, col));

  int indexOf(int row, int col) => row * width + col;

  int valueAt(int row, int col) => values[indexOf(row, col)];

  bool get isComplete {
    for (int i = 0; i < cellCount; i++) {
      if (kinds[i] == KakuroCellKind.value && values[i] == 0) {
        return false;
      }
    }
    return true;
  }

  KakuroBoard copyWith({List<int>? values}) => KakuroBoard(
        width: width,
        height: height,
        kinds: kinds,
        values: values ?? this.values,
        acrossClues: acrossClues,
        downClues: downClues,
        entries: entries,
        acrossEntryForCell: acrossEntryForCell,
        downEntryForCell: downEntryForCell,
      );

  KakuroBoard setValue(int index, int digit) {
    final List<int> newValues = List<int>.from(values);
    newValues[index] = digit;
    return copyWith(values: newValues);
  }

  KakuroEntry entryForCell(int index, KakuroDirection direction) {
    final int entryId =
        direction == KakuroDirection.across ? acrossEntryForCell[index] : downEntryForCell[index];
    if (entryId < 0) {
      throw ArgumentError('Cell $index has no ${direction.name} entry');
    }
    return entries[entryId];
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'width': width,
        'height': height,
        'kinds': kinds.map((KakuroCellKind kind) => kind.index).toList(growable: false),
        'values': values,
        'acrossClues': acrossClues,
        'downClues': downClues,
        'entries': entries.map((KakuroEntry entry) => entry.toJson()).toList(growable: false),
        'acrossEntryForCell': acrossEntryForCell,
        'downEntryForCell': downEntryForCell,
      };

  factory KakuroBoard.fromJson(Map<String, dynamic> json) {
    final List<KakuroCellKind> kinds =
        (json['kinds'] as List).map((dynamic value) => KakuroCellKind.values[value as int]).toList();
    return KakuroBoard(
      width: json['width'] as int,
      height: json['height'] as int,
      kinds: kinds,
      values: List<int>.from(json['values'] as List),
      acrossClues: List<int?>.from(json['acrossClues'] as List),
      downClues: List<int?>.from(json['downClues'] as List),
      entries: (json['entries'] as List)
          .map((dynamic raw) => KakuroEntry.fromJson(Map<String, dynamic>.from(raw as Map)))
          .toList(growable: false),
      acrossEntryForCell: List<int>.from(json['acrossEntryForCell'] as List),
      downEntryForCell: List<int>.from(json['downEntryForCell'] as List),
    );
  }

  @override
  String toString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! KakuroBoard) {
      return false;
    }
    return width == other.width &&
        height == other.height &&
        _listEquals(kinds, other.kinds) &&
        _listEquals(values, other.values) &&
        _listEquals(acrossClues, other.acrossClues) &&
        _listEquals(downClues, other.downClues) &&
        _entryListEquals(entries, other.entries) &&
        _listEquals(acrossEntryForCell, other.acrossEntryForCell) &&
        _listEquals(downEntryForCell, other.downEntryForCell);
  }

  @override
  int get hashCode => Object.hash(
        width,
        height,
        Object.hashAll(kinds),
        Object.hashAll(values),
        Object.hashAll(acrossClues),
        Object.hashAll(downClues),
        Object.hashAll(entries),
        Object.hashAll(acrossEntryForCell),
        Object.hashAll(downEntryForCell),
      );

  static bool _listEquals<T>(List<T> a, List<T> b) {
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

  static bool _entryListEquals(List<KakuroEntry> a, List<KakuroEntry> b) {
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
}
