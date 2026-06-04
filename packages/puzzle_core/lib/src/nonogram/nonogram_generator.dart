import '../generators/generator.dart';
import '../solver/solver.dart';
import '../util/nonogram.dart';
import '../util/seeded_rng.dart';
import 'nonogram_board.dart';
import 'nonogram_solver.dart';

class NonogramGenerator extends PuzzleGenerator<NonogramBoard> {
  const NonogramGenerator({
    this.maxUniquenessAttempts = 64,
    this.logicSolver = const NonogramSolver(),
  });

  final int maxUniquenessAttempts;
  final NonogramSolver logicSolver;

  @override
  PuzzleGenerationResult<NonogramBoard> generate(GeneratorContext context) {
    final int width = context.size.width;
    final int height = context.size.height;
    if (!_supportedSize(width, height)) {
      throw ArgumentError('Unsupported nonogram size: ${width}x$height');
    }

    final _BitmapProfile profile = _BitmapProfile.forLevel(
      context.difficulty.level,
    );
    _CandidateReport lastReport = _CandidateReport.empty(profile);

    for (int attempt = 1; attempt <= maxUniquenessAttempts; attempt++) {
      List<int> solution = _deriveBitmapForDifficulty(
        context.rng,
        width,
        height,
        profile,
        attempt,
      );
      if (!_hasAnyFilled(solution)) {
        solution = _structuredFallbackBitmap(width, height, profile);
      }

      final _BitmapMetrics metrics = _bitmapMetrics(solution, width, height);
      final String? rejectionReason = _quickReject(metrics, profile);
      if (rejectionReason != null) {
        lastReport = _CandidateReport(
          profile: profile,
          metrics: metrics,
          attempts: attempt,
          rejectionReason: rejectionReason,
        );
        continue;
      }

      final PuzzleGenerationResult<NonogramBoard>? attemptResult =
          _attemptSolution(
            solution,
            width,
            height,
            context,
            attempt: attempt,
            profile: profile,
            metrics: metrics,
          );
      if (attemptResult != null) {
        return attemptResult;
      }
      lastReport = _CandidateReport(
        profile: profile,
        metrics: metrics,
        attempts: attempt,
        rejectionReason: 'not_unique',
      );
    }

    throw StateError(
      'Unable to generate unique nonogram for seed ${context.seedStr}: '
      '${lastReport.rejectionReason}',
    );
  }

  List<int> _deriveBitmapForDifficulty(
    SeededRng rng,
    int width,
    int height,
    _BitmapProfile profile,
    int attempt,
  ) {
    final List<int> bitmap = List<int>.filled(
      width * height,
      NonogramLineSolver.empty,
    );

    _applyCoarseScaffold(rng, bitmap, width, height, profile);

    final int family = (rng.nextIntInRange(3) + attempt) % 3;
    switch (family) {
      case 0:
        _applyRegionFamily(rng, bitmap, width, height, profile);
        break;
      case 1:
        _applyMotifFamily(rng, bitmap, width, height, profile);
        break;
      default:
        _applyIconFamily(rng, bitmap, width, height, profile);
        break;
    }

    _targetDensity(rng, bitmap, width, height, profile);
    _targetFragmentation(rng, bitmap, width, height, profile);
    _cleanupSingletonsAndPinholes(rng, bitmap, width, height, profile);
    _targetDensity(rng, bitmap, width, height, profile);
    _cleanupSingletonsAndPinholes(rng, bitmap, width, height, profile);

    return bitmap;
  }

  void _applyCoarseScaffold(
    SeededRng rng,
    List<int> bitmap,
    int width,
    int height,
    _BitmapProfile profile,
  ) {
    final int cellSize = width <= 10 ? 2 : 3;
    final int coarseWidth = (width + cellSize - 1) ~/ cellSize;
    final int coarseHeight = (height + cellSize - 1) ~/ cellSize;
    final List<bool> coarse = List<bool>.filled(
      coarseWidth * coarseHeight,
      false,
    );
    final int walks = profile.scaffoldWalks;

    for (int walk = 0; walk < walks; walk++) {
      int cx = rng.nextIntInRange(coarseWidth);
      int cy = rng.nextIntInRange(coarseHeight);
      final int steps =
          profile.scaffoldMinSteps +
          rng.nextIntInRange(
            profile.scaffoldMaxSteps - profile.scaffoldMinSteps + 1,
          );
      for (int step = 0; step < steps; step++) {
        coarse[cy * coarseWidth + cx] = true;
        final int direction = rng.nextIntInRange(4);
        if (direction == 0 && cx > 0) {
          cx--;
        } else if (direction == 1 && cx + 1 < coarseWidth) {
          cx++;
        } else if (direction == 2 && cy > 0) {
          cy--;
        } else if (direction == 3 && cy + 1 < coarseHeight) {
          cy++;
        }
      }
    }

    for (int cy = 0; cy < coarseHeight; cy++) {
      for (int cx = 0; cx < coarseWidth; cx++) {
        if (!coarse[cy * coarseWidth + cx]) {
          continue;
        }
        final int x0 = cx * cellSize;
        final int y0 = cy * cellSize;
        final int x1 = _minInt(width, x0 + cellSize);
        final int y1 = _minInt(height, y0 + cellSize);
        for (int y = y0; y < y1; y++) {
          for (int x = x0; x < x1; x++) {
            _setFilled(bitmap, width, x, y);
          }
        }
      }
    }
  }

  bool _supportedSize(int width, int height) {
    return (width == 10 && height == 10) || (width == 15 && height == 15);
  }

