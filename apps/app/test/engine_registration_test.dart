// filepath: apps/app/test/engine_registration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart';

import '../lib/shared/services/engine_registry_service.dart';

void main() {
  group('Engine registration', () {
    test('sudoku_classic engine is registered', () async {
      // Ensure engines are initialized (idempotent)
      await EngineRegistryService().initialize();

      final registry = EngineRegistry();
      final hasSudoku = registry.hasEngine('sudoku_classic');

      expect(hasSudoku, isTrue, reason: 'Expected "sudoku_classic" engine to be registered');
    }, timeout: Timeout(Duration(seconds: 10)));
  });
}

