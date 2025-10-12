class NonogramMove {
  final int row;
  final int col;
  final int? value;

  const NonogramMove({
    required this.row,
    required this.col,
    required this.value,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'row': row,
        'col': col,
        'value': value,
      };

  factory NonogramMove.fromJson(Map<String, dynamic> json) => NonogramMove(
        row: json['row'] as int,
        col: json['col'] as int,
        value: json['value'] as int?,
      );
}
