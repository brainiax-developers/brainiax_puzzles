part of puzzle_core_kakuro_generator;

typedef KakuroLayoutFamilyBuilder =
    List<String> Function({
      required SeededRng rng,
      required int width,
      required int height,
      required String difficulty,
    });

class KakuroLayoutMutationOptions {
  const KakuroLayoutMutationOptions({
    required this.minSymmetricToggles,
    required this.maxSymmetricToggles,
    required this.maxMutationAttempts,
    required this.minInteriorBlockCount,
    required this.maxInteriorBlockCount,
  });

  final int minSymmetricToggles;
  final int maxSymmetricToggles;
  final int maxMutationAttempts;
  final int minInteriorBlockCount;
  final int maxInteriorBlockCount;
}

class KakuroLayoutFamily {
  const KakuroLayoutFamily({
    required this.id,
    required this.supportedSizeIds,
    required this.supportedDifficulties,
    this.basePattern,
    this.proceduralBuilder,
    required this.mutationOptions,
  }) : assert(basePattern != null || proceduralBuilder != null);

  final String id;
  final Set<String> supportedSizeIds;
  final Set<String> supportedDifficulties;
  final List<String>? basePattern;
  final KakuroLayoutFamilyBuilder? proceduralBuilder;
  final KakuroLayoutMutationOptions mutationOptions;

  bool supports({
    required int width,
    required int height,
    required String difficulty,
  }) {
    return supportedSizeIds.contains('${width}x$height') &&
        supportedDifficulties.contains(difficulty);
  }

  List<String> buildBaseRows({
    required SeededRng rng,
    required int width,
    required int height,
    required String difficulty,
  }) {
    if (basePattern != null) {
      return List<String>.from(basePattern!);
    }
    return proceduralBuilder!(
      rng: rng,
      width: width,
      height: height,
      difficulty: difficulty,
    );
  }
}

const List<KakuroLayoutFamily> _kakuroLayoutFamilies = <KakuroLayoutFamily>[
  KakuroLayoutFamily(
    id: 'medium_balanced_v1',
    supportedSizeIds: <String>{'9x9'},
    supportedDifficulties: <String>{'medium', 'hard'},
    proceduralBuilder: _buildMediumBalancedBaseRows,
    mutationOptions: KakuroLayoutMutationOptions(
      minSymmetricToggles: 0,
      maxSymmetricToggles: 0,
      maxMutationAttempts: 20,
      minInteriorBlockCount: 8,
      maxInteriorBlockCount: 30,
    ),
  ),
  KakuroLayoutFamily(
    id: 'hard_crossing_heavy_v1',
    supportedSizeIds: <String>{'9x9'},
    supportedDifficulties: <String>{'hard', 'expert'},
    proceduralBuilder: _buildHardCrossingHeavyBaseRows,
    mutationOptions: KakuroLayoutMutationOptions(
      minSymmetricToggles: 0,
      maxSymmetricToggles: 0,
      maxMutationAttempts: 24,
      minInteriorBlockCount: 8,
      maxInteriorBlockCount: 30,
    ),
  ),
  KakuroLayoutFamily(
    id: 'expert_long_run_controlled_v1',
    supportedSizeIds: <String>{'9x9'},
    supportedDifficulties: <String>{'expert', 'hard'},
    proceduralBuilder: _buildExpertLongRunControlledBaseRows,
    mutationOptions: KakuroLayoutMutationOptions(
      minSymmetricToggles: 0,
      maxSymmetricToggles: 0,
      maxMutationAttempts: 24,
      minInteriorBlockCount: 8,
      maxInteriorBlockCount: 30,
    ),
  ),
  KakuroLayoutFamily(
    id: 'easy_9x9_calibration_v1',
    supportedSizeIds: <String>{'9x9'},
    supportedDifficulties: <String>{'easy'},
    proceduralBuilder: _buildEasyCalibrationBaseRows,
    mutationOptions: KakuroLayoutMutationOptions(
      minSymmetricToggles: 0,
      maxSymmetricToggles: 0,
      maxMutationAttempts: 16,
      minInteriorBlockCount: 8,
      maxInteriorBlockCount: 30,
    ),
  ),
  KakuroLayoutFamily(
    id: 'portrait_7x9_easy_v1',
    supportedSizeIds: <String>{'7x9'},
    supportedDifficulties: <String>{'easy'},
    proceduralBuilder: _buildPortraitProfileBaseRows,
    mutationOptions: KakuroLayoutMutationOptions(
      minSymmetricToggles: 0,
      maxSymmetricToggles: 0,
      maxMutationAttempts: 0,
      minInteriorBlockCount: 6,
      maxInteriorBlockCount: 18,
    ),
  ),
  KakuroLayoutFamily(
    id: 'portrait_7x10_medium_v1',
    supportedSizeIds: <String>{'7x10'},
    supportedDifficulties: <String>{'medium'},
    proceduralBuilder: _buildPortraitProfileBaseRows,
    mutationOptions: KakuroLayoutMutationOptions(
      minSymmetricToggles: 0,
      maxSymmetricToggles: 0,
      maxMutationAttempts: 0,
      minInteriorBlockCount: 8,
      maxInteriorBlockCount: 22,
    ),
  ),
  KakuroLayoutFamily(
    id: 'portrait_8x11_hard_v1',
    supportedSizeIds: <String>{'8x11'},
    supportedDifficulties: <String>{'hard'},
    proceduralBuilder: _buildPortraitProfileBaseRows,
    mutationOptions: KakuroLayoutMutationOptions(
      minSymmetricToggles: 0,
      maxSymmetricToggles: 0,
      maxMutationAttempts: 0,
      minInteriorBlockCount: 12,
      maxInteriorBlockCount: 28,
    ),
  ),
  KakuroLayoutFamily(
    id: 'portrait_9x12_expert_v1',
    supportedSizeIds: <String>{'9x12'},
    supportedDifficulties: <String>{'expert'},
    proceduralBuilder: _buildPortraitProfileBaseRows,
    mutationOptions: KakuroLayoutMutationOptions(
      minSymmetricToggles: 0,
      maxSymmetricToggles: 0,
      maxMutationAttempts: 0,
      minInteriorBlockCount: 16,
      maxInteriorBlockCount: 36,
    ),
  ),
];

