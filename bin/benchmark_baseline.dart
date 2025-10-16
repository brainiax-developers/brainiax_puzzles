#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';

/// Utility script for managing benchmark baselines.
void main(List<String> arguments) async {
  if (arguments.isEmpty || arguments[0] == '--help' || arguments[0] == '-h') {
    print('Benchmark Baseline Manager');
    print('');
    print('Usage: dart bin/benchmark_baseline.dart <command> [options]');
    print('');
    print('Commands:');
    print('  set <file>                    Set a benchmark results file as the baseline');
    print('  get [output_file]             Get the current baseline');
    print('  compare <current> [baseline] [threshold]  Compare current results with baseline');
    print('');
    print('Examples:');
    print('  dart bin/benchmark_baseline.dart set benchmark_results.json');
    print('  dart bin/benchmark_baseline.dart get');
    print('  dart bin/benchmark_baseline.dart compare current.json baseline.json 20');
    exit(0);
  }

  final command = arguments[0];
  
  switch (command) {
    case 'set':
      if (arguments.length < 2) {
        print('❌ Error: set command requires a file argument');
        exit(1);
      }
      await _setBaseline(arguments[1]);
      break;
    case 'get':
      final outputFile = arguments.length > 1 ? arguments[1] : null;
      await _getBaseline(outputFile);
      break;
    case 'compare':
      if (arguments.length < 2) {
        print('❌ Error: compare command requires a current results file');
        exit(1);
      }
      final currentFile = arguments[1];
      final baselineFile = arguments.length > 2 ? arguments[2] : null;
      final threshold = arguments.length > 3 ? double.parse(arguments[3]) : 20.0;
      await _compareResults(currentFile, baselineFile, threshold);
      break;
    default:
      print('❌ Error: Unknown command "$command"');
      print('Run with --help for usage information');
      exit(1);
  }
}

/// Set a benchmark results file as the baseline.
Future<void> _setBaseline(String file) async {
  final sourceFile = File(file);
  if (!await sourceFile.exists()) {
    print('❌ File not found: $file');
    exit(1);
  }

  final baselineFile = File('benchmark_baseline.json');
  await sourceFile.copy(baselineFile.path);
  
  print('✅ Baseline set from $file');
  
  // Show summary
  final json = jsonDecode(await baselineFile.readAsString());
  print('\n📊 Baseline Summary:');
  _printResults(json);
}

/// Get the current baseline.
Future<void> _getBaseline(String? outputFile) async {
  final baselineFile = File('benchmark_baseline.json');
  if (!await baselineFile.exists()) {
    print('❌ No baseline found. Run "dart bin/benchmark_baseline.dart set" first.');
    exit(1);
  }

  if (outputFile != null) {
    final output = File(outputFile);
    await baselineFile.copy(output.path);
    print('✅ Baseline copied to $outputFile');
  } else {
    print('📊 Current Baseline:');
    final json = jsonDecode(await baselineFile.readAsString());
    _printResults(json);
  }
}

/// Compare current results with baseline.
Future<void> _compareResults(String currentFile, String? baselineFile, double threshold) async {
  final current = File(currentFile);
  final baseline = File(baselineFile ?? 'benchmark_baseline.json');
  
  if (!await current.exists()) {
    print('❌ Current results file not found: $currentFile');
    exit(1);
  }
  
  if (!await baseline.exists()) {
    print('❌ Baseline file not found: ${baseline.path}');
    exit(1);
  }

  final currentJson = jsonDecode(await current.readAsString());
  final baselineJson = jsonDecode(await baseline.readAsString());

  print('📊 Performance Comparison');
  print('========================');
  print('Threshold: ${threshold}% regression');
  print('');

  bool hasRegression = false;
  double maxRegression = 0;

  print('| Engine | Current P95 | Baseline P95 | Change | Status |');
  print('|--------|-------------|--------------|--------|--------|');

  for (final entry in (currentJson['results'] as Map<String, dynamic>).entries) {
    final engineId = entry.key;
    final currentResult = entry.value;
    final baselineResult = baselineJson['results']?[engineId];

    if (baselineResult == null) {
      print('| $engineId | ${currentResult['p95Ms']?.toStringAsFixed(2) ?? 'N/A'}ms | N/A | N/A | 🆕 New |');
      continue;
    }

    if (!currentResult['success'] || !baselineResult['success']) {
      print('| $engineId | ${currentResult['success'] ? '✅' : '❌'} | ${baselineResult['success'] ? '✅' : '❌'} | N/A | ⚠️  Error |');
      continue;
    }

    final currentP95 = currentResult['p95Ms'] as double;
    final baselineP95 = baselineResult['p95Ms'] as double;
    final change = ((currentP95 - baselineP95) / baselineP95) * 100;
    
    maxRegression = maxRegression > change ? maxRegression : change;
    
    String status;
    if (change > threshold) {
      status = '🔴 Regression';
      hasRegression = true;
    } else if (change > threshold / 2) {
      status = '🟡 Warning';
    } else {
      status = '🟢 Good';
    }

    final changeText = change > 0 ? '+${change.toStringAsFixed(1)}%' : '${change.toStringAsFixed(1)}%';
    print('| $engineId | ${currentP95.toStringAsFixed(2)}ms | ${baselineP95.toStringAsFixed(2)}ms | $changeText | $status |');
  }

  print('');
  if (hasRegression) {
    print('❌ Performance regression detected!');
    print('Maximum regression: ${maxRegression.toStringAsFixed(1)}%');
    exit(1);
  } else {
    print('✅ No significant regression detected');
  }
}

/// Print benchmark results summary.
void _printResults(Map<String, dynamic> json) {
  final results = json['results'] as Map<String, dynamic>;
  
  print('| Engine | P95 | P99 | Total Time | Iterations |');
  print('|--------|-----|-----|------------|------------|');
  
  for (final entry in results.entries) {
    final engineId = entry.key;
    final result = entry.value;
    
    if (result['success'] == true) {
      print('| $engineId | ${result['p95Ms'].toStringAsFixed(2)}ms | ${result['p99Ms'].toStringAsFixed(2)}ms | ${result['totalTimeMs'].toStringAsFixed(2)}ms | ${result['iterations']} |');
    } else {
      print('| $engineId | ❌ Failed | - | - | - |');
    }
  }
}