  void _applyRegionFamily(
    SeededRng rng,
    List<int> bitmap,
    int width,
    int height,
    _BitmapProfile profile,
  ) {
    final int regions =
        profile.regionCount + rng.nextIntInRange(profile.regionVariance + 1);
    for (int i = 0; i < regions; i++) {
      final int cx = rng.nextIntInRange(width);
      final int cy = rng.nextIntInRange(height);
      final int rx =
          profile.minRegionRadius +
          rng.nextIntInRange(
            profile.maxRegionRadius - profile.minRegionRadius + 1,
          );
      final int ry =
          profile.minRegionRadius +
          rng.nextIntInRange(
            profile.maxRegionRadius - profile.minRegionRadius + 1,
          );
      for (
        int y = _maxInt(0, cy - ry);
        y <= _minInt(height - 1, cy + ry);
        y++
      ) {
        for (
          int x = _maxInt(0, cx - rx);
          x <= _minInt(width - 1, cx + rx);
          x++
        ) {
          final int dx = (x - cx).abs();
          final int dy = (y - cy).abs();
          if (dx * ry + dy * rx <= rx * ry + _maxInt(rx, ry)) {
            _setFilled(bitmap, width, x, y);
          }
        }
      }
    }

    final int notches = profile.cutCount;
    for (int i = 0; i < notches; i++) {
      final int x0 = rng.nextIntInRange(width);
      final int y0 = rng.nextIntInRange(height);
      final int length = 2 + rng.nextIntInRange(width <= 10 ? 3 : 5);
      final bool horizontal = rng.nextBool();
      for (int offset = 0; offset < length; offset++) {
        final int x = horizontal ? x0 + offset : x0;
        final int y = horizontal ? y0 : y0 + offset;
        if (_inBounds(width, height, x, y)) {
          _setEmpty(bitmap, width, x, y);
        }
      }
    }
  }

  void _applyMotifFamily(
    SeededRng rng,
    List<int> bitmap,
    int width,
    int height,
    _BitmapProfile profile,
  ) {
    final int strokes = profile.strokeCount;
    for (int i = 0; i < strokes; i++) {
      final int mode = rng.nextIntInRange(4);
      if (mode == 0) {
        final int y = rng.nextIntInRange(height);
        final int x0 = rng.nextIntInRange(width ~/ 2 + 1);
        final int x1 = x0 + 2 + rng.nextIntInRange(width - x0);
        _drawLine(
          bitmap,
          width,
          height,
          x0,
          y,
          x1,
          y,
          thickness: profile.strokeThickness,
        );
      } else if (mode == 1) {
        final int x = rng.nextIntInRange(width);
        final int y0 = rng.nextIntInRange(height ~/ 2 + 1);
        final int y1 = y0 + 2 + rng.nextIntInRange(height - y0);
        _drawLine(
          bitmap,
          width,
          height,
          x,
          y0,
          x,
          y1,
          thickness: profile.strokeThickness,
        );
      } else if (mode == 2) {
        final int left = rng.nextIntInRange(width ~/ 3 + 1);
        final int top = rng.nextIntInRange(height ~/ 3 + 1);
        final int span = 3 + rng.nextIntInRange(_minInt(width, height) - 2);
        for (int step = 0; step < span; step++) {
          final int x = left + step;
          final int y = top + (step ~/ 2);
          _paintBrush(bitmap, width, height, x, y, profile.strokeThickness);
        }
      } else {
        final int cx = width ~/ 2 + rng.randIntRange(-1, 2);
        final int cy = height ~/ 2 + rng.randIntRange(-1, 2);
        _drawLine(
          bitmap,
          width,
          height,
          cx,
          1,
          cx,
          height - 2,
          thickness: profile.strokeThickness,
        );
        _drawLine(
          bitmap,
          width,
          height,
          1,
          cy,
          width - 2,
          cy,
          thickness: profile.strokeThickness,
        );
      }
    }

    final int chips = profile.chipCount;
    for (int i = 0; i < chips; i++) {
      final int x = rng.nextIntInRange(width);
      final int y = rng.nextIntInRange(height);
      if (_filledNeighborCount(bitmap, width, height, x, y) >= 2) {
        _setEmpty(bitmap, width, x, y);
      }
    }
  }

  void _applyIconFamily(
    SeededRng rng,
    List<int> bitmap,
    int width,
    int height,
    _BitmapProfile profile,
  ) {
    final int icon = rng.nextIntInRange(4);
    if (icon == 0) {
      _drawHouseIcon(bitmap, width, height);
    } else if (icon == 1) {
      _drawKeyIcon(bitmap, width, height);
    } else if (icon == 2) {
      _drawLeafIcon(bitmap, width, height);
    } else {
      _drawBoatIcon(bitmap, width, height);
    }

    final int accents = profile.iconAccentCount;
    for (int i = 0; i < accents; i++) {
      final int x = rng.nextIntInRange(width);
      final int y = rng.nextIntInRange(height);
      if (_filledNeighborCount(bitmap, width, height, x, y) > 0) {
        _paintBrush(bitmap, width, height, x, y, 1);
      }
    }
  }

  bool _hasAnyFilled(List<int> bitmap) {
    for (final int value in bitmap) {
      if (value == NonogramLineSolver.filled) {
        return true;
      }
    }
    return false;
  }

  List<int> _structuredFallbackBitmap(
    int width,
    int height,
    _BitmapProfile profile,
  ) {
    final List<int> bitmap = List<int>.filled(
      width * height,
      NonogramLineSolver.empty,
    );
    _drawLeafIcon(bitmap, width, height);
    _drawLine(
      bitmap,
      width,
      height,
      1,
      height - 3,
      width - 2,
      height - 3,
      thickness: 1,
    );
    for (int i = 2; i < width - 2; i += 3) {
      _setEmpty(bitmap, width, i, height - 3);
    }
    final SeededRng cleanupRng = SeededRng(
      width * 31 + height * 131 + profile.targetFilledPermille,
    );
    _targetDensity(cleanupRng, bitmap, width, height, profile);
    _targetFragmentation(cleanupRng, bitmap, width, height, profile);
    _cleanupSingletonsAndPinholes(cleanupRng, bitmap, width, height, profile);
    return bitmap;
  }