KakuroLayout _buildLayoutCandidateForAttempt({
  required int seed64,
  required int width,
  required int height,
  required String difficulty,
  required int attemptIndex,
  SeededRng? newspaperRng,
}) {
  if (!_shouldUseLayoutFamilies(
    width: width,
    height: height,
    difficulty: difficulty,
  )) {
    return KakuroLayout.buildNewspaper(
      rng:
          newspaperRng ??
          SeededRng(
            _deriveLayoutFamilySeed(
              seed64,
              width,
              height,
              difficulty,
              attemptIndex,
              0x44f3,
            ),
          ),
      width: width,
      height: height,
      difficulty: difficulty,
      layoutFamilyId: _defaultKakuroLayoutFamilyId,
    );
  }

  // Keep deterministic access to baseline newspaper topology while still
  // exploring family variants for the same 9x9 request.
  if (width == 9 && height == 9 && attemptIndex % 5 == 4) {
    return KakuroLayout.buildNewspaper(
      rng:
          newspaperRng ??
          SeededRng(
            _deriveLayoutFamilySeed(
              seed64,
              width,
              height,
              difficulty,
              attemptIndex,
              0x4f41,
            ),
          ),
      width: width,
      height: height,
      difficulty: difficulty,
      layoutFamilyId: _defaultKakuroLayoutFamilyId,
    );
  }

  final List<KakuroLayoutFamily> eligible = _kakuroLayoutFamilies
      .where(
        (KakuroLayoutFamily family) => family.supports(
          width: width,
          height: height,
          difficulty: difficulty,
        ),
      )
      .toList();

  if (eligible.isEmpty) {
    return KakuroLayout.buildNewspaper(
      rng: SeededRng(
        _deriveLayoutFamilySeed(
          seed64,
          width,
          height,
          difficulty,
          attemptIndex,
          0x44f4,
        ),
      ),
      width: width,
      height: height,
      difficulty: difficulty,
      layoutFamilyId: _defaultKakuroLayoutFamilyId,
    );
  }

  final SeededRng selectorRng = SeededRng(
    _deriveLayoutFamilySeed(
      seed64,
      width,
      height,
      difficulty,
      attemptIndex,
      0x51a1,
    ),
  );
  final int familyOffset = selectorRng.nextIntInRange(eligible.length);
  final KakuroLayoutFamily family =
      eligible[(attemptIndex + familyOffset) % eligible.length];

  final SeededRng baseRng =
      newspaperRng ??
      SeededRng(
        _deriveLayoutFamilySeed(
          seed64,
          width,
          height,
          family.id,
          attemptIndex,
          0x61b2,
        ),
      );
  List<List<int>> grid = _rowsToGrid(
    family.buildBaseRows(
      rng: baseRng,
      width: width,
      height: height,
      difficulty: difficulty,
    ),
  );

  _ensureBoundaryBlocks(grid);
  _applyFamilyMutations(
    grid: grid,
    rng: SeededRng(
      _deriveLayoutFamilySeed(
        seed64,
        width,
        height,
        family.id,
        attemptIndex,
        0x84d4,
      ),
    ),
    options: family.mutationOptions,
  );

  if (!_isStructurallyValidGrid(grid)) {
    grid = _rowsToGrid(
      KakuroLayout.buildNewspaper(
        rng: SeededRng(
          _deriveLayoutFamilySeed(
            seed64,
            width,
            height,
            family.id,
            attemptIndex,
            0x95e5,
          ),
        ),
        width: width,
        height: height,
        difficulty: difficulty,
        layoutFamilyId: family.id,
      ).layout,
    );
  }

  final KakuroLayout layout = KakuroLayout.fromRows(
    _gridToRows(grid),
    layoutFamilyId: family.id,
  );
  if (_isStructurallyValidLayout(layout)) {
    return layout;
  }

  return KakuroLayout.buildNewspaper(
    rng: SeededRng(
      _deriveLayoutFamilySeed(
        seed64,
        width,
        height,
        family.id,
        attemptIndex,
        0x98f8,
      ),
    ),
    width: width,
    height: height,
    difficulty: difficulty,
    layoutFamilyId: family.id,
  );
}

