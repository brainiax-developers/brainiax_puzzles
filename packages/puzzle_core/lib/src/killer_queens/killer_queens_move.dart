class KillerQueensMove {
  const KillerQueensMove({
    required this.row,
    required this.col,
    required this.value,
  });

  factory KillerQueensMove.fromJson(Map<String, dynamic> json) => KillerQueensMove(
        row: (json['row'] as num).toInt(),
        col: (json['col'] as num).toInt(),
        value: (json['value'] as num).toInt(),
      );

  final int row;
  final int col;
  final int value; // 0 for empty, 1 for queen

  Map<String, dynamic> toJson() => <String, dynamic>{
        'row': row,
        'col': col,
        'value': value,
      };

  @override
  bool operator ==(Object other) {
    return other is KillerQueensMove &&
        other.row == row &&
        other.col == col &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(row, col, value);

  @override
  String toString() => 'KillerQueensMove(row: $row, col: $col, value: $value)';
}
