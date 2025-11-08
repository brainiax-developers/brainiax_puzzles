// Dart port of Harald Bögeholz's Haskell Slitherlink generator (generate.hs).
//
// Behavior mirrored:
// 1) Build a random "inside" set of cells using a frontier of directional
//    seeds; add a cell only if its 6-forward neighborhood is disjoint from the
//    current inside set (generate.hs:addSquare + forward6).
// 2) Derive a full clue grid where each cell's number is the count of edges
//    between inside/outside across its four neighbors (generate.hs:makeProblem
//    + countLines). Out-of-bounds neighbors are treated as outside.
// 3) Remove clues in a random permutation while maintaining uniqueness by
//    re-solving with a cap of two solutions (generate.hs:generate/remove).
//
// Notes:
// - The Haskell reference has no explicit difficulty tiers; we therefore apply
//   the same algorithm for all requested difficulties. Difficulty scoring and
//   bucketing remain handled externally by the engine's scorer.
// - Determinism: all randomness flows from context.rng.

import '../generators/generator.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../util/seeded_rng.dart';
import 'slitherlink_board.dart';
import 'slitherlink_solver.dart';
// Topology & validator removed in Haskell-port (uniqueness handled via solver).

// Haskell-port helper types at top-level (Dart doesn't allow nested classes)
class _Inside {
  _Inside(this.rows, this.cols, this.ins, this.seeds);
  final int rows;
  final int cols;
  final Set<int> ins; // linear indices row*cols + col
  final Set<_Seed> seeds;
}

class _Seed {
  const _Seed(this.row, this.col, this.dr, this.dc);
  final int row;
  final int col;
  final int dr;
  final int dc;

  @override
  bool operator ==(Object other) =>
      other is _Seed && row == other.row && col == other.col && dr == other.dr && dc == other.dc;
  @override
  int get hashCode => Object.hash(row, col, dr, dc);
}

class SlitherlinkGenerator extends PuzzleGenerator<SlitherlinkBoard> {
  const SlitherlinkGenerator();

  // Supported board cell dimensions (rows x columns).
  // The reference supports arbitrary sizes; to keep performance predictable on
  // low-end devices, we clamp to a reasonable range and square boards.
  static const List<int> _supportedWidths = <int>[5, 6, 7, 8, 9];
  static const List<int> _supportedHeights = <int>[5, 6, 7, 8, 9];

  @override
  PuzzleGenerationResult<SlitherlinkBoard> generate(GeneratorContext context) {
    final int width = context.size.width; // cell columns
    final int height = context.size.height; // cell rows
    if (!_supportedWidths.contains(width) || !_supportedHeights.contains(height)) {
      throw ArgumentError('Unsupported Slitherlink size: ${width}x$height');
    }
    if (width != height) {
      // The Haskell tool generates rectangular boards too, but our app flow and
      // scorer are optimized for square boards; keep it simple and deterministic.
      throw ArgumentError('Non-square Slitherlink sizes are not supported');
    }

    final Stopwatch sw = Stopwatch()..start();
    final SlitherlinkSolver solver = const SlitherlinkSolver();
    final SeededRng rng = context.rng;
    // Phase 1: Build a random inside set and derive the full clue grid.
  final _Inside inside = _initialInside(width, rng);
    _growInside(inside, rng);
    final List<int?> fullClues = _makeProblemFromInside(inside);

    // Phase 2: Remove clues in random order while keeping uniqueness.
    final List<int> perm = List<int>.generate(width * width, (int i) => i);
    rng.shuffle(perm);
    List<int?> working = List<int?>.from(fullClues);
    final _SolveResult base = _solveWithMetrics(
      clues: working,
      width: width,
      solver: solver,
      maxSolutions: 1,
      rngSalt: 'base',
    );
    // If the full puzzle isn't solvable (shouldn't happen), restart with full clues.
    if (base.solutionCount != 1) {
      working = List<int?>.from(fullClues);
    }

    for (int t = perm.length; t >= 1; t--) {
      final int idx = perm[perm.length - t];
      final int? prev = working[idx];
      if (prev == null) continue;
      working[idx] = null; // Unconstrained
      final _SolveResult res = _solveWithMetrics(
        clues: working,
        width: width,
        solver: solver,
        maxSolutions: 2,
        rngSalt: 'remove:$t',
      );
      if (res.solutionCount != 1) {
        // Revert
        working[idx] = prev;
      }
    }

    final SlitherlinkBoard puzzle = SlitherlinkBoard.empty(
      width: width,
      height: height,
      clues: working,
    );

    sw.stop();
    final Map<String, Object?> telemetry = <String, Object?>{
      'width': width,
      'height': height,
      'revealedClues': working.where((c) => c != null).length,
      'generationUs': sw.elapsedMicroseconds,
      'difficulty': context.difficulty.level.toLowerCase(),
      'generator': 'hs_port',
    };
    DeterminismGuard.assertNoFloatsOrDateTimes(puzzle.toJson());
    return PuzzleGenerationResult<SlitherlinkBoard>(
      board: puzzle,
      snapshot: GenerationSnapshot(telemetry: telemetry),
    );
  }
  // --- Haskell-port helpers ---

  static const List<List<int>> _directions4 = <List<int>>[
    <int>[0, 1],
    <int>[1, 0],
    <int>[0, -1],
    <int>[-1, 0],
  ];