  void _drawHouseIcon(List<int> bitmap, int width, int height) {
    final int left = width ~/ 4;
    final int right = width - left - 1;
    final int roofTop = height ~/ 6;
    final int roofBase = height ~/ 2;
    final int bodyTop = roofBase;
    final int bodyBottom = height - 2;
    for (int y = roofTop; y <= roofBase; y++) {
      final int spread =
          ((y - roofTop) * (right - left + 1)) ~/
          _maxInt(1, roofBase - roofTop + 1);
      final int cx = width ~/ 2;
      for (int x = cx - spread ~/ 2; x <= cx + spread ~/ 2; x++) {
        if (_inBounds(width, height, x, y)) {
          _setFilled(bitmap, width, x, y);
        }
      }
    }
    _fillRect(bitmap, width, height, left, bodyTop, right, bodyBottom);
    _fillRect(
      bitmap,
      width,
      height,
      width ~/ 2 - 1,
      bodyBottom - 2,
      width ~/ 2 + 1,
      bodyBottom,
    );
    _setEmpty(bitmap, width, width ~/ 2, bodyBottom - 1);
    if (width >= 15) {
      _fillRect(
        bitmap,
        width,
        height,
        left + 1,
        bodyTop + 2,
        left + 2,
        bodyTop + 3,
      );
      _fillRect(
        bitmap,
        width,
        height,
        right - 2,
        bodyTop + 2,
        right - 1,
        bodyTop + 3,
      );
      _setEmpty(bitmap, width, left + 1, bodyTop + 2);
      _setEmpty(bitmap, width, right - 1, bodyTop + 3);
    }
  }

  void _drawKeyIcon(List<int> bitmap, int width, int height) {
    final int cx = width ~/ 3;
    final int cy = height ~/ 2;
    final int radius = width <= 10 ? 2 : 3;
    for (int y = cy - radius; y <= cy + radius; y++) {
      for (int x = cx - radius; x <= cx + radius; x++) {
        if (!_inBounds(width, height, x, y)) {
          continue;
        }
        final int distance = (x - cx).abs() + (y - cy).abs();
        if (distance <= radius + 1) {
          _setFilled(bitmap, width, x, y);
        }
      }
    }
    _setEmpty(bitmap, width, cx, cy);
    _drawLine(
      bitmap,
      width,
      height,
      cx + radius,
      cy,
      width - 2,
      cy,
      thickness: 1,
    );
    _drawLine(
      bitmap,
      width,
      height,
      width - 4,
      cy,
      width - 4,
      cy + 2,
      thickness: 1,
    );
    _drawLine(
      bitmap,
      width,
      height,
      width - 2,
      cy,
      width - 2,
      cy + 1,
      thickness: 1,
    );
  }

  void _drawLeafIcon(List<int> bitmap, int width, int height) {
    final int x0 = width ~/ 5;
    final int y0 = height - 3;
    final int x1 = width - 3;
    final int y1 = 2;
    _drawLine(bitmap, width, height, x0, y0, x1, y1, thickness: 1);
    final int cx = width ~/ 2;
    final int cy = height ~/ 2;
    final int rx = width <= 10 ? 3 : 5;
    final int ry = height <= 10 ? 3 : 5;
    for (int y = cy - ry; y <= cy + ry; y++) {
      for (int x = cx - rx; x <= cx + rx; x++) {
        if (!_inBounds(width, height, x, y)) {
          continue;
        }
        final int dx = (x - cx).abs();
        final int dy = (y - cy).abs();
        if (dx * ry + dy * rx <= rx * ry) {
          _setFilled(bitmap, width, x, y);
        }
      }
    }
    for (int i = 1; i < _minInt(width, height) - 2; i += 3) {
      final int x = x0 + i;
      final int y = y0 - i;
      if (_inBounds(width, height, x, y)) {
        _setEmpty(bitmap, width, x, y);
      }
    }
  }

  void _drawBoatIcon(List<int> bitmap, int width, int height) {
    final int hullTop = (height * 2) ~/ 3;
    final int hullBottom = height - 2;
    for (int y = hullTop; y <= hullBottom; y++) {
      final int inset = y - hullTop;
      for (int x = 1 + inset; x < width - 1 - inset; x++) {
        _setFilled(bitmap, width, x, y);
      }
    }
    final int mastX = width ~/ 2;
    _drawLine(bitmap, width, height, mastX, 2, mastX, hullTop, thickness: 1);
    for (int y = 2; y < hullTop; y++) {
      final int span = hullTop - y;
      for (int x = mastX; x <= _minInt(width - 2, mastX + span); x++) {
        _setFilled(bitmap, width, x, y);
      }
    }
    for (int y = hullTop - 2; y < hullTop; y++) {
      _setEmpty(bitmap, width, mastX + 1, y);
    }
  }

  bool _matchesSolution(List<int?> solvedCells, List<int> solution) {
    if (solvedCells.length != solution.length) {
      return false;
    }
    for (int i = 0; i < solvedCells.length; i++) {
      if (solvedCells[i] != solution[i]) {
        return false;
      }
    }
    return true;
  }

  PuzzleGenerationResult<NonogramBoard>? _attemptSolution(
    List<int> solution,
    int width,
    int height,
    GeneratorContext context, {
    required int attempt,
    required _BitmapProfile profile,
    required _BitmapMetrics metrics,
  }) {
    final List<List<int>> rowClues = _cluesForRows(solution, width, height);
    final List<List<int>> columnClues = _cluesForColumns(
      solution,
      width,
      height,
    );
    final NonogramBoard puzzle = NonogramBoard.empty(
      width: width,
      height: height,
      rowClues: rowClues,
      columnClues: columnClues,
    );

    final SolverResult<NonogramBoard> result = logicSolver.solve(
      puzzle,
      SolverContext(
        rng: SeededRng(context.seed64 ^ 0x41b29d38b14e5c03),
        maxSolutions: 2,
      ),
    );

    if (result.isUnique && result.solutions.isNotEmpty) {
      final NonogramBoard solved = result.solutions.first;
      if (_matchesSolution(solved.cells, solution)) {
        return PuzzleGenerationResult<NonogramBoard>(
          board: puzzle,
          snapshot: GenerationSnapshot(
            telemetry: <String, Object?>{
              'attempts': attempt,
              'candidateDensity': metrics.density,
              'fragmentation': metrics.fragmentation,
              'visualScore': metrics.visualScore,
              'rejectionReason': 'accepted',
              'profile': profile.level,
              'isolatedFilledRatio': metrics.isolatedFilledRatio,
              'emptyFullLineRatio': metrics.emptyFullLineRatio,
              'largestFilledComponentRatio':
                  metrics.largestFilledComponentRatio,
              'largestSolidRectangleRatio': metrics.largestSolidRectangleRatio,
              'fillRatio': metrics.density,
              'solverTelemetry': result.telemetry,
            },
          ),
        );
      }
    }

    return null;
  }