bool _shouldUseLayoutFamilies({
  required int width,
  required int height,
  required String difficulty,
}) {
  final String sizeId = '${width}x$height';
  if (sizeId == '7x9') {
    return difficulty == 'easy';
  }
  if (sizeId == '7x10') {
    return difficulty == 'medium';
  }
  if (sizeId == '8x11') {
    return difficulty == 'hard';
  }
  if (sizeId == '9x12') {
    return difficulty == 'expert';
  }
  if (width == 9 && height == 9) {
    return difficulty == 'medium' ||
        difficulty == 'hard' ||
        difficulty == 'expert';
  }
  return false;
}

int _deriveLayoutFamilySeed(
  int seed64,
  int width,
  int height,
  String key,
  int attemptIndex,
  int stage,
) {
  final int keyHash = Seed.fromString(
    'kakuro_layout_family:$key:$width:$height',
  );
  final int attemptSalt = ((attemptIndex + 1) * _mixMultiplier) & _mask64;
  final int combined = seed64 ^ keyHash ^ attemptSalt ^ stage;
  return combined & _mask64;
}

List<String> _buildMediumBalancedBaseRows({
  required SeededRng rng,
  required int width,
  required int height,
  required String difficulty,
}) {
  final List<List<int>> grid = _rowsToGrid(
    KakuroLayout.buildNewspaper(
      rng: rng,
      width: width,
      height: height,
      difficulty: 'medium',
      layoutFamilyId: 'medium_balanced_v1',
    ).layout,
  );

  return _gridToRows(grid);
}

List<String> _buildHardCrossingHeavyBaseRows({
  required SeededRng rng,
  required int width,
  required int height,
  required String difficulty,
}) {
  final List<List<int>> grid = _rowsToGrid(
    KakuroLayout.buildNewspaper(
      rng: rng,
      width: width,
      height: height,
      difficulty: 'hard',
      layoutFamilyId: 'hard_crossing_heavy_v1',
    ).layout,
  );

  return _gridToRows(grid);
}

List<String> _buildExpertLongRunControlledBaseRows({
  required SeededRng rng,
  required int width,
  required int height,
  required String difficulty,
}) {
  final List<List<int>> grid = _rowsToGrid(
    KakuroLayout.buildNewspaper(
      rng: rng,
      width: width,
      height: height,
      difficulty: 'medium',
      layoutFamilyId: 'expert_long_run_controlled_v1',
    ).layout,
  );

  return _gridToRows(grid);
}

