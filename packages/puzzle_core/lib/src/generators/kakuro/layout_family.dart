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
    required this.supportedSizes,
    required this.supportedDifficulties,
    this.basePattern,
    this.proceduralBuilder,
    required this.mutationOptions,
  }) : assert(basePattern != null || proceduralBuilder != null);

  final String id;
  final Set<int> supportedSizes;
  final Set<String> supportedDifficulties;
  final List<String>? basePattern;
  final KakuroLayoutFamilyBuilder? proceduralBuilder;
  final KakuroLayoutMutationOptions mutationOptions;

  bool supports({
    required int width,
    required int height,
    required String difficulty,
  }) {
    return width == height &&
        supportedSizes.contains(width) &&
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
    id: 'medium-balanced',
    supportedSizes: <int>{9},
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
    id: 'hard-crossing-heavy',
    supportedSizes: <int>{9},
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
    id: 'expert-long-run-controlled',
    supportedSizes: <int>{9},
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
    id: 'easy-9x9-calibration',
    supportedSizes: <int>{9},
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
  if (attemptIndex % 5 == 4) {
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
  if (width != 9 || height != 9) {
    return false;
  }
  return difficulty == 'medium' ||
      difficulty == 'hard' ||
      difficulty == 'expert';
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
      layoutFamilyId: 'medium-balanced',
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
      layoutFamilyId: 'hard-crossing-heavy',
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
      layoutFamilyId: 'expert-long-run-controlled',
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
      layoutFamilyId: 'easy-9x9-calibration',
    ).layout,
  );

  return _gridToRows(grid);
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
