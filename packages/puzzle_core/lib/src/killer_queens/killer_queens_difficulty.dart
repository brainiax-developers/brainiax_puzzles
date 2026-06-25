import '../difficulty/telemetry.dart';
import 'killer_queens_board.dart';

class KillerQueensDifficultyScorer extends DifficultyScorer<KillerQueensBoard> {
  const KillerQueensDifficultyScorer();

  @override
  DifficultyTelemetry score({
    required KillerQueensBoard puzzle,
    required KillerQueensBoard solution,
    required DifficultyContext context,
  }) {
    final int size = puzzle.size;
    final int cellCount = size * size;
    final int regionCount = puzzle.cages.length;
    final int givens = puzzle.fixed.where((bool value) => value).length;

    final Map<String, Object?> generator = context.generatorTelemetry;
    final Map<String, Object?> solver = context.solverTelemetry;
    final double solverNodes = _asDouble(solver['nodes']);
    final double branches = _asDouble(solver['branches']);
    final double backtracks = _asDouble(solver['backtracks']);
    final double averageBranchingFactor = _asDouble(
      solver['averageBranchingFactor'],
    );
    final double acceptedGenerationAttempts = _asDouble(
      generator['attempts'],
      fallback: 1.0,
    );

    final _RegionMetrics regions = _measureRegions(puzzle);

    final double solverSearchScore =
        (solverNodes * 0.18) + (branches * 0.30) + (backtracks * 0.70);
    final double branchingScore = averageBranchingFactor * 2.4;
    final double regionVarianceScore = regions.areaVariance * 0.18;
    final double constrainedRegionScore =
        regions.nearSingletonRegionCount * 0.45;
    final double perimeterScore = regions.averagePerimeterToAreaRatio * 1.8;
    final double boardSizeScore = size * 0.25;
    final double attemptsScore = acceptedGenerationAttempts * 0.08;

    final double rawScore =
        solverSearchScore +
        branchingScore +
        regionVarianceScore +
        constrainedRegionScore +
        perimeterScore +
        boardSizeScore +
        attemptsScore;

    final Map<String, num> metrics = <String, num>{
      'boardSize': size,
      'cellCount': cellCount,
      'regionCount': regionCount,
      'avgRegionArea': regions.averageArea,
      'regionAreaVariance': regions.areaVariance,
      'nearSingletonRegionCount': regions.nearSingletonRegionCount,
      'averageRegionPerimeterToAreaRatio': regions.averagePerimeterToAreaRatio,
      'solverNodes': solverNodes,
      'branches': branches,
      'backtracks': backtracks,
      'averageBranchingFactor': averageBranchingFactor,
      'acceptedGenerationAttempts': acceptedGenerationAttempts,
      'givens': givens,
      'solverSearchScore': solverSearchScore,
      'branchingScore': branchingScore,
      'regionVarianceScore': regionVarianceScore,
      'constrainedRegionScore': constrainedRegionScore,
      'perimeterScore': perimeterScore,
      'boardSizeScore': boardSizeScore,
      'attemptsScore': attemptsScore,
      'rawScore': rawScore,
    };

    return DifficultyTelemetry(
      rawScore: rawScore,
      bucket: 'pending',
      metrics: metrics,
    );
  }

  _RegionMetrics _measureRegions(KillerQueensBoard puzzle) {
    if (puzzle.cages.isEmpty) {
      return const _RegionMetrics(
        averageArea: 0.0,
        areaVariance: 0.0,
        nearSingletonRegionCount: 0,
        averagePerimeterToAreaRatio: 0.0,
      );
    }

    final List<int> areas = <int>[];
    final List<double> perimeterRatios = <double>[];
    int nearSingletonRegionCount = 0;

    for (
      int regionIndex = 0;
      regionIndex < puzzle.cages.length;
      regionIndex++
    ) {
      final KillerQueensCage cage = puzzle.cages[regionIndex];
      final int area = cage.cells.length;
      areas.add(area);
      if (area <= 2) {
        nearSingletonRegionCount += 1;
      }

      int perimeter = 0;
      for (final int cell in cage.cells) {
        final int row = cell ~/ puzzle.size;
        final int col = cell % puzzle.size;
        final List<int?> neighbors = <int?>[
          row == 0 ? null : cell - puzzle.size,
          row == puzzle.size - 1 ? null : cell + puzzle.size,
          col == 0 ? null : cell - 1,
          col == puzzle.size - 1 ? null : cell + 1,
        ];
        for (final int? neighbor in neighbors) {
          if (neighbor == null || puzzle.cageByCell[neighbor] != regionIndex) {
            perimeter += 1;
          }
        }
      }
      perimeterRatios.add(area == 0 ? 0.0 : perimeter / area);
    }

    final double averageArea =
        areas.fold<int>(0, (int sum, int area) => sum + area) / areas.length;
    final double variance =
        areas
            .map((int area) {
              final double delta = area - averageArea;
              return delta * delta;
            })
            .fold<double>(0.0, (double sum, double value) => sum + value) /
        areas.length;
    final double averagePerimeterRatio =
        perimeterRatios.fold<double>(
          0.0,
          (double sum, double value) => sum + value,
        ) /
        perimeterRatios.length;

    return _RegionMetrics(
      averageArea: averageArea,
      areaVariance: variance,
      nearSingletonRegionCount: nearSingletonRegionCount,
      averagePerimeterToAreaRatio: averagePerimeterRatio,
    );
  }

  double _asDouble(Object? value, {double fallback = 0.0}) {
    if (value is num) {
      return value.toDouble();
    }
    return fallback;
  }
}

class _RegionMetrics {
  const _RegionMetrics({
    required this.averageArea,
    required this.areaVariance,
    required this.nearSingletonRegionCount,
    required this.averagePerimeterToAreaRatio,
  });

  final double averageArea;
  final double areaVariance;
  final int nearSingletonRegionCount;
  final double averagePerimeterToAreaRatio;
}