List<String> _buildEasyCalibrationBaseRows({
  required SeededRng rng,
  required int width,
  required int height,
  required String difficulty,
}) {
  final List<List<int>> grid = _rowsToGrid(
    KakuroLayout.buildNewspaper(
      rng: rng,
      width: width,
      height: height,
      difficulty: 'easy',
      layoutFamilyId: 'easy_9x9_calibration_v1',
    ).layout,
  );

  return _gridToRows(grid);
}

List<String> _buildPortraitProfileBaseRows({
  required SeededRng rng,
  required int width,
  required int height,
  required String difficulty,
}) {
  final _KakuroLayoutThresholdProfile? profile = _thresholdProfileFor(
    width: width,
    height: height,
    difficulty: difficulty,
  );
  final int totalCells = width * height;
  final int minWhiteCells = profile == null
      ? _ceilDiv(totalCells * 300, 1000)
      : _ceilDiv(totalCells * profile.minWhiteDensityMilli, 1000);
  final int maxWhiteCells = profile == null
      ? (totalCells * 560) ~/ 1000
      : (totalCells * profile.maxWhiteDensityMilli) ~/ 1000;
  final int densityDivisor = difficulty == 'easy' ? 5 : 3;
  final int targetWhiteCells = profile == null
      ? (totalCells * 420) ~/ 1000
      : minWhiteCells + ((maxWhiteCells - minWhiteCells) ~/ densityDivisor);

  KakuroLayout? bestLayout;
  KakuroLayoutPreScoreResult? bestScore;
  for (int variant = 0; variant < 32; variant++) {
    final SeededRng variantRng = SeededRng(
      rng.nextInt64() ^
          Seed.fromString(
            'kakuro_portrait_layout:$width:$height:$difficulty:$variant',
          ),
    );
    final List<int>? rowMasks = _buildPortraitMaskSequence(
      rng: variantRng,
      interiorWidth: width - 2,
      interiorHeight: height - 2,
      minWhiteCells: minWhiteCells,
      maxWhiteCells: maxWhiteCells,
      targetWhiteCells: targetWhiteCells,
    );
    if (rowMasks == null) {
      continue;
    }

    final List<List<int>> grid = _portraitMasksToGrid(
      rowMasks: rowMasks,
      width: width,
      height: height,
    );
    if (!_isStructurallyValidGrid(grid)) {
      continue;
    }
    final KakuroLayout layout = KakuroLayout.fromRows(_gridToRows(grid));
    final KakuroLayoutPreScoreResult score = const KakuroLayoutPreScorer()
        .score(layout: layout, difficulty: difficulty);
    if (_isBetterPortraitPreScore(score, bestScore)) {
      bestLayout = layout;
      bestScore = score;
    }
  }

  if (bestLayout != null) {
    return bestLayout.layout;
  }

  final List<List<int>> fallback = _buildPortraitScaffoldGrid(width, height);
  return _gridToRows(fallback);
}

bool _isBetterPortraitPreScore(
  KakuroLayoutPreScoreResult candidate,
  KakuroLayoutPreScoreResult? incumbent,
) {
  if (incumbent == null) {
    return true;
  }
  if (candidate.accepted != incumbent.accepted) {
    return candidate.accepted;
  }
  if (candidate.scoreMilli != incumbent.scoreMilli) {
    return candidate.scoreMilli > incumbent.scoreMilli;
  }
  if (candidate.metrics.unpairedValueCellCount !=
      incumbent.metrics.unpairedValueCellCount) {
    return candidate.metrics.unpairedValueCellCount <
        incumbent.metrics.unpairedValueCellCount;
  }
  return candidate.metrics.totalRunCount > incumbent.metrics.totalRunCount;
}

