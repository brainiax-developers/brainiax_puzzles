import 'package:app/shared/services/kakuro_on_demand_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

void main() {
  test('exhausts maxAttempts with a typed GenerationFailure', () async {
    final requests = <core.GenerateKakuroRequest>[];
    final service = KakuroOnDemandService(
      runGenerator: (request) {
        requests.add(request);
        throw StateError('forced failure');
      },
    );

    await expectLater(
      service.nextPuzzle(
        difficulty: 'easy',
        width: 7,
        height: 9,
        seed: 123,
        maxAttempts: 3,
        timeBudget: const Duration(seconds: 1),
      ),
      throwsA(
        isA<core.GenerationFailure>()
            .having((failure) => failure.attempts, 'attempts', 3)
            .having((failure) => failure.baseSeed, 'baseSeed', 123)
            .having(
              (failure) => failure.context['difficulty'],
              'difficulty',
              'easy',
            ),
      ),
    );

    expect(requests, hasLength(3));
    expect(
      requests.map((request) => request.strategy).toSet(),
      equals({core.KakuroGenerationStrategy.solutionFirst}),
    );
  });

  test('stops when wall-time budget is exhausted', () async {
    final requests = <core.GenerateKakuroRequest>[];
    final service = KakuroOnDemandService(
      runGenerator: (request) async {
        requests.add(request);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        throw StateError('slow failure');
      },
    );
    final watch = Stopwatch()..start();

    await expectLater(
      service.nextPuzzle(
        difficulty: 'easy',
        width: 7,
        height: 9,
        seed: 123,
        maxAttempts: 5,
        timeBudget: const Duration(milliseconds: 10),
      ),
      throwsA(
        isA<core.GenerationFailure>().having(
          (failure) => failure.attempts,
          'attempts',
          1,
        ),
      ),
    );

    watch.stop();
    expect(requests, hasLength(1));
    expect(watch.elapsedMilliseconds, lessThan(500));
  });
}
