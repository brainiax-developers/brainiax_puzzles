import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:puzzle_core/puzzle_core.dart';

/// Standalone benchmark runner for puzzle engines.
/// 
/// This can be called from the main bench.dart script to run actual
/// puzzle engine benchmarks in a separate process.
void main(List<String> arguments) async {
  if (arguments.length < 4) {
    print('Usage: dart benchmark_runner.dart <engineId> <count> <difficulty> <size>');
    exit(1);
  }

  final engineId = arguments[0];
  final count = int.parse(arguments[1]);
  final difficulty = arguments[2];
  final size = arguments[3];

  try {
    // Initialize engines
    await _initializeEngines();
    
    // Run benchmark
    final result = await _benchmarkEngine(
      engineId: engineId,
      count: count,
      difficulty: difficulty,
      size: size,
    );

    // Output result as JSON
    print(jsonEncode(result.toJson()));
  } catch (e) {
    final errorResult = EngineBenchmarkResult(
      engineId: engineId,
      success: false,
      error: e.toString(),
      p95Ms: 0,
      p99Ms: 0,
      totalTimeMs: 0,
      iterations: 0,
    );
    print(jsonEncode(errorResult.toJson()));
    exit(1);
  }
}

/// Initialize all available engines.
Future<void> _initializeEngines() async {
  final registry = EngineRegistry();
  
  // Register stub engines
  registry.register(StubPuzzleEngine());
  registry.register(StubSudokuEngine());

  // Register real engines (with error handling)
  try {
    registry.register(SudokuEngine());
  } catch (e) {
    // Engine might not be available
  }

  try {
    registry.register(NonogramEngine());
  } catch (e) {
    // Engine might not be available
  }

  try {
    registry.register(KakuroEngine());
  } catch (e) {
    // Engine might not be available
  }

  try {
    registry.register(SlitherlinkEngine());
  } catch (e) {
    // Engine might not be available
  }

  try {
    registry.register(MathdokuEngine());
  } catch (e) {
    // Engine might not be available
  }

  try {
    registry.register(FutoshikiEngine());
  } catch (e) {
    // Engine might not be available
  }

  try {
    registry.register(TakuzuEngine());
  } catch (e) {
    // Engine might not be available
  }
}

/// Benchmark a single engine.
Future<EngineBenchmarkResult> _benchmarkEngine({
  required String engineId,
  required int count,
  required String difficulty,
  required String size,
}) async {
  final registry = EngineRegistry();
  final engine = registry.getEngine(engineId);
  
  if (engine == null) {
    throw Exception('Engine not found: $engineId');
  }

  // Parse size
  final sizeParts = size.split('x');
  if (sizeParts.length != 2) {
    throw Exception('Invalid size format: $size');
  }
  final width = int.parse(sizeParts[0]);
  final height = int.parse(sizeParts[1]);

  // Parse difficulty
  final difficultyScore = _parseDifficulty(difficulty);

  final times = <int>[];
  final totalStopwatch = Stopwatch()..start();

  for (int i = 0; i < count; i++) {
    final seedStr = 'bench:$engineId:$i';
    final seed64 = seedStr.hashCode;

    final stopwatch = Stopwatch()..start();
    
    try {
      final puzzle = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: SizeOpt(
          id: '${width}x$height',
          description: '${width}x$height',
          width: width,
          height: height,
        ),
        difficulty: difficultyScore,
      );
      
      // Basic validation
      if (puzzle.meta.engineVersion.isEmpty) {
        throw Exception('Invalid puzzle generated');
      }
    } catch (e) {
      throw Exception('Puzzle generation failed: $e');
    }
    
    stopwatch.stop();
    times.add(stopwatch.elapsedMicroseconds);
  }

  totalStopwatch.stop();

  // Calculate percentiles
  times.sort();
  final p95 = _percentile(times, 0.95);
  final p99 = _percentile(times, 0.99);

  return EngineBenchmarkResult(
    engineId: engineId,
    success: true,
    error: null,
    p95Ms: p95 / 1000.0,
    p99Ms: p99 / 1000.0,
    totalTimeMs: totalStopwatch.elapsedMicroseconds / 1000.0,
    iterations: count,
  );
}

/// Parse difficulty string to DifficultyScore.
DifficultyScore _parseDifficulty(String difficulty) {
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

/// Calculate percentile from sorted list.
int _percentile(List<int> sortedList, double percentile) {
  if (sortedList.isEmpty) return 0;
  final index = (percentile * (sortedList.length - 1)).round();
  return sortedList[index.clamp(0, sortedList.length - 1)];
}

/// Result of benchmarking a single engine.
class EngineBenchmarkResult {
  final String engineId;
  final bool success;
  final String? error;
  final double p95Ms;
  final double p99Ms;
  final double totalTimeMs;
  final int iterations;

  EngineBenchmarkResult({
    required this.engineId,
    required this.success,
    required this.error,
    required this.p95Ms,
    required this.p99Ms,
    required this.totalTimeMs,
    required this.iterations,
  });

  Map<String, dynamic> toJson() => {
    'engineId': engineId,
    'success': success,
    'error': error,
    'p95Ms': p95Ms,
    'p99Ms': p99Ms,
    'totalTimeMs': totalTimeMs,
    'iterations': iterations,
  };

  factory EngineBenchmarkResult.fromJson(Map<String, dynamic> json) =>
      EngineBenchmarkResult(
        engineId: json['engineId'] as String,
        success: json['success'] as bool,
        error: json['error'] as String?,
        p95Ms: (json['p95Ms'] as num).toDouble(),
        p99Ms: (json['p99Ms'] as num).toDouble(),
        totalTimeMs: (json['totalTimeMs'] as num).toDouble(),
        iterations: json['iterations'] as int,
      );
}
