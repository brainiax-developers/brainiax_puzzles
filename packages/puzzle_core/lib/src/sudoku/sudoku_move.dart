/// Sudoku move representing setting a digit in a specific cell.
class SudokuMove {
  final int row;
  final int col;
  final int digit;

  const SudokuMove({required this.row, required this.col, required this.digit});

  factory SudokuMove.fromJson(Map<String, dynamic> json) => SudokuMove(
        row: json['row'] as int? ?? 0,
        col: json['col'] as int? ?? 0,
        digit: json['digit'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'row': row,
        'col': col,
        'digit': digit,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SudokuMove &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col &&
          digit == other.digit;

  @override
  int get hashCode => Object.hash(row, col, digit);

  @override
  String toString() => 'SudokuMove(row: $row, col: $col, digit: $digit)';
}
