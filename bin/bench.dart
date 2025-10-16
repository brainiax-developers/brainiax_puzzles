#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

/// Local/CI benchmark runner for puzzle engines.
/// 
/// This script runs selected engines N times and prints p95 performance metrics.
/// It's designed to be used in CI to detect performance regressions without
/// blocking release gates.
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('engines', 
        abbr: 'e', 
        help: 'Comma-separated list of engine IDs to benchmark',
        defaultsTo: 'stub,stub_sudoku')
    ..addOption('count', 
        abbr: 'c', 
        help: 'Number of iterations per engine',
        defaultsTo: '100')
    ..addOption('difficulty', 
        abbr: 'd', 
        help: 'Difficulty level (easy, medium, hard)',
        defaultsTo: 'medium')
    ..addOption('size', 
        abbr: 's', 
        help: 'Puzzle size (e.g., 9x9, 6x6)',
        defaultsTo: '9x9')
    ..addOption('output', 
        abbr: 'o', 
        help: 'Output file for results (JSON format)',
        defaultsTo: 'benchmark_results.json')
    ..addOption('baseline', 
        abbr: 'b', 
        help: 'Baseline file to compare against')
    ..addFlag('ci', 
        help: 'Run in CI mode (exit with error code on regression)')
    ..addOption('threshold', 
        help: 'Regression threshold percentage (default: 20)',
        defaultsTo: '20')
    ..addFlag('help', abbr: 'h', help: 'Show this help message');

  final results = parser.parse(arguments);
  
  if (results['help'] as bool) {
    print('Puzzle Engine Benchmark Runner');
    print('');
    print('Usage: dart bin/bench.dart [options]');
    print('');
    print(parser.usage);
    exit(0);
  }

  final engines = (results['engines'] as String).split(',').map((e) => e.trim()).toList();
  final count = int.parse(results['count'] as String);
  final difficulty = results['difficulty'] as String;
  final size = results['size'] as String;
  final outputFile = results['output'] as String;
  final baselineFile = results['baseline'] as String?;
  final ciMode = results['ci'] as bool;
  final threshold = double.parse(results['threshold'] as String);

  print('🚀 Starting benchmark run...');
  print('Engines: ${engines.join(', ')}');
  print('Count: $count per engine');
  print('Difficulty: $difficulty');
  print('Size: $size');
  print('');

  try {
    // Run benchmarks
    final benchmarkResults = await _runBenchmarks(
      engines: engines,
      count: count,
      difficulty: difficulty,
      size: size,
    );

    // Save results
    await _saveResults(benchmarkResults, outputFile);
    print('📊 Results saved to $outputFile');

    // Save p95-only artifact for CI
    final p95File = outputFile.replaceAll('.json', '_p95.json');
    await _saveP95Artifact(benchmarkResults, p95File);
    print('📊 P95 artifact saved to $p95File');

    // Print summary
    _printSummary(benchmarkResults);

    // CI mode: compare with baseline
    if (ciMode && baselineFile != null) {
      final regression = await _checkRegression(benchmarkResults, baselineFile, threshold);
      if (regression.hasRegression) {
        print('❌ Performance regression detected!');
        print('Regression: ${regression.regressionPercent.toStringAsFixed(1)}%');
        print('Threshold: ${threshold}%');
        exit(1);
      } else {
        print('✅ No significant regression detected');
      }
    }

    print('✅ Benchmark completed successfully');
  } catch (e) {
    print('❌ Benchmark failed: $e');
    exit(1);
  }
}

/// Run benchmarks for the specified engines.
Future<Map<String, EngineBenchmarkResult>> _runBenchmarks({
  required List<String> engines,
  required int count,
  required String difficulty,
  required String size,
}) async {
  final results = <String, EngineBenchmarkResult>{};

  for (final engineId in engines) {
    print('🔧 Benchmarking $engineId...');
    
    try {
      final result = await _benchmarkEngine(
        engineId: engineId,
        count: count,
        difficulty: difficulty,
        size: size,
      );
      results[engineId] = result;
      
      print('  P95: ${result.p95Ms.toStringAsFixed(2)}ms');
      print('  P99: ${result.p99Ms.toStringAsFixed(2)}ms');
      print('  Total: ${result.totalTimeMs.toStringAsFixed(2)}ms');
    } catch (e) {
      print('  ❌ Failed: $e');
      results[engineId] = EngineBenchmarkResult(
        engineId: engineId,
        success: false,
        error: e.toString(),
        p95Ms: 0,
        p99Ms: 0,
        totalTimeMs: 0,
        iterations: 0,
      );
    }
    print('');
  }

  return results;
}

