class KakuroMove {
  const KakuroMove({
    required this.row,
    required this.col,
    required this.digit,
  });

  final int row;
  final int col;
  final int digit;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'row': row,
        'col': col,
        'digit': digit,
      };

  factory KakuroMove.fromJson(Map<String, dynamic> json) => KakuroMove(
        row: json['row'] as int,
        col: json['col'] as int,
        digit: json['digit'] as int,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KakuroMove &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col &&
          digit == other.digit;

  @override
  int get hashCode => Object.hash(row, col, digit);
}
