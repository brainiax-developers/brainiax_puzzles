import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'slitherlink corpus scenario uses deterministic fixed seeds',
    () async {
      Future<Map<String, Object?>> runScenario() async {
        final ProcessResult result = await Process.run('dart', <String>[
          'run',
          'bin/benchmark_runner.dart',
          '--engine',
          'slitherlink_loop',
          '--slitherlink-scenario',
          '5x5_easy',
        ], runInShell: true);

        expect(result.exitCode, equals(0), reason: '${result.stderr}');
        return Map<String, Object?>.from(
          jsonDecode(result.stdout as String) as Map,
        );
      }

      final Map<String, Object?> first = await runScenario();
      final Map<String, Object?> second = await runScenario();

      final Map<String, Object?> firstExtras = Map<String, Object?>.from(
        first['extras'] as Map,
      );
      final Map<String, Object?> secondExtras = Map<String, Object?>.from(
        second['extras'] as Map,
      );
      final Map<String, Object?> firstScenarios = Map<String, Object?>.from(
        firstExtras['scenarios'] as Map,
      );
      final Map<String, Object?> secondScenarios = Map<String, Object?>.from(
        secondExtras['scenarios'] as Map,
      );
      final Map<String, Object?> firstScenario = Map<String, Object?>.from(
        firstScenarios['5x5_easy'] as Map,
      );
      final Map<String, Object?> secondScenario = Map<String, Object?>.from(
        secondScenarios['5x5_easy'] as Map,
      );
      final List<String> firstSeeds = List<String>.from(
        firstScenario['seedCorpus'] as List,
      );
      final List<String> secondSeeds = List<String>.from(
        secondScenario['seedCorpus'] as List,
      );
      final List<String> firstStatuses = _statuses(firstScenario);
      final List<String> secondStatuses = _statuses(secondScenario);

      expect(first['iterations'], equals(30));
      expect(second['iterations'], equals(30));
      expect(firstSeeds, equals(secondSeeds));
      expect(firstStatuses, equals(secondStatuses));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

List<String> _statuses(Map<String, Object?> scenario) {
  final Map<String, Object?> extras = Map<String, Object?>.from(
    scenario['extras'] as Map,
  );
  final List<Object?> details = List<Object?>.from(
    extras['iterationDetails'] as List? ?? const <Object?>[],
  );
  return details
      .map((Object? detail) => Map<String, Object?>.from(detail as Map))
      .map((Map<String, Object?> detail) => detail['status'].toString())
      .toList(growable: false);
}
