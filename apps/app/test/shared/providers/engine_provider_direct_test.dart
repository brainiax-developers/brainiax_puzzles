import 'package:app/shared/providers/engine_provider.dart';
import 'package:app/shared/services/engine_registry_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

void main() {
  setUp(() {
    core.EngineRegistry().clear();
  });

  tearDown(() {
    core.EngineRegistry().clear();
  });

  test('engine providers expose registered engines and info records', () {
    final engine = core.StubPuzzleEngine(
      engineId: 'stub-direct',
      engineName: 'Stub Direct',
    );
    core.EngineRegistry().register(engine);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(engineProvider('stub-direct')), same(engine));
    expect(container.read(engineProvider('missing')), isNull);
    expect(container.read(availableEnginesProvider), contains('stub-direct'));
    expect(container.read(isEngineAvailableProvider('stub-direct')), isTrue);
    expect(container.read(isEngineAvailableProvider('missing')), isFalse);
    expect(container.read(engineCountProvider), 1);
    expect(container.read(allEnginesProvider), <core.PuzzleEngine>[engine]);
    expect(
      container.read(engineInfoProvider('stub-direct')),
      const EngineInfo(
        id: 'stub-direct',
        name: 'Stub Direct',
        version: '2.0.0',
      ),
    );
    expect(container.read(engineInfoProvider('missing')), isNull);
    expect(container.read(allEngineInfoProvider), const <EngineInfo>[
      EngineInfo(id: 'stub-direct', name: 'Stub Direct', version: '2.0.0'),
    ]);
    expect(
      const EngineInfo(
        id: 'stub-direct',
        name: 'Stub Direct',
        version: '2.0.0',
      ).toString(),
      'EngineInfo(id: stub-direct, name: Stub Direct, version: 2.0.0)',
    );
  });

  test(
    'engine registry service initializes active V1 engines including Kakuro',
    () async {
      final service = EngineRegistryService();

      await service.initialize();

      expect(service.isEngineAvailable('kakuro'), isTrue);
      expect(
        service.getAvailableEngines(),
        containsAll(<String>[
          'sudoku_classic',
          'nonogram_mono',
          'kakuro',
          'slitherlink_loop',
          'mathdoku_classic',
          'killer_queens',
          'takuzu_binary',
        ]),
      );

      await service.initialize();
      expect(service.isEngineAvailable('kakuro'), isTrue);
    },
  );
}