List<int>? _buildPortraitMaskSequence({
  required SeededRng rng,
  required int interiorWidth,
  required int interiorHeight,
  required int minWhiteCells,
  required int maxWhiteCells,
  required int targetWhiteCells,
}) {
  final List<int> masks = _validPortraitRowMasks(interiorWidth);
  if (masks.isEmpty) {
    return null;
  }
  final Map<int, int> whiteCellsByMask = <int, int>{
    for (final int mask in masks) mask: interiorWidth - _popCount(mask),
  };
  int minRowWhiteCells = interiorWidth;
  int maxRowWhiteCells = 0;
  for (final int count in whiteCellsByMask.values) {
    if (count < minRowWhiteCells) {
      minRowWhiteCells = count;
    }
    if (count > maxRowWhiteCells) {
      maxRowWhiteCells = count;
    }
  }

  final List<int> selected = List<int>.filled(interiorHeight, 0);
  final List<int> verticalRuns = List<int>.filled(interiorWidth, 0);
  int nodeBudget = 1600;

  bool search(int row, int whiteCellsSoFar, List<int> currentRuns) {
    nodeBudget--;
    if (nodeBudget < 0) {
      return false;
    }
    if (row == interiorHeight) {
      if (whiteCellsSoFar < minWhiteCells || whiteCellsSoFar > maxWhiteCells) {
        return false;
      }
      for (final int run in currentRuns) {
        if (run == 1 || run > 9) {
          return false;
        }
      }
      return true;
    }

    final List<int> ordered = _orderedPortraitMasks(
      rng: rng,
      masks: masks,
      interiorWidth: interiorWidth,
      whiteCellsByMask: whiteCellsByMask,
      targetWhiteCells: targetWhiteCells,
      whiteCellsSoFar: whiteCellsSoFar,
      remainingRowsIncludingCurrent: interiorHeight - row,
    );
    final int remainingRows = interiorHeight - row - 1;
    final bool isLastRow = row == interiorHeight - 1;
    for (final int mask in ordered) {
      final int rowWhiteCells = whiteCellsByMask[mask]!;
      final int nextWhiteCells = whiteCellsSoFar + rowWhiteCells;
      if (nextWhiteCells > maxWhiteCells) {
        continue;
      }
      if (nextWhiteCells + remainingRows * maxRowWhiteCells < minWhiteCells) {
        continue;
      }
      if (nextWhiteCells + remainingRows * minRowWhiteCells > maxWhiteCells) {
        continue;
      }
      final List<int>? nextRuns = _appendPortraitMask(
        mask: mask,
        currentRuns: currentRuns,
        isLastRow: isLastRow,
      );
      if (nextRuns == null) {
        continue;
      }
      selected[row] = mask;
      if (search(row + 1, nextWhiteCells, nextRuns)) {
        return true;
      }
    }
    return false;
  }

  if (search(0, 0, verticalRuns)) {
    return selected;
  }
  return null;
}

List<int> _orderedPortraitMasks({
  required SeededRng rng,
  required List<int> masks,
  required int interiorWidth,
  required Map<int, int> whiteCellsByMask,
  required int targetWhiteCells,
  required int whiteCellsSoFar,
  required int remainingRowsIncludingCurrent,
}) {
  final int targetPerRowMilli =
      ((targetWhiteCells - whiteCellsSoFar) * 1000) ~/
      remainingRowsIncludingCurrent;
  final List<_KakuroPortraitMaskChoice> choices = <_KakuroPortraitMaskChoice>[];
  for (final int mask in masks) {
    final int whiteCells = whiteCellsByMask[mask]!;
    final int shapePenalty = _portraitMaskShapePenalty(
      mask,
      whiteCells,
      interiorWidth: interiorWidth,
    );
    choices.add(
      _KakuroPortraitMaskChoice(
        mask: mask,
        score:
            ((whiteCells * 1000 - targetPerRowMilli).abs() * 4) +
            shapePenalty +
            rng.nextIntInRange(250),
      ),
    );
  }
  choices.sort(
    (_KakuroPortraitMaskChoice a, _KakuroPortraitMaskChoice b) =>
        a.score.compareTo(b.score),
  );
  return choices
      .map((_KakuroPortraitMaskChoice choice) => choice.mask)
      .toList(growable: false);
}

int _portraitMaskShapePenalty(
  int mask,
  int whiteCells, {
  required int interiorWidth,
}) {
  final int blockCount = _popCount(mask);
  int transitions = 0;
  bool? previousValue;
  for (int col = 0; col < interiorWidth; col++) {
    final bool isValue = (mask & (1 << col)) == 0;
    if (previousValue != null && previousValue != isValue) {
      transitions++;
    }
    previousValue = isValue;
  }
  return (blockCount - 2).abs() * 180 +
      (whiteCells < 2 ? 800 : 0) +
      transitions * 20;
}

class _KakuroPortraitMaskChoice {
  const _KakuroPortraitMaskChoice({required this.mask, required this.score});

