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
        expect(first.meta.seedStr, equals(seed));
        expect(first.meta.seed64, equals(core.Seed.fromString(seed)));
        expect(
          first.telemetry!.difficulty.rawScore,
          equals(second.telemetry!.difficulty.rawScore),
        );
        expect(
          first.telemetry!.difficulty.metrics['clueDensity'],
          equals(second.telemetry!.difficulty.metrics['clueDensity']),
        );
        expect(
          first.telemetry!.difficulty.metrics['loopEdgeCount'],
          equals(second.telemetry!.difficulty.metrics['loopEdgeCount']),
        );
        expect(first.telemetry!.difficulty.metrics, isNotEmpty);
        expect(
          first.telemetry!.difficulty.metrics.keys,
          containsAll(<String>[
            'clueDensity',
            'loopEdgeCount',
            'revealedZeroRatio',
          ]),
        );
        final generatorTelemetry = (first.telemetry!.extras['generator'] as Map)
            .cast<String, Object?>();
        final requestedProfile =
            (first.telemetry!.extras['requestedGenerationProfile'] as Map)
                .cast<String, Object?>();
        expect(generatorTelemetry['solverStatus'], equals('unique'));
        expect(generatorTelemetry['qualityGatePassed'], isTrue);
        expect(
          first.meta.difficulty.level,
          equals(first.telemetry!.difficulty.bucket),
        );
        expect(
          first.meta.difficulty.value,
          equals(first.telemetry!.difficulty.rawScore),
        );
        expect(requestedProfile['difficulty'], equals('medium'));
        expect(requestedProfile['size'], equals('6x6'));
        expect(requestedProfile['variant'], equals('classicLoop'));
        expect(first.telemetry!.extras['measuredDifficultyAvailable'], isTrue);
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
