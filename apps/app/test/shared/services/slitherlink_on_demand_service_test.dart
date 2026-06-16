import 'package:app/shared/services/slitherlink_on_demand_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

void main() {
  group('SlitherlinkOnDemandService', () {
    final service = SlitherlinkOnDemandService();

    test(
      'produces deterministic on-demand puzzles for identical seeds',
      () async {
        const seed = 'slitherlink:on-demand:deterministic';

        final first = await service.nextPuzzle(
          difficulty: 'medium',
          width: 6,
          height: 6,
          seed: seed,
        );
        final second = await service.nextPuzzle(
          difficulty: 'medium',
          width: 6,
          height: 6,
          seed: seed,
        );

        expect(first.state.clues, equals(second.state.clues));
        expect(first.meta, equals(second.meta));
        expect(first.telemetry, equals(second.telemetry));
        expect(first.meta.seedStr, equals(seed));
        expect(first.meta.seed64, equals(core.Seed.fromString(seed)));
      },
    );

    test(
      'can produce different on-demand puzzles for different seeds',
      () async {
        final first = await service.nextPuzzle(
          difficulty: 'medium',
          width: 6,
          height: 6,
          seed: 'slitherlink:on-demand:seed:a',
        );
        final second = await service.nextPuzzle(
          difficulty: 'medium',
          width: 6,
          height: 6,
          seed: 'slitherlink:on-demand:seed:b',
        );

        expect(first.meta.seed64, isNot(equals(second.meta.seed64)));
        expect(first.state.clues, isNot(equals(second.state.clues)));
      },
    );
  });
}
