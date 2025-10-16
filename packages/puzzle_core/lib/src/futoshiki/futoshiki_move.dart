class FutoshikiMove {
  const FutoshikiMove({required this.row, required this.col, required this.value});

  factory FutoshikiMove.fromJson(Map<String, dynamic> json) => FutoshikiMove(
        row: json['row'] as int,
        col: json['col'] as int,
        value: json['value'] as int,
      );

  final int row;
  final int col;
  final int value;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'row': row,
        'col': col,
        'value': value,
      };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FutoshikiMove &&
            runtimeType == other.runtimeType &&
            row == other.row &&
            col == other.col &&
            value == other.value;
  }

  @override
  int get hashCode => Object.hash(row, col, value);

  @override
  String toString() => 'FutoshikiMove(row: $row, col: $col, value: $value)';
}