  List<List<int>> _cluesForRows(List<int> cells, int width, int height) {
    final List<List<int>> clues = <List<int>>[];
    for (int row = 0; row < height; row++) {
      final List<int> values = <int>[];
      int run = 0;
      for (int col = 0; col < width; col++) {
        final int value = cells[row * width + col];
        if (value == NonogramLineSolver.filled) {
          run++;
        } else {
          if (run > 0) {
            values.add(run);
            run = 0;
          }
        }
      }
      if (run > 0) {
        values.add(run);
      }
      clues.add(values);
    }
    return clues;
  }

  List<List<int>> _cluesForColumns(List<int> cells, int width, int height) {
    final List<List<int>> clues = <List<int>>[];
    for (int col = 0; col < width; col++) {
      final List<int> values = <int>[];
      int run = 0;
      for (int row = 0; row < height; row++) {
        final int value = cells[row * width + col];
        if (value == NonogramLineSolver.filled) {
          run++;
        } else {
          if (run > 0) {
            values.add(run);
            run = 0;
          }
        }
      }
      if (run > 0) {
        values.add(run);
      }
      clues.add(values);
    }
    return clues;
  }

  void _targetDensity(
    SeededRng rng,
    List<int> bitmap,
    int width,
    int height,
    _BitmapProfile profile,
  ) {
    final int cellCount = width * height;
    final int jitter = rng.randIntRange(
      -profile.densityJitterPermille,
      profile.densityJitterPermille + 1,
    );
    final int target =
        (cellCount * (profile.targetFilledPermille + jitter)) ~/ 1000;
    final int minFilled = (cellCount * profile.minFilledPermille) ~/ 1000;
    final int maxFilled = (cellCount * profile.maxFilledPermille) ~/ 1000;
    final int targetFilled = _boundedInt(target, minFilled, maxFilled);

    int filled = _filledCount(bitmap);
    if (filled < targetFilled) {
      final List<int> order = rng.permute(
        List<int>.generate(cellCount, (int index) => index),
      );
      for (int pass = 0; pass < 3 && filled < targetFilled; pass++) {
        for (final int index in order) {
          if (filled >= targetFilled) {
            break;
          }
          if (bitmap[index] == NonogramLineSolver.filled) {
            continue;
          }
          final int row = index ~/ width;
          final int col = index % width;
          final int neighbors = _filledNeighborCount(
            bitmap,
            width,
            height,
            col,
            row,
          );
          if (neighbors >= (pass == 0 ? 2 : 1)) {
            bitmap[index] = NonogramLineSolver.filled;
            filled++;
          }
        }
      }
    } else if (filled > targetFilled) {
      final List<int> order = rng.permute(
        List<int>.generate(cellCount, (int index) => index),
      );
      for (int pass = 0; pass < 3 && filled > targetFilled; pass++) {
        for (final int index in order) {
          if (filled <= targetFilled) {
            break;
          }
          if (bitmap[index] != NonogramLineSolver.filled) {
            continue;
          }
          final int row = index ~/ width;
          final int col = index % width;
          final int neighbors = _filledNeighborCount(
            bitmap,
            width,
            height,
            col,
            row,
          );
          if (neighbors >= (pass == 0 ? 3 : 2)) {
            bitmap[index] = NonogramLineSolver.empty;
            filled--;
          }
        }
      }
    }
  }

  void _targetFragmentation(
    SeededRng rng,
    List<int> bitmap,
    int width,
    int height,
    _BitmapProfile profile,
  ) {
    _BitmapMetrics metrics = _bitmapMetrics(bitmap, width, height);
    final int maxEdits = (width * height) ~/ 5;
    int edits = 0;

    while (metrics.fragmentation < profile.minFragmentation &&
        edits < maxEdits) {
      bool changed = false;
      final List<int> order = rng.permute(
        List<int>.generate(width * height, (int index) => index),
      );
      for (final int index in order) {
        if (edits >= maxEdits ||
            metrics.fragmentation >= profile.minFragmentation) {
          break;
        }
        if (bitmap[index] != NonogramLineSolver.filled) {
          continue;
        }
        final int row = index ~/ width;
        final int col = index % width;
        final bool splitsHorizontal =
            col > 0 &&
            col + 1 < width &&
            _isFilledCell(bitmap, width, col - 1, row) &&
            _isFilledCell(bitmap, width, col + 1, row);
        final bool splitsVertical =
            row > 0 &&
            row + 1 < height &&
            _isFilledCell(bitmap, width, col, row - 1) &&
            _isFilledCell(bitmap, width, col, row + 1);
        final bool denseInterior =
            profile.minFragmentation >= 2.5 &&
            _filledNeighborCount(bitmap, width, height, col, row) >= 3;
        if (!splitsHorizontal && !splitsVertical && !denseInterior) {
          continue;
        }
        bitmap[index] = NonogramLineSolver.empty;
        if (_createsNearbySingleton(bitmap, width, height, col, row)) {
          bitmap[index] = NonogramLineSolver.filled;
          continue;
        }
        edits++;
        changed = true;
        metrics = _bitmapMetrics(bitmap, width, height);
      }
      if (!changed) {
        changed = _addFragmentPair(rng, bitmap, width, height, profile);
        if (changed) {
          edits++;
          metrics = _bitmapMetrics(bitmap, width, height);
        } else {
          break;
        }
      }
    }

    while (metrics.fragmentation > profile.maxFragmentation &&
        edits < maxEdits) {
      bool changed = false;
      final List<int> order = rng.permute(
        List<int>.generate(width * height, (int index) => index),
      );
      for (final int index in order) {
        if (edits >= maxEdits ||
            metrics.fragmentation <= profile.maxFragmentation) {
          break;
        }
        if (bitmap[index] == NonogramLineSolver.filled) {
          continue;
        }
        final int row = index ~/ width;
        final int col = index % width;
        final bool bridgesHorizontal =
            col > 0 &&
            col + 1 < width &&
            _isFilledCell(bitmap, width, col - 1, row) &&
            _isFilledCell(bitmap, width, col + 1, row);
        final bool bridgesVertical =
            row > 0 &&
            row + 1 < height &&
            _isFilledCell(bitmap, width, col, row - 1) &&
            _isFilledCell(bitmap, width, col, row + 1);
        final bool denseGap =
            profile.maxFragmentation <= 1.6 &&
            _filledNeighborCount(bitmap, width, height, col, row) >= 2;
        if (!bridgesHorizontal && !bridgesVertical && !denseGap) {
          continue;
        }
        bitmap[index] = NonogramLineSolver.filled;
        edits++;
        changed = true;
        metrics = _bitmapMetrics(bitmap, width, height);
      }
      if (!changed) {
        break;
      }
    }
  }

