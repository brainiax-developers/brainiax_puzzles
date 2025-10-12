class TakuzuMove {
  final int row;
  final int col;
  final int value;

  const TakuzuMove({
    required this.row,
    required this.col,
    required this.value,
  });

  factory TakuzuMove.fromJson(Map<String, dynamic> json) => TakuzuMove(
        row: json['row'] as int? ?? 0,
        col: json['col'] as int? ?? 0,
        value: json['value'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'row': row,
        'col': col,
        'value': value,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TakuzuMove &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col &&
          value == other.value;

  @override
  int get hashCode => Object.hash(row, col, value);

  @override
  String toString() => 'TakuzuMove(row: $row, col: $col, value: $value)';
}