  final int mask;
  final int score;
}

List<int>? _appendPortraitMask({
  required int mask,
  required List<int> currentRuns,
  required bool isLastRow,
}) {
  final List<int> nextRuns = List<int>.filled(currentRuns.length, 0);
  for (int col = 0; col < currentRuns.length; col++) {
    final bool isBlock = (mask & (1 << col)) != 0;
    if (isBlock) {
      if (currentRuns[col] == 1) {
        return null;
      }
      nextRuns[col] = 0;
      continue;
    }
    final int nextRun = currentRuns[col] + 1;
    if (nextRun > 9 || (isLastRow && nextRun == 1)) {
      return null;
    }
    nextRuns[col] = nextRun;
  }
  return nextRuns;
}

List<int> _validPortraitRowMasks(int interiorWidth) {
  final List<int> masks = <int>[];
  final int limit = 1 << interiorWidth;
  for (int mask = 0; mask < limit; mask++) {
    final int whiteCells = interiorWidth - _popCount(mask);
    if (whiteCells < 2) {
      continue;
    }
    if (_rowMaskHasValidRuns(mask, interiorWidth)) {
      masks.add(mask);
    }
  }
  return masks;
}

bool _rowMaskHasValidRuns(int mask, int interiorWidth) {
  int run = 0;
  for (int col = 0; col < interiorWidth; col++) {
    final bool isValue = (mask & (1 << col)) == 0;
    if (isValue) {
      run++;
      continue;
    }
    if (run == 1 || run > 9) {
      return false;
    }
    run = 0;
  }
  return run != 1 && run <= 9;
}

List<List<int>> _portraitMasksToGrid({
  required List<int> rowMasks,
  required int width,
  required int height,
}) {
  final List<List<int>> grid = List<List<int>>.generate(
    height,
    (_) => List<int>.filled(width, 1),
  );
  for (int row = 1; row < height - 1; row++) {
    final int mask = rowMasks[row - 1];
    for (int col = 1; col < width - 1; col++) {
      grid[row][col] = (mask & (1 << (col - 1))) == 0 ? 0 : 1;
    }
  }
  return grid;
}

List<List<int>> _buildPortraitScaffoldGrid(int width, int height) {
  final List<List<int>> grid = List<List<int>>.generate(
    height,
    (_) => List<int>.filled(width, 0),
  );
  _ensureBoundaryBlocks(grid);
  for (int row = 2; row < height - 2; row += 3) {
    for (int col = 2; col < width - 2; col += 4) {
      grid[row][col] = 1;
    }
  }
  _repairRuns(
    SeededRng(Seed.fromString('kakuro_portrait_scaffold')),
    grid,
    2,
    9,
  );
  return grid;
}

int _ceilDiv(int numerator, int denominator) {
  return (numerator + denominator - 1) ~/ denominator;
}

int _popCount(int value) {
  int count = 0;
  int bits = value;
  while (bits != 0) {
    bits &= bits - 1;
    count++;
  }
  return count;
}

void _applyFamilyMutations({
  required List<List<int>> grid,
  required SeededRng rng,
  required KakuroLayoutMutationOptions options,
}) {
  final int h = grid.length;
  final int w = grid.first.length;
  final List<List<int>> pairs = _symmetryPairs(h, w);
  if (pairs.isEmpty) {
    return;
  }

  final int range =
      options.maxSymmetricToggles - options.minSymmetricToggles + 1;
  final int target = options.minSymmetricToggles + rng.nextIntInRange(range);
  final List<List<int>> order = rng.permute(pairs);

  int applied = 0;
  int attempts = 0;
  for (final List<int> pair in order) {
    if (applied >= target || attempts >= options.maxMutationAttempts) {
      break;
    }
    attempts++;
    final int r = pair[0];
    final int c = pair[1];
    final int nextValue = grid[r][c] == 1 ? 0 : 1;
    if (!_trySetSymmetricValue(grid, r, c, nextValue)) {
      continue;
    }
    if (!_isWithinInteriorBlockBounds(grid, options)) {
      _trySetSymmetricValue(grid, r, c, nextValue == 1 ? 0 : 1, force: true);
      continue;
    }
    if (!_isStructurallyValidGrid(grid)) {
      _trySetSymmetricValue(grid, r, c, nextValue == 1 ? 0 : 1, force: true);
      continue;
    }
    applied++;
  }
}