  bool _addFragmentPair(
    SeededRng rng,
    List<int> bitmap,
    int width,
    int height,
    _BitmapProfile profile,
  ) {
    if (profile.minFragmentation < 2.5) {
      return false;
    }
    final int maxFilled = (width * height * profile.maxFilledPermille) ~/ 1000;
    if (_filledCount(bitmap) + 2 > maxFilled) {
      return false;
    }

    final List<int> order = rng.permute(
      List<int>.generate(width * height, (int index) => index),
    );
    for (final int index in order) {
      final int row = index ~/ width;
      final int col = index % width;
      if (bitmap[index] == NonogramLineSolver.filled) {
        continue;
      }
      final bool horizontal = rng.nextBool();
      final int col2 = horizontal ? col + 1 : col;
      final int row2 = horizontal ? row : row + 1;
      if (!_inBounds(width, height, col2, row2) ||
          _isFilledCell(bitmap, width, col2, row2)) {
        continue;
      }
      if (_filledNeighborCount(bitmap, width, height, col, row) > 0 ||
          _filledNeighborCount(bitmap, width, height, col2, row2) > 0) {
        continue;
      }
      _setFilled(bitmap, width, col, row);
      _setFilled(bitmap, width, col2, row2);
      return true;
    }
    return false;
  }

  void _cleanupSingletonsAndPinholes(
    SeededRng rng,
    List<int> bitmap,
    int width,
    int height,
    _BitmapProfile profile,
  ) {
    final List<int> order = rng.permute(
      List<int>.generate(width * height, (int index) => index),
    );
    for (int pass = 0; pass < 2; pass++) {
      for (final int index in order) {
        final int row = index ~/ width;
        final int col = index % width;
        final int neighbors = _filledNeighborCount(
          bitmap,
          width,
          height,
          col,
          row,
        );
        if (bitmap[index] == NonogramLineSolver.filled && neighbors == 0) {
          if (_bitmapMetrics(bitmap, width, height).density >
              profile.targetDensity) {
            bitmap[index] = NonogramLineSolver.empty;
          } else {
            _fillFirstEmptyNeighbor(bitmap, width, height, col, row);
          }
        } else if (bitmap[index] == NonogramLineSolver.empty &&
            neighbors >= 4) {
          bitmap[index] = NonogramLineSolver.filled;
        }
      }
    }
  }

  String? _quickReject(_BitmapMetrics metrics, _BitmapProfile profile) {
    if (metrics.density < profile.minDensity ||
        metrics.density > profile.maxDensity) {
      return 'density_outside_profile';
    }
    if (metrics.fragmentation > profile.maxFragmentation + 0.2) {
      return 'fragmentation_outside_profile';
    }
    if (metrics.isolatedFilledRatio > profile.maxIsolatedFilledRatio) {
      return 'too_many_isolated_filled_cells';
    }
    if (metrics.emptyFullLineRatio > profile.maxEmptyFullLineRatio) {
      return 'too_many_empty_or_full_lines';
    }
    if (metrics.largestSolidRectangleRatio > profile.maxSolidRectangleRatio) {
      return 'giant_rectangle';
    }
    if (metrics.largestFilledComponentRatio > profile.maxFilledComponentRatio) {
      return 'giant_blob';
    }
    if (profile.rejectExactSymmetry && metrics.hasExactSymmetry) {
      return 'exact_symmetry';
    }
    if (metrics.visualScore < profile.minVisualScore) {
      return 'low_visual_score';
    }
    return null;
  }