  static List<int> _turnLeft(int dr, int dc) => <int>[-dc, dr];
  static List<int> _turnRight(int dr, int dc) => <int>[dc, -dr];

  static List<List<int>> _forward6(int r, int c, int dr, int dc) {
    final List<int> l = _turnLeft(dr, dc);
    final List<int> rr = _turnRight(dr, dc);
    return <List<int>>[
      <int>[r, c],
      <int>[r + l[0], c + l[1]],
      <int>[r + rr[0], c + rr[1]],
      <int>[r + dr, c + dc],
      <int>[r + l[0] + dr, c + l[1] + dc],
      <int>[r + rr[0] + dr, c + rr[1] + dc],
    ];
  }

  static _Seed _makeSeed(int r, int c, int dr, int dc) => _Seed(r + dr, c + dc, dr, dc);

  static bool _inGrid(int rows, int cols, _Seed s) =>
      s.row >= 0 && s.row < rows && s.col >= 0 && s.col < cols;

  _Inside _initialInside(int size, SeededRng rng) {
    final int nr = size;
    final int nc = size;
    final int r = rng.nextIntInRange(nr);
    final int c = rng.nextIntInRange(nc);
    final Set<_Seed> initialSeeds = <_Seed>{};
    for (final List<int> d in _directions4) {
      final _Seed s = _makeSeed(r, c, d[0], d[1]);
      if (_inGrid(nr, nc, s)) initialSeeds.add(s);
    }
    return _Inside(nr, nc, <int>{r * nc + c}, initialSeeds);
  }

  void _growInside(_Inside st, SeededRng rng) {
    // Mirrors addSquare: while seeds remain, pick random; add if forward6 disjoint.
    final int nr = st.rows;
    final int nc = st.cols;
    final List<_Seed> seedsList = st.seeds.toList();
    while (seedsList.isNotEmpty) {
      final int pick = rng.nextIntInRange(seedsList.length);
      final _Seed chosen = seedsList.removeAt(pick);
      st.seeds.remove(chosen);
      final int r = chosen.row;
      final int c = chosen.col;
      final int dr = chosen.dr;
      final int dc = chosen.dc;

      // Check disjointness of forward6 with current inside set.
      bool disjoint = true;
  for (final List<int> p in _forward6(r, c, dr, dc)) {
        final int pr = p[0];
        final int pc = p[1];
        if (pr < 0 || pr >= nr || pc < 0 || pc >= nc) {
          continue; // out-of-bounds can't intersect st.ins
        }
        if (st.ins.contains(pr * nc + pc)) {
          disjoint = false;
          break;
        }
      }
      if (!disjoint) {
        // Discard this seed and continue.
        continue;
      }

      // Accept: add cell i = (r,c)
      st.ins.add(r * nc + c);

      // Add new seeds from i with directions d, left, right.
      final List<List<int>> dirs = <List<int>>[
        <int>[dr, dc],
        _turnLeft(dr, dc),
        _turnRight(dr, dc),
      ];
      for (final List<int> d in dirs) {
        final _Seed s = _makeSeed(r, c, d[0], d[1]);
        if (_inGrid(nr, nc, s)) {
          if (st.seeds.add(s)) {
            seedsList.add(s);
          }
        }
      }
    }
  }

  List<int?> _makeProblemFromInside(_Inside ins) {
    final int nr = ins.rows;
    final int nc = ins.cols;
    final List<int?> clues = List<int?>.filled(nr * nc, 0);
    for (int r = 0; r < nr; r++) {
      for (int c = 0; c < nc; c++) {
        final bool thisInside = ins.ins.contains(r * nc + c);
        int count = 0;
        for (final List<int> d in _directions4) {
          final int r2 = r + d[0];
          final int c2 = c + d[1];
          bool otherInside = false;
          if (r2 >= 0 && r2 < nr && c2 >= 0 && c2 < nc) {
            otherInside = ins.ins.contains(r2 * nc + c2);
          } else {
            otherInside = false; // out-of-bounds treated as outside
          }
          if (thisInside != otherInside) count++;
        }
        clues[r * nc + c] = count;
      }
    }
    return clues;
  }

  _SolveResult _solveWithMetrics({
    required List<int?> clues,
    required int width,
    required SlitherlinkSolver solver,
    required int maxSolutions,
    String rngSalt = '',
  }) {
    final SlitherlinkBoard board = SlitherlinkBoard.empty(
      width: width,
      height: width,
      clues: clues,
    );
    final SolverContext ctx = SolverContext(
      // Use a deterministic seed derived from the visible clues and width;
      // avoid List.hashCode (identity-based) which is not stable across runs.
      rng: SeededRng(
        Seed.fromString(
          'slitherlink_solve:$width:$rngSalt:${clues.map((c) => c?.toString() ?? '_').join(',')}',
        ),
      ),
      maxSolutions: maxSolutions,
      preferredEdgeValues: null,
      speculativeStepBudget: 150000,
    );
    final SolverResult<SlitherlinkBoard> result = solver.solve(board, ctx);
    return _SolveResult(
      solutionCount: result.solutions.length,
      // Haskell generator only needs uniqueness; we omit loop metrics here.
    );
  }
}

class _SolveResult {
  const _SolveResult({
    required this.solutionCount,
  });
  final int solutionCount;
}

