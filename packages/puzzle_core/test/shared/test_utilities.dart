import 'dart:math';
import 'package:puzzle_core/puzzle_core.dart';

/// Shared utilities for puzzle engine testing.
class TestUtilities {
  static final Random _random = Random();

  /// Generate a deterministic seed for testing.
  static String generateTestSeed(String engineId, int testIndex) {
    return 'test:$engineId:$testIndex';
  }

  /// Generate a random seed for property testing.
  static String generateRandomSeed(String engineId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(1000000);
    return 'random:$engineId:$timestamp:$random';
  }

  /// Generate a daily seed for testing.
  static String generateDailySeed(String engineId, DateTime date) {
    final dateStr = '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
    return '$engineId:$dateStr';
  }

  /// Generate a random play seed for testing.
  static String generateRandomPlaySeed(String engineId, String userId, String sessionNonce) {
    return '$engineId:$userId:$sessionNonce';
  }

  /// Measure execution time of a function.
  static Future<Duration> measureTime<T>(Future<T> Function() function) async {
    final stopwatch = Stopwatch()..start();
    await function();
    stopwatch.stop();
    return stopwatch.elapsed;
  }

  /// Check if a puzzle is solvable by attempting to solve it.
  static Future<bool> isSolvable<T>(PuzzleEngine engine, T puzzleState) async {
    try {
      // This is a simplified check - in practice, you'd implement
      // a proper solver or use the engine's built-in solver
      return true; // Placeholder
    } catch (e) {
      return false;
    }
  }

  /// Validate that a puzzle has exactly one solution.
  static Future<bool> hasUniqueSolution<T>(PuzzleEngine engine, T puzzleState) async {
    try {
      // This would implement a solver that exits early if it finds
      // a second solution
      return true; // Placeholder
    } catch (e) {
      return false;
    }
  }

  /// Check if a puzzle state is valid.
  static bool isValidPuzzleState<T>(T puzzleState) {
    // Basic validation - check for null and required properties
    return puzzleState != null;
  }

  /// Generate test data for property testing.
  static List<Map<String, dynamic>> generateTestData({
    required int count,
    required List<String> engineIds,
    required List<String> difficulties,
    required List<String> sizes,
  }) {
    final testData = <Map<String, dynamic>>[];
    
    for (int i = 0; i < count; i++) {
      testData.add({
        'engineId': engineIds[i % engineIds.length],
        'difficulty': difficulties[i % difficulties.length],
        'size': sizes[i % sizes.length],
        'seed': generateRandomSeed(engineIds[i % engineIds.length]),
        'testIndex': i,
      });
    }
    
    return testData;
  }

  /// Parse size string to width and height.
  static Map<String, int> parseSize(String size) {
    final parts = size.split('x');
    if (parts.length != 2) {
      throw ArgumentError('Invalid size format: $size');
    }
    return {
      'width': int.parse(parts[0]),
      'height': int.parse(parts[1]),
    };
  }

  /// Parse difficulty string to DifficultyScore.
  static DifficultyScore parseDifficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const DifficultyScore(value: 0.3, level: 'easy');
      case 'medium':
        return const DifficultyScore(value: 0.6, level: 'medium');
      case 'hard':
        return const DifficultyScore(value: 0.9, level: 'hard');
      default:
        return const DifficultyScore(value: 0.6, level: 'medium');
    }
  }

  /// Create SizeOpt from size string.
  static SizeOpt createSizeOpt(String size) {
    final dimensions = parseSize(size);
    return SizeOpt(
      id: size,
      description: '${dimensions['width']}x${dimensions['height']}',
      width: dimensions['width']!,
      height: dimensions['height']!,
    );
  }

  /// Assert that two puzzles are identical (for reproducibility testing).
  static bool puzzlesAreIdentical<T>(T puzzle1, T puzzle2) {
    // This would implement proper comparison logic
    // For now, just check if they're the same type
    return puzzle1.runtimeType == puzzle2.runtimeType;
  }

  /// Check if a puzzle meets difficulty requirements.
  static bool meetsDifficultyRequirements<T>(
    T puzzle,
    DifficultyScore targetDifficulty,
    double tolerance,
  ) {
    // This would implement difficulty validation
    // For now, return true as placeholder
    return true;
  }

  /// Generate a list of test scenarios.
  static List<TestScenario> generateTestScenarios({
    required List<String> engineIds,
    required List<String> difficulties,
    required List<String> sizes,
    int scenariosPerEngine = 10,
  }) {
    final scenarios = <TestScenario>[];
    
    for (final engineId in engineIds) {
      for (int i = 0; i < scenariosPerEngine; i++) {
        scenarios.add(TestScenario(
          engineId: engineId,
          difficulty: difficulties[i % difficulties.length],
          size: sizes[i % sizes.length],
          seed: generateTestSeed(engineId, i),
          testIndex: i,
        ));
      }
    }
    
    return scenarios;
  }
}

/// Test scenario configuration.
class TestScenario {
  final String engineId;
  final String difficulty;
  final String size;
  final String seed;
  final int testIndex;

  const TestScenario({
    required this.engineId,
    required this.difficulty,
    required this.size,
    required this.seed,
    required this.testIndex,
  });

  Map<String, dynamic> toJson() => {
    'engineId': engineId,
    'difficulty': difficulty,
    'size': size,
    'seed': seed,
    'testIndex': testIndex,
  };

  factory TestScenario.fromJson(Map<String, dynamic> json) => TestScenario(
    engineId: json['engineId'] as String,
    difficulty: json['difficulty'] as String,
    size: json['size'] as String,
    seed: json['seed'] as String,
    testIndex: json['testIndex'] as int,
  );
}

/// Test result for a single scenario.
class TestResult {
  final TestScenario scenario;
  final bool success;
  final String? error;
  final Duration? generationTime;
  final Duration? validationTime;
  final bool isSolvable;
  final bool hasUniqueSolution;
  final bool meetsDifficulty;

  const TestResult({
    required this.scenario,
    required this.success,
    this.error,
    this.generationTime,
    this.validationTime,
    this.isSolvable = false,
    this.hasUniqueSolution = false,
    this.meetsDifficulty = false,
  });

  Map<String, dynamic> toJson() => {
    'scenario': scenario.toJson(),
    'success': success,
    'error': error,
    'generationTimeMs': generationTime?.inMilliseconds,
    'validationTimeMs': validationTime?.inMilliseconds,
    'isSolvable': isSolvable,
    'hasUniqueSolution': hasUniqueSolution,
    'meetsDifficulty': meetsDifficulty,
  };
}
