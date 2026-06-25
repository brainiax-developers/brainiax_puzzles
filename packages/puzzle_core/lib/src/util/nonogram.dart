class NonogramLineSolver {
  static const int filled = 1;
  static const int empty = 0;

  static final NonogramLineCache _sharedCache = NonogramLineCache();

  static List<List<int>> generatePlacements(
    int length,
    List<int> clues, {
    List<int?>? current,
  }) {
    if (current != null && current.length != length) {
      throw ArgumentError.value(
        current.length,
        'current.length',
        'must match line length',
      );
    }
    final NonogramLineSummary summary = _sharedCache.summary(
      current ?? List<int?>.filled(length, null),
      clues,
    );
    return summary.placements
        .map((List<int> placement) => List<int>.from(placement))
        .toList(growable: false);
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
    List<int> clues, {
    NonogramLineCache? cache,
  }) {
    final NonogramLineSummary summary = (cache ?? _sharedCache).summary(
      current,
      clues,
    );
    if (summary.contradiction) {
      return NonogramPropagationResult(
        updated: List<int?>.from(current),
        changed: false,
        contradiction: true,
      );
    }
    final List<int?> updated = List<int?>.from(current);
    bool changed = false;
    for (int i = 0; i < updated.length; i++) {
      if (updated[i] != summary.intersection[i]) {
        updated[i] = summary.intersection[i];
        changed = true;
      }
    }
    return NonogramPropagationResult(
      updated: updated,
      changed: changed,
      contradiction: false,
    );
  }

  static List<List<int>> _generatePlacementPool(int length, List<int> clues) {
    final List<List<int>> placements = <List<int>>[];
    final List<int?> constraint = List<int?>.filled(length, null);

    final int clueSum = clues.fold<int>(0, (int sum, int value) => sum + value);
    final int minimumRequired =
        clueSum + (clues.isEmpty ? 0 : clues.length - 1);
    if (minimumRequired > length) {
      return placements;
    }

    final int knownFilled = constraint
        .where((int? value) => value == filled)
        .length;
    if (knownFilled > clueSum) {
      return placements;
    }

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
}

class NonogramLineCache {
  final Map<_LineKey, List<List<int>>> _placementPools =
      <_LineKey, List<List<int>>>{};
  final Map<_LineSummaryKey, NonogramLineSummary> _summaries =
      <_LineSummaryKey, NonogramLineSummary>{};

  int cacheHits = 0;
  int cacheMisses = 0;

  List<List<int>> placementPool(int length, List<int> clues) {
    final _LineKey key = _LineKey(length, clues);
    final List<List<int>>? cached = _placementPools[key];
    if (cached != null) {
      cacheHits++;
      return cached;
    }
    cacheMisses++;
    final List<List<int>> generated = List<List<int>>.unmodifiable(
      NonogramLineSolver._generatePlacementPool(
        length,
        key.clues,
      ).map((List<int> placement) => List<int>.unmodifiable(placement)),
    );
    _placementPools[key] = generated;
    return generated;
  }

  NonogramLineSummary summary(List<int?> current, List<int> clues) {
    final _LineKey lineKey = _LineKey(current.length, clues);
    final _KnownMasks masks = _KnownMasks.fromLine(current);
    final _LineSummaryKey key = _LineSummaryKey(
      lineKey,
      masks.filledMask,
      masks.emptyMask,
    );
    final NonogramLineSummary? cached = _summaries[key];
    if (cached != null) {
      cacheHits++;
      return cached;
    }
    cacheMisses++;

    final List<List<int>> pool = placementPool(current.length, lineKey.clues);
    final List<List<int>> surviving = <List<int>>[];
    for (final List<int> placement in pool) {
      if (_matchesMasks(placement, masks)) {
        surviving.add(placement);
      }
    }

    final NonogramLineSummary summary = NonogramLineSummary(
      placements: List<List<int>>.unmodifiable(surviving),
      intersection: surviving.isEmpty
          ? <int?>[]
          : List<int?>.unmodifiable(
              NonogramLineSolver.intersectPlacements(surviving),
            ),
      contradiction: surviving.isEmpty,
    );
    _summaries[key] = summary;
    return summary;
  }

  static bool _matchesMasks(List<int> placement, _KnownMasks masks) {
    for (int i = 0; i < placement.length; i++) {
      final BigInt bit = BigInt.one << i;
      if ((masks.filledMask & bit) != BigInt.zero &&
          placement[i] != NonogramLineSolver.filled) {
        return false;
      }
      if ((masks.emptyMask & bit) != BigInt.zero &&
          placement[i] != NonogramLineSolver.empty) {
        return false;
      }
    }
    return true;
  }
}

class NonogramLineSummary {
  const NonogramLineSummary({
    required this.placements,
    required this.intersection,
    required this.contradiction,
  });

  final List<List<int>> placements;
  final List<int?> intersection;
  final bool contradiction;

  int get domainSize => placements.length;
}

class _LineKey {
  _LineKey(this.length, List<int> clues)
    : clues = List<int>.unmodifiable(clues),
      _hash = Object.hashAll(<Object>[length, ...clues]);

  final int length;
  final List<int> clues;
  final int _hash;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! _LineKey ||
        other.length != length ||
        other.clues.length != clues.length) {
      return false;
    }
    for (int i = 0; i < clues.length; i++) {
      if (other.clues[i] != clues[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => _hash;
}

class _LineSummaryKey {
  const _LineSummaryKey(this.lineKey, this.filledMask, this.emptyMask);

  final _LineKey lineKey;
  final BigInt filledMask;
  final BigInt emptyMask;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _LineSummaryKey &&
            other.lineKey == lineKey &&
            other.filledMask == filledMask &&
            other.emptyMask == emptyMask;
  }

  @override
  int get hashCode => Object.hash(lineKey, filledMask, emptyMask);
}

class _KnownMasks {
  const _KnownMasks({required this.filledMask, required this.emptyMask});

  factory _KnownMasks.fromLine(List<int?> current) {
    BigInt filledMask = BigInt.zero;
    BigInt emptyMask = BigInt.zero;
    for (int i = 0; i < current.length; i++) {
      final int? value = current[i];
      if (value == null) {
        continue;
      }
      final BigInt bit = BigInt.one << i;
      if (value == NonogramLineSolver.filled) {
        filledMask |= bit;
      } else if (value == NonogramLineSolver.empty) {
        emptyMask |= bit;
      }
    }
    return _KnownMasks(filledMask: filledMask, emptyMask: emptyMask);
  }

  final BigInt filledMask;
  final BigInt emptyMask;
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
