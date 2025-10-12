class MathdokuMove {
  final int row;
  final int col;
  final int value;

  const MathdokuMove({
    required this.row,
    required this.col,
    required this.value,
  });

  factory MathdokuMove.fromJson(Map<String, dynamic> json) => MathdokuMove(
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
      other is MathdokuMove &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col &&
          value == other.value;

  @override
  int get hashCode => Object.hash(row, col, value);

  @override
  String toString() => 'MathdokuMove(row: $row, col: $col, value: $value)';
}
