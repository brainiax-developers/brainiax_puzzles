/// Represents a move in a Kakuro puzzle.
class KakuroMove {
  /// The index of the cell being modified.
  final int index;

  /// The new value for the cell (0-9). 0 represents clearing the cell.
  final int value;

  const KakuroMove({
    required this.index,
    required this.value,
  });

  factory KakuroMove.fromJson(Map<String, dynamic> json) {
    return KakuroMove(
      index: json['index'] as int,
      value: json['value'] as int,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'index': index,
        'value': value,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KakuroMove &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          value == other.value;

  @override
  int get hashCode => index.hashCode ^ value.hashCode;

  @override
  String toString() => 'KakuroMove(index: $index, value: $value)';
}