  _BitmapMetrics _bitmapMetrics(List<int> bitmap, int width, int height) {
    final int cellCount = width * height;
    if (cellCount == 0) {
      return const _BitmapMetrics(
        density: 0.0,
        fragmentation: 0.0,
        visualScore: 0.0,
        isolatedFilledRatio: 0.0,
        emptyFullLineRatio: 0.0,
        largestFilledComponentRatio: 0.0,
        largestSolidRectangleRatio: 0.0,
        hasExactSymmetry: false,
      );
    }

    int filled = 0;
    int isolated = 0;
    int emptyOrFullLines = 0;
    int totalClues = 0;

    for (int row = 0; row < height; row++) {
      int rowFilled = 0;
      bool inRun = false;
      for (int col = 0; col < width; col++) {
        if (_isFilledCell(bitmap, width, col, row)) {
          filled++;
          rowFilled++;
          if (!inRun) {
            totalClues++;
            inRun = true;
          }
          if (_filledNeighborCount(bitmap, width, height, col, row) == 0) {
            isolated++;
          }
        } else {
          inRun = false;
        }
      }
      if (rowFilled == 0 || rowFilled == width) {
        emptyOrFullLines++;
      }
    }

    for (int col = 0; col < width; col++) {
      int colFilled = 0;
      bool inRun = false;
      for (int row = 0; row < height; row++) {
        if (_isFilledCell(bitmap, width, col, row)) {
          colFilled++;
          if (!inRun) {
            totalClues++;
            inRun = true;
          }
        } else {
          inRun = false;
        }
      }
      if (colFilled == 0 || colFilled == height) {
        emptyOrFullLines++;
      }
    }

    final double density = filled / cellCount;
    final double fragmentation = totalClues / (width + height);
    final double isolatedRatio = filled == 0 ? 0.0 : isolated / filled;
    final double emptyFullLineRatio = emptyOrFullLines / (width + height);
    final double componentRatio = filled == 0
        ? 0.0
        : _largestFilledComponent(bitmap, width, height) / filled;
    final double rectangleRatio = filled == 0
        ? 0.0
        : _largestSolidRectangle(bitmap, width, height) / filled;
    final bool symmetry = _hasExactSymmetry(bitmap, width, height);
    final double visualScore = _visualScore(
      density: density,
      fragmentation: fragmentation,
      isolatedRatio: isolatedRatio,
      emptyFullLineRatio: emptyFullLineRatio,
      componentRatio: componentRatio,
      rectangleRatio: rectangleRatio,
      symmetry: symmetry,
    );

    return _BitmapMetrics(
      density: density,
      fragmentation: fragmentation,
      visualScore: visualScore,
      isolatedFilledRatio: isolatedRatio,
      emptyFullLineRatio: emptyFullLineRatio,
      largestFilledComponentRatio: componentRatio,
      largestSolidRectangleRatio: rectangleRatio,
      hasExactSymmetry: symmetry,
    );
  }

  double _visualScore({
    required double density,
    required double fragmentation,
    required double isolatedRatio,
    required double emptyFullLineRatio,
    required double componentRatio,
    required double rectangleRatio,
    required bool symmetry,
  }) {
    final double densityPenalty = (density - 0.46).abs() * 120.0;
    final double isolationPenalty = isolatedRatio * 260.0;
    final double emptyFullPenalty = emptyFullLineRatio * 110.0;
    final double blobPenalty = _positiveDouble(componentRatio - 0.72) * 70.0;
    final double rectanglePenalty = rectangleRatio * 45.0;
    final double fragmentationPenalty = fragmentation < 0.7
        ? (0.7 - fragmentation) * 20.0
        : 0.0;
    final double symmetryPenalty = symmetry ? 8.0 : 0.0;
    return _boundedDouble(
      100.0 -
          densityPenalty -
          isolationPenalty -
          emptyFullPenalty -
          blobPenalty -
          rectanglePenalty -
          fragmentationPenalty -
          symmetryPenalty,
      0.0,
      100.0,
    );
  }

  int _largestFilledComponent(List<int> bitmap, int width, int height) {
    final List<bool> visited = List<bool>.filled(width * height, false);
    int largest = 0;
    for (int index = 0; index < bitmap.length; index++) {
      if (visited[index] || bitmap[index] != NonogramLineSolver.filled) {
        continue;
      }
      int size = 0;
      final List<int> stack = <int>[index];
      visited[index] = true;
      while (stack.isNotEmpty) {
        final int current = stack.removeLast();
        size++;
        final int row = current ~/ width;
        final int col = current % width;
        _pushFilledNeighbor(
          bitmap,
          width,
          height,
          visited,
          stack,
          col - 1,
          row,
        );
        _pushFilledNeighbor(
          bitmap,
          width,
          height,
          visited,
          stack,
          col + 1,
          row,
        );
        _pushFilledNeighbor(
          bitmap,
          width,
          height,
          visited,
          stack,
          col,
          row - 1,
        );
        _pushFilledNeighbor(
          bitmap,
          width,
          height,
          visited,
          stack,
          col,
          row + 1,
        );
      }
      if (size > largest) {
        largest = size;
      }
    }
    return largest;
  }

  void _pushFilledNeighbor(
    List<int> bitmap,
    int width,
    int height,
    List<bool> visited,
    List<int> stack,
    int col,
    int row,
  ) {
    if (!_inBounds(width, height, col, row)) {
      return;
    }
    final int index = row * width + col;
    if (visited[index] || bitmap[index] != NonogramLineSolver.filled) {
      return;
    }
    visited[index] = true;
    stack.add(index);
  }

