import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'killer queens benchmark emits generation percentiles and solver metrics',
    () async {
      final ProcessResult result = await Process.run('dart', <String>[
        'run',
        'bin/benchmark_runner.dart',
        '--engine',
        'killer_queens',
        '--count',
        '2',
        '--difficulty',
        'easy',
        '--size',
        '6x6',
        '--iteration-cap-ms',
        '8000',
      ], runInShell: true);

      expect(result.exitCode, equals(0), reason: '${result.stderr}');
      final Map<String, Object?> json = Map<String, Object?>.from(
        jsonDecode(result.stdout as String) as Map,
      );
      final Map<String, Object?> extras = Map<String, Object?>.from(
        json['extras'] as Map,
      );
      final Map<String, Object?> metrics = Map<String, Object?>.from(
        extras['killerQueensMetrics'] as Map,
      );
      final Map<String, Object?> generationMs = Map<String, Object?>.from(
        metrics['generationMs'] as Map,
      );
      final Map<String, Object?> solverMetrics = Map<String, Object?>.from(
        metrics['solverMetrics'] as Map,
      );
      final Map<String, Object?> nodes = Map<String, Object?>.from(
        solverMetrics['nodes'] as Map,
      );
      final Map<String, Object?> backtracks = Map<String, Object?>.from(
        solverMetrics['backtracks'] as Map,
      );
      final Map<String, Object?> elapsedMs = Map<String, Object?>.from(
        solverMetrics['elapsedMs'] as Map,
      );
      final Map<String, Object?> acceptedAttempts = Map<String, Object?>.from(
        metrics['acceptedGenerationAttempts'] as Map,
      );

      expect(json['engineId'], equals('killer_queens'));
      expect(json['success'], isTrue);
      expect(json['p50Ms'], isA<num>());
      expect(json['p95Ms'], isA<num>());
      expect(json['p99Ms'], isA<num>());
      expect(generationMs.keys, containsAll(<String>['p50', 'p95', 'p99']));
      expect(metrics['multiSolutionCount'], equals(0));
      expect(metrics['unknownCount'], equals(0));
      expect(metrics['noSolutionCount'], equals(0));
      expect(acceptedAttempts['count'], equals(2));
      expect(nodes['count'], equals(2));
      expect(backtracks['count'], equals(2));
      expect(elapsedMs['count'], equals(2));

      final List<Object?> details = List<Object?>.from(
        extras['iterationDetails'] as List,
      );
      for (final Object? detail in details) {
        final Map<String, Object?> iteration = Map<String, Object?>.from(
          detail as Map,
        );
        expect(iteration['acceptedGenerationAttempts'], isA<num>());
        expect(iteration['elapsedMs'], isA<num>());
        expect(iteration['attempts'], isA<num>());
        expect(iteration['rejectedMultiple'], isA<num>());
        expect(iteration['rejectedUnknown'], isA<num>());
        expect(iteration['solverNodes'], isA<num>());
        expect(iteration['solverBacktracks'], isA<num>());
        expect(iteration['solverElapsedMs'], isA<num>());
        expect(iteration['status'], equals('success'));
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'killer queens benchmark can report every app difficulty profile',
    () async {
      final ProcessResult result = await Process.run('dart', <String>[
        'run',
        'bin/benchmark_runner.dart',
        '--engine',
        'killer_queens',
        '--count',
        '1',
        '--difficulty',
        'all',
        '--size',
        'app',
        '--iteration-cap-ms',
        '8000',
      ], runInShell: true);

      expect(result.exitCode, equals(0), reason: '${result.stderr}');
      final Map<String, Object?> json = Map<String, Object?>.from(
        jsonDecode(result.stdout as String) as Map,
      );
      final Map<String, Object?> extras = Map<String, Object?>.from(
        json['extras'] as Map,
      );
      final Map<String, Object?> difficultyResults = Map<String, Object?>.from(
        extras['difficultyResults'] as Map,
      );
      final Map<String, Object?> generationMs = Map<String, Object?>.from(
        extras['generationMs'] as Map,
      );

      expect(json['success'], isTrue);
      expect(json['p50Ms'], isA<num>());
      expect(json['p95Ms'], isA<num>());
      expect(json['p99Ms'], isA<num>());
      expect(generationMs.keys, containsAll(<String>['p50', 'p95', 'p99']));
      expect(
        difficultyResults.keys,
        containsAll(<String>['easy', 'medium', 'hard', 'expert']),
      );

      for (final String difficulty in <String>[
        'easy',
        'medium',
        'hard',
        'expert',
      ]) {
        final Map<String, Object?> resultJson = Map<String, Object?>.from(
          difficultyResults[difficulty] as Map,
        );
        expect(resultJson['p50Ms'], isA<num>(), reason: difficulty);
        expect(resultJson['p95Ms'], isA<num>(), reason: difficulty);
        expect(resultJson['p99Ms'], isA<num>(), reason: difficulty);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
