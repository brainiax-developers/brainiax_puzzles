class NonogramLineSolver {
  static const int filled = 1;
  static const int empty = 0;

  static List<List<int>> generatePlacements(
    int length,
    List<int> clues, {
    List<int?>? current,
  }) {
    final List<List<int>> placements = <List<int>>[];
    final List<int?> constraint = current ?? List<int?>.filled(length, null);

    void dfs(int clueIndex, int position, List<int> buffer) {
      if (clueIndex == clues.length) {
        for (int i = position; i < length; i++) {
          if (!_matches(constraint[i], empty)) {
            return;
          }
          buffer[i] = empty;
        }
        placements.add(List<int>.from(buffer));
        return;
      }

      final int blockLength = clues[clueIndex];
      final int remainingLength = _tailLength(clues, clueIndex + 1);
      for (int start = position; start + blockLength <= length; start++) {
        final int end = start + blockLength;
        if (end + remainingLength > length) {
          break;
        }
        final List<int> candidate = List<int>.from(buffer);
        bool ok = true;

        for (int i = position; i < start; i++) {
          if (!_matches(constraint[i], empty)) {
            ok = false;
            break;
          }
          candidate[i] = empty;
        }
        if (!ok) {
          continue;
        }

        for (int i = start; i < end; i++) {
          if (!_matches(constraint[i], filled)) {
            ok = false;
            break;
          }
          candidate[i] = filled;
        }
        if (!ok) {
          continue;
        }

        if (end < length) {
          if (!_matches(constraint[end], empty)) {
            continue;
          }
          candidate[end] = empty;
        }

        dfs(clueIndex + 1, end + 1, candidate);
      }
    }

    final List<int> initial = List<int>.filled(length, empty);
    dfs(0, 0, initial);
    return placements;
  }

  static bool _matches(int? constraint, int desired) {
    return constraint == null || constraint == desired;
  }

  static int _tailLength(List<int> clues, int index) {
    if (index >= clues.length) {
      return 0;
    }
    int total = 0;
    for (int i = index; i < clues.length; i++) {
      total += clues[i];
    }
    total += clues.length - index - 1;
    return total;
  }

  static List<int?> intersectPlacements(List<List<int>> placements) {
    if (placements.isEmpty) {
      return <int?>[];
    }
    final int length = placements.first.length;
    final List<int?> result = List<int?>.filled(length, null);
    for (int i = 0; i < length; i++) {
      int? value;
      bool consistent = true;
      for (final List<int> placement in placements) {
        final int cell = placement[i];
        if (value == null) {
          value = cell;
        } else if (value != cell) {
          consistent = false;
          break;
        }
      }
      result[i] = consistent ? value : null;
    }
    return result;
  }

  static NonogramPropagationResult propagate(
    List<int?> current,
    List<int> clues,
  ) {
    final List<List<int>> placements =
        generatePlacements(current.length, clues, current: current);
    if (placements.isEmpty) {
      return NonogramPropagationResult(
        updated: List<int?>.from(current),
        changed: false,
        contradiction: true,
      );
    }
    final List<int?> intersection = intersectPlacements(placements);
    final List<int?> updated = List<int?>.from(current);
    bool changed = false;
    for (int i = 0; i < updated.length; i++) {
      if (updated[i] != intersection[i]) {
        updated[i] = intersection[i];
        changed = true;
      }
    }
    return NonogramPropagationResult(
      updated: updated,
      changed: changed,
      contradiction: false,
    );
  }
}

class NonogramPropagationResult {
  final List<int?> updated;
  final bool changed;
  final bool contradiction;

  const NonogramPropagationResult({
    required this.updated,
    required this.changed,
    required this.contradiction,
  });
}
