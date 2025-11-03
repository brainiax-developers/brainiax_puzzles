import 'kakuro_board.dart';

/// Format a Kakuro puzzle (and optional solution overlay) as a newspaper-style
/// text grid. Clue cells render as "across/down" with '/' separator.
/// Value cells render as '.' for puzzle or the digit from the solution when provided.
String formatKakuroText(KakuroBoard puzzle, {KakuroBoard? solution}) {
  final int w = puzzle.width;
  final int h = puzzle.height;

  // Compute string for each cell with a fixed width for alignment.
  const int cellW = 5; // enough for '##' or '12/34'
  String cellStr(int index) {
    if (puzzle.kinds[index] == KakuroCellKind.value) {
      final int digit = solution?.values[index] ?? 0;
      final String v = digit > 0 ? digit.toString() : '.';
      return _padCenter(v, cellW);
    }
    final int? a = puzzle.acrossClues[index];
    final int? d = puzzle.downClues[index];
    if (a == null && d == null) {
      return _padCenter('#', cellW);
    }
    final String left = a != null ? a.toString() : '';
    final String right = d != null ? d.toString() : '';
    final String s = '$left/$right';
    return _padCenter(s, cellW);
  }

  final StringBuffer out = StringBuffer();
  for (int r = 0; r < h; r++) {
    final StringBuffer row = StringBuffer();
    for (int c = 0; c < w; c++) {
      final int i = r * w + c;
      row.write(cellStr(i));
    }
    out.writeln(row.toString());
  }
  return out.toString();
}

/// Export a puzzle+solution pair to a friendly JSON structure for sharing.
Map<String, Object?> exportKakuroJson({required KakuroBoard puzzle, required KakuroBoard solution}) {
  return <String, Object?>{
    'puzzle': puzzle.toJson(),
    'solution': solution.toJson(),
  };
}

String _padCenter(String s, int width) {
  if (s.length >= width) return s;
  final int total = width - s.length;
  final int left = total ~/ 2;
  final int right = total - left;
  return '${' ' * left}$s${' ' * right}';
}