bool _trySetSymmetricValue(
  List<List<int>> grid,
  int r,
  int c,
  int value, {
  bool force = false,
}) {
  final int h = grid.length;
  final int w = grid.first.length;
  final int r2 = h - 1 - r;
  final int c2 = w - 1 - c;
  if (r <= 0 || c <= 0 || r >= h - 1 || c >= w - 1) {
    return false;
  }
  if (r2 <= 0 || c2 <= 0 || r2 >= h - 1 || c2 >= w - 1) {
    return false;
  }

  final int prevA = grid[r][c];
  final int prevB = grid[r2][c2];
  grid[r][c] = value;
  grid[r2][c2] = value;

  if (force) {
    return true;
  }

  if (!_isStructurallyValidGrid(grid)) {
    grid[r][c] = prevA;
    grid[r2][c2] = prevB;
    return false;
  }
  return true;
}

List<List<int>> _symmetryPairs(int height, int width) {
  final List<List<int>> pairs = <List<int>>[];
  for (int r = 1; r < height - 1; r++) {
    for (int c = 1; c < width - 1; c++) {
      final int r2 = height - 1 - r;
      final int c2 = width - 1 - c;
      if (r > r2 || (r == r2 && c > c2)) {
        continue;
      }
      pairs.add(<int>[r, c]);
    }
  }
  return pairs;
}

int _countInteriorBlocks(List<List<int>> grid) {
  int blocks = 0;
  for (int r = 1; r < grid.length - 1; r++) {
    for (int c = 1; c < grid.first.length - 1; c++) {
      if (grid[r][c] == 1) {
        blocks++;
      }
    }
  }
  return blocks;
}

bool _isWithinInteriorBlockBounds(
  List<List<int>> grid,
  KakuroLayoutMutationOptions options,
) {
  final int blocks = _countInteriorBlocks(grid);
  return blocks >= options.minInteriorBlockCount &&
      blocks <= options.maxInteriorBlockCount;
}

void _ensureBoundaryBlocks(List<List<int>> grid) {
  final int h = grid.length;
  final int w = grid.first.length;
  for (int r = 0; r < h; r++) {
    grid[r][0] = 1;
    grid[r][w - 1] = 1;
  }
  for (int c = 0; c < w; c++) {
    grid[0][c] = 1;
    grid[h - 1][c] = 1;
  }
}

bool _isStructurallyValidGrid(List<List<int>> grid) {
  if (!_runsValid(grid, 2, 9)) {
    return false;
  }

  final int h = grid.length;
  final int w = grid.first.length;
  int whiteCount = 0;
  for (int r = 0; r < h; r++) {
    for (int c = 0; c < w; c++) {
      if (grid[r][c] != 0) {
        continue;
      }
      whiteCount++;
      final bool hasAcross =
          (c > 0 && grid[r][c - 1] == 0) || (c + 1 < w && grid[r][c + 1] == 0);
      final bool hasDown =
          (r > 0 && grid[r - 1][c] == 0) || (r + 1 < h && grid[r + 1][c] == 0);
      if (!hasAcross || !hasDown) {
        return false;
      }
    }
  }
  return whiteCount > 0;
}

bool _isStructurallyValidLayout(KakuroLayout layout) {
  if (layout.valueCells.isEmpty || layout.entries.isEmpty) {
    return false;
  }
  for (final int cell in layout.valueCells) {
    if (layout.acrossEntryForCell[cell] < 0 ||
        layout.downEntryForCell[cell] < 0) {
      return false;
    }
  }
  for (final KakuroLayoutEntry entry in layout.entries) {
    if (entry.length < 2 || entry.length > 9) {
      return false;
    }
  }
  return true;
}

List<List<int>> _rowsToGrid(List<String> rows) {
  return rows
      .map(
        (String row) => row
            .split('')
            .map((String ch) => ch == '#' ? 1 : 0)
            .toList(growable: false),
      )
      .toList(growable: false);
}

List<String> _gridToRows(List<List<int>> grid) {
  final List<String> rows = <String>[];
  for (final List<int> row in grid) {
    final StringBuffer buffer = StringBuffer();
    for (final int cell in row) {
      buffer.write(cell == 1 ? '#' : '.');
    }
    rows.add(buffer.toString());
  }
  return rows;
}
