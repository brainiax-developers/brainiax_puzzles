part of puzzle_core_kakuro_generator;

class KakuroSolution {
  KakuroSolution({
    required this.values,
    required this.entrySums,
  });

  final List<int> values;
  final Map<int, int> entrySums;
}

KakuroSolution? buildSolutionFirst(KakuroLayout template, SeededRng rng) {
  final int cellCount = template.width * template.height;
  final List<int> values = List<int>.filled(cellCount, 0);
  final Map<int, Set<int>> usedAcross = <int, Set<int>>{};
  final Map<int, Set<int>> usedDown = <int, Set<int>>{};

  final List<int> cells = List<int>.from(template.valueCells);
  cells.sort((int a, int b) {
    int al = 0, bl = 0;
    final int ae = template.acrossEntryForCell[a];
    final int be = template.acrossEntryForCell[b];
    final int ad = template.downEntryForCell[a];
    final int bd = template.downEntryForCell[b];
    if (ae >= 0) al += template.entries[ae].length;
    if (ad >= 0) al += template.entries[ad].length;
    if (be >= 0) bl += template.entries[be].length;
    if (bd >= 0) bl += template.entries[bd].length;
    return al.compareTo(bl);
  });

  bool backtrack(int index) {
    if (index >= cells.length) {
      return true;
    }
    final int cell = cells[index];
    final int ae = template.acrossEntryForCell[cell];
    final int de = template.downEntryForCell[cell];
    final Set<int> ua = usedAcross.putIfAbsent(ae, () => <int>{});
    final Set<int> ud = usedDown.putIfAbsent(de, () => <int>{});
    final List<int> digits = <int>[];
    for (int d = 1; d <= 9; d++) {
      if (!ua.contains(d) && !ud.contains(d)) {
        digits.add(d);
      }
    }
    if (digits.isEmpty) {
      return false;
    }
    final List<int> order = rng.permute(digits);
    for (final int d in order) {
      ua.add(d);
      ud.add(d);
      values[cell] = d;
      if (backtrack(index + 1)) {
        return true;
      }
      values[cell] = 0;
      ua.remove(d);
      ud.remove(d);
    }
    return false;
  }

  if (!backtrack(0)) {
    return null;
  }

  final Map<int, int> entrySums = <int, int>{};
  for (final KakuroLayoutEntry entry in template.entries) {
    int sum = 0;
    final Set<int> seen = <int>{};
    for (final int idx in entry.cells) {
      final int v = values[idx];
      if (v == 0 || !seen.add(v)) {
        return null;
      }
      sum += v;
    }
    entrySums[entry.id] = sum;
  }

  return KakuroSolution(values: values, entrySums: entrySums);
}