  int _largestSolidRectangle(List<int> bitmap, int width, int height) {
    final List<int> heights = List<int>.filled(width, 0);
    int largest = 0;
    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        heights[col] = _isFilledCell(bitmap, width, col, row)
            ? heights[col] + 1
            : 0;
      }
      for (int right = 0; right < width; right++) {
        int minHeight = height + 1;
        for (int left = right; left >= 0; left--) {
          if (heights[left] == 0) {
            break;
          }
          minHeight = _minInt(minHeight, heights[left]);
          final int area = minHeight * (right - left + 1);
          if (area > largest) {
            largest = area;
          }
        }
      }
    }
    return largest;
  }

  bool _hasExactSymmetry(List<int> bitmap, int width, int height) {
    bool horizontal = true;
    bool vertical = true;
    bool rotational = true;
    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        final int value = bitmap[row * width + col];
        if (value != bitmap[(height - row - 1) * width + col]) {
          horizontal = false;
        }
        if (value != bitmap[row * width + (width - col - 1)]) {
          vertical = false;
        }
        if (value != bitmap[(height - row - 1) * width + (width - col - 1)]) {
          rotational = false;
        }
      }
    }
    return horizontal || vertical || rotational;
  }

  bool _createsNearbySingleton(
    List<int> bitmap,
    int width,
    int height,
    int col,
    int row,
  ) {
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx.abs() + dy.abs() != 1 && (dx != 0 || dy != 0)) {
          continue;
        }
        final int x = col + dx;
        final int y = row + dy;
        if (!_inBounds(width, height, x, y)) {
          continue;
        }
        if (_isFilledCell(bitmap, width, x, y) &&
            _filledNeighborCount(bitmap, width, height, x, y) == 0) {
          return true;
        }
      }
    }
    return false;
  }

  void _fillFirstEmptyNeighbor(
    List<int> bitmap,
    int width,
    int height,
    int col,
    int row,
  ) {
    const List<List<int>> directions = <List<int>>[
      <int>[1, 0],
      <int>[0, 1],
      <int>[-1, 0],
      <int>[0, -1],
    ];
    for (final List<int> direction in directions) {
      final int x = col + direction[0];
      final int y = row + direction[1];
      if (_inBounds(width, height, x, y) &&
          !_isFilledCell(bitmap, width, x, y)) {
        _setFilled(bitmap, width, x, y);
        return;
      }
    }
  }

  void _fillRect(
    List<int> bitmap,
    int width,
    int height,
    int left,
    int top,
    int right,
    int bottom,
  ) {
    for (int y = _maxInt(0, top); y <= _minInt(height - 1, bottom); y++) {
      for (int x = _maxInt(0, left); x <= _minInt(width - 1, right); x++) {
        _setFilled(bitmap, width, x, y);
      }
    }
  }

  void _drawLine(
    List<int> bitmap,
    int width,
    int height,
    int x0,
    int y0,
    int x1,
    int y1, {
    required int thickness,
  }) {
    final int dx = (x1 - x0).abs();
    final int dy = -(y1 - y0).abs();
    final int sx = x0 < x1 ? 1 : -1;
    final int sy = y0 < y1 ? 1 : -1;
    int error = dx + dy;
    int x = x0;
    int y = y0;

    while (true) {
      _paintBrush(bitmap, width, height, x, y, thickness);
      if (x == x1 && y == y1) {
        break;
      }
      final int twiceError = error * 2;
      if (twiceError >= dy) {
        error += dy;
        x += sx;
      }
      if (twiceError <= dx) {
        error += dx;
        y += sy;
      }
      if (!_inBounds(width, height, x, y) &&
          (x < -1 || x > width || y < -1 || y > height)) {
        break;
      }
    }
  }

  void _paintBrush(
    List<int> bitmap,
    int width,
    int height,
    int col,
    int row,
    int thickness,
  ) {
    final int radius = thickness <= 1 ? 0 : 1;
    for (int y = row - radius; y <= row + radius; y++) {
      for (int x = col - radius; x <= col + radius; x++) {
        if (_inBounds(width, height, x, y) &&
            (x - col).abs() + (y - row).abs() <= radius + 1) {
          _setFilled(bitmap, width, x, y);
        }
      }
    }
  }

  int _filledNeighborCount(
    List<int> bitmap,
    int width,
    int height,
    int col,
    int row,
  ) {
    int count = 0;
    if (row > 0 && _isFilledCell(bitmap, width, col, row - 1)) {
      count++;
    }
    if (row + 1 < height && _isFilledCell(bitmap, width, col, row + 1)) {
      count++;
    }
    if (col > 0 && _isFilledCell(bitmap, width, col - 1, row)) {
      count++;
    }
    if (col + 1 < width && _isFilledCell(bitmap, width, col + 1, row)) {
      count++;
    }
    return count;
  }

  bool _isFilledCell(List<int> bitmap, int width, int col, int row) {
    return bitmap[row * width + col] == NonogramLineSolver.filled;
  }

  void _setFilled(List<int> bitmap, int width, int col, int row) {
    bitmap[row * width + col] = NonogramLineSolver.filled;
  }

  void _setEmpty(List<int> bitmap, int width, int col, int row) {
    bitmap[row * width + col] = NonogramLineSolver.empty;
  }

  bool _inBounds(int width, int height, int col, int row) {
    return col >= 0 && col < width && row >= 0 && row < height;
  }

  int _filledCount(List<int> bitmap) {
    int filled = 0;
    for (final int value in bitmap) {
      if (value == NonogramLineSolver.filled) {
        filled++;
      }
    }
    return filled;
  }

  int _minInt(int a, int b) => a < b ? a : b;

  int _maxInt(int a, int b) => a > b ? a : b;

  int _boundedInt(int value, int min, int max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  double _boundedDouble(double value, double min, double max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  double _positiveDouble(double value) {
    return value > 0.0 ? value : 0.0;
  }
}

class _BitmapProfile {
  const _BitmapProfile({
    required this.level,
    required this.minFilledPermille,
    required this.targetFilledPermille,
    required this.maxFilledPermille,
    required this.densityJitterPermille,
    required this.minFragmentation,
    required this.maxFragmentation,
    required this.maxIsolatedFilledRatio,
    required this.maxEmptyFullLineRatio,
    required this.maxFilledComponentRatio,
    required this.maxSolidRectangleRatio,
    required this.rejectExactSymmetry,
    required this.minVisualScore,
    required this.scaffoldWalks,
    required this.scaffoldMinSteps,
    required this.scaffoldMaxSteps,
    required this.regionCount,
    required this.regionVariance,
    required this.minRegionRadius,
    required this.maxRegionRadius,
    required this.strokeCount,
    required this.strokeThickness,
    required this.cutCount,
    required this.chipCount,
    required this.iconAccentCount,
  });

  final String level;
  final int minFilledPermille;
  final int targetFilledPermille;
  final int maxFilledPermille;
  final int densityJitterPermille;
  final double minFragmentation;
  final double maxFragmentation;
  final double maxIsolatedFilledRatio;
  final double maxEmptyFullLineRatio;
  final double maxFilledComponentRatio;
  final double maxSolidRectangleRatio;
  final bool rejectExactSymmetry;
  final double minVisualScore;
  final int scaffoldWalks;
  final int scaffoldMinSteps;
  final int scaffoldMaxSteps;
  final int regionCount;
  final int regionVariance;
  final int minRegionRadius;
  final int maxRegionRadius;
  final int strokeCount;
  final int strokeThickness;
  final int cutCount;
  final int chipCount;
  final int iconAccentCount;

  double get minDensity => minFilledPermille / 1000.0;
  double get targetDensity => targetFilledPermille / 1000.0;
  double get maxDensity => maxFilledPermille / 1000.0;

  static _BitmapProfile forLevel(String level) {
    switch (level.toLowerCase()) {
      case 'easy':
        return const _BitmapProfile(
          level: 'easy',
          minFilledPermille: 360,
          targetFilledPermille: 500,
          maxFilledPermille: 660,
          densityJitterPermille: 35,
          minFragmentation: 0.75,
          maxFragmentation: 1.35,
          maxIsolatedFilledRatio: 0.03,
          maxEmptyFullLineRatio: 0.22,
          maxFilledComponentRatio: 0.94,
          maxSolidRectangleRatio: 0.56,
          rejectExactSymmetry: false,
          minVisualScore: 42.0,
          scaffoldWalks: 2,
          scaffoldMinSteps: 5,
          scaffoldMaxSteps: 8,
          regionCount: 2,
          regionVariance: 1,
          minRegionRadius: 2,
          maxRegionRadius: 5,
          strokeCount: 1,
          strokeThickness: 2,
          cutCount: 0,
          chipCount: 0,
          iconAccentCount: 1,
        );
      case 'hard':
        return const _BitmapProfile(
          level: 'hard',
          minFilledPermille: 310,
          targetFilledPermille: 445,
          maxFilledPermille: 600,
          densityJitterPermille: 55,
          minFragmentation: 2.9,
          maxFragmentation: 4.45,
          maxIsolatedFilledRatio: 0.065,
          maxEmptyFullLineRatio: 0.15,
          maxFilledComponentRatio: 0.84,
          maxSolidRectangleRatio: 0.42,
          rejectExactSymmetry: true,
          minVisualScore: 48.0,
          scaffoldWalks: 4,
          scaffoldMinSteps: 3,
          scaffoldMaxSteps: 7,
          regionCount: 3,
          regionVariance: 2,
          minRegionRadius: 1,
          maxRegionRadius: 4,
          strokeCount: 5,
          strokeThickness: 1,
          cutCount: 9,
          chipCount: 14,
          iconAccentCount: 7,
        );
      case 'expert':
        return const _BitmapProfile(
          level: 'expert',
          minFilledPermille: 300,
          targetFilledPermille: 430,
          maxFilledPermille: 610,
          densityJitterPermille: 60,
          minFragmentation: 1.9,
          maxFragmentation: 4.9,
          maxIsolatedFilledRatio: 0.075,
          maxEmptyFullLineRatio: 0.13,
          maxFilledComponentRatio: 0.80,
          maxSolidRectangleRatio: 0.38,
          rejectExactSymmetry: true,
          minVisualScore: 48.0,
          scaffoldWalks: 5,
          scaffoldMinSteps: 3,
          scaffoldMaxSteps: 6,
          regionCount: 4,
          regionVariance: 2,
          minRegionRadius: 1,
          maxRegionRadius: 4,
          strokeCount: 6,
          strokeThickness: 1,
          cutCount: 12,
          chipCount: 18,
          iconAccentCount: 8,
        );
      case 'medium':
      case 'auto':
      default:
        return const _BitmapProfile(
          level: 'medium',
          minFilledPermille: 340,
          targetFilledPermille: 470,
          maxFilledPermille: 630,
          densityJitterPermille: 45,
          minFragmentation: 1.15,
          maxFragmentation: 1.55,
          maxIsolatedFilledRatio: 0.045,
          maxEmptyFullLineRatio: 0.18,
          maxFilledComponentRatio: 0.88,
          maxSolidRectangleRatio: 0.48,
          rejectExactSymmetry: true,
          minVisualScore: 46.0,
          scaffoldWalks: 4,
          scaffoldMinSteps: 3,
          scaffoldMaxSteps: 7,
          regionCount: 3,
          regionVariance: 1,
          minRegionRadius: 2,
          maxRegionRadius: 4,
          strokeCount: 3,
          strokeThickness: 1,
          cutCount: 3,
          chipCount: 4,
          iconAccentCount: 4,
        );
    }
  }
}

class _BitmapMetrics {
  const _BitmapMetrics({
    required this.density,
    required this.fragmentation,
    required this.visualScore,
    required this.isolatedFilledRatio,
    required this.emptyFullLineRatio,
    required this.largestFilledComponentRatio,
    required this.largestSolidRectangleRatio,
    required this.hasExactSymmetry,
  });

  final double density;
  final double fragmentation;
  final double visualScore;
  final double isolatedFilledRatio;
  final double emptyFullLineRatio;
  final double largestFilledComponentRatio;
  final double largestSolidRectangleRatio;
  final bool hasExactSymmetry;
}

class _CandidateReport {
  const _CandidateReport({
    required this.profile,
    required this.metrics,
    required this.attempts,
    required this.rejectionReason,
  });

  factory _CandidateReport.empty(_BitmapProfile profile) {
    return _CandidateReport(
      profile: profile,
      metrics: const _BitmapMetrics(
        density: 0.0,
        fragmentation: 0.0,
        visualScore: 0.0,
        isolatedFilledRatio: 0.0,
        emptyFullLineRatio: 0.0,
        largestFilledComponentRatio: 0.0,
        largestSolidRectangleRatio: 0.0,
        hasExactSymmetry: false,
      ),
      attempts: 0,
      rejectionReason: 'not_started',
    );
  }

  final _BitmapProfile profile;
  final _BitmapMetrics metrics;
  final int attempts;
  final String rejectionReason;
}