/// Benchmark a single engine using the standalone benchmark runner.
Future<EngineBenchmarkResult> _benchmarkEngine({
  required String engineId,
  required int count,
  required String difficulty,
  required String size,
}) async {
  final process = await Process.start(
    'dart',
    [
      'run',
      'packages/puzzle_core/bin/benchmark_runner.dart',
      engineId,
      count.toString(),
      difficulty,
      size,
    ],
  );

  final exitCode = await process.exitCode;
  final stdout = await process.stdout.transform(utf8.decoder).join();
  final stderr = await process.stderr.transform(utf8.decoder).join();

  if (exitCode != 0) {
    throw Exception('Benchmark runner failed: $stderr');
  }

  try {
    final json = jsonDecode(stdout);
    return EngineBenchmarkResult.fromJson(json);
  } catch (e) {
    throw Exception('Failed to parse benchmark result: $e');
  }
}

/// Calculate percentile from sorted list.
int _percentile(List<int> sortedList, double percentile) {
  if (sortedList.isEmpty) return 0;
  final index = (percentile * (sortedList.length - 1)).round();
  return sortedList[index.clamp(0, sortedList.length - 1)];
}

/// Save benchmark results to file.
Future<void> _saveResults(
  Map<String, EngineBenchmarkResult> results, 
  String outputFile,
) async {
  final json = {
    'timestamp': DateTime.now().toIso8601String(),
    'hostname': Platform.localHostname,
    'platform': Platform.operatingSystem,
    'dartVersion': Platform.version,
    'results': results.map((key, value) => MapEntry(key, value.toJson())),
    'summary': {
      'totalEngines': results.length,
      'successfulEngines': results.values.where((r) => r.success).length,
      'failedEngines': results.values.where((r) => !r.success).length,
      'averageP95Ms': results.values
          .where((r) => r.success)
          .map((r) => r.p95Ms)
          .fold(0.0, (a, b) => a + b) / results.values.where((r) => r.success).length,
    },
  };

  final file = File(outputFile);
  await file.writeAsString(jsonEncode(json));
}

/// Save p95-only artifact for CI consumption.
Future<void> _saveP95Artifact(
  Map<String, EngineBenchmarkResult> results, 
  String outputFile,
) async {
  final p95Data = <String, double>{};
  
  for (final entry in results.entries) {
    final engineId = entry.key;
    final result = entry.value;
    
    if (result.success) {
      p95Data[engineId] = result.p95Ms;
    }
  }

  final json = {
    'timestamp': DateTime.now().toIso8601String(),
    'hostname': Platform.localHostname,
    'platform': Platform.operatingSystem,
    'p95Ms': p95Data,
  };

  final file = File(outputFile);
  await file.writeAsString(jsonEncode(json));
}

/// Print summary of benchmark results.
void _printSummary(Map<String, EngineBenchmarkResult> results) {
  print('📈 Benchmark Summary');
  print('==================');
  
  for (final entry in results.entries) {
    final engineId = entry.key;
    final result = entry.value;
    
    if (result.success) {
      print('$engineId:');
      print('  P95: ${result.p95Ms.toStringAsFixed(2)}ms');
      print('  P99: ${result.p99Ms.toStringAsFixed(2)}ms');
      print('  Total: ${result.totalTimeMs.toStringAsFixed(2)}ms');
      print('  Iterations: ${result.iterations}');
    } else {
      print('$engineId: FAILED (${result.error})');
    }
  }
}

/// Check for performance regression against baseline.
Future<RegressionCheck> _checkRegression(
  Map<String, EngineBenchmarkResult> current,
  String baselineFile,
  double threshold,
) async {
  final baselineFileObj = File(baselineFile);
  if (!await baselineFileObj.exists()) {
    print('⚠️  Baseline file not found: $baselineFile');
    return RegressionCheck(hasRegression: false, regressionPercent: 0);
  }

  final baselineJson = jsonDecode(await baselineFileObj.readAsString());
  final baselineResults = (baselineJson['results'] as Map<String, dynamic>)
      .map((key, value) => MapEntry(key, EngineBenchmarkResult.fromJson(value)));

  double maxRegression = 0;
  bool hasRegression = false;

  for (final entry in current.entries) {
    final engineId = entry.key;
    final currentResult = entry.value;
    final baselineResult = baselineResults[engineId];

    if (baselineResult == null || !currentResult.success || !baselineResult.success) {
      continue;
    }

    final regression = ((currentResult.p95Ms - baselineResult.p95Ms) / baselineResult.p95Ms) * 100;
    maxRegression = max(maxRegression, regression);

    if (regression > threshold) {
      hasRegression = true;
      print('⚠️  Regression in $engineId: ${regression.toStringAsFixed(1)}%');
    }
  }

  return RegressionCheck(
    hasRegression: hasRegression,
    regressionPercent: maxRegression,
  );
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

/// Result of regression check.
class RegressionCheck {
  final bool hasRegression;
  final double regressionPercent;

  RegressionCheck({
    required this.hasRegression,
    required this.regressionPercent,
  });
}
