import 'package:app/shared/services/seed_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates and parses every supported seed shape', () {
    final service = SeedService();

    final daily = service.generateDailySeed(
      'kakuro',
      DateTime.utc(2026, 7, 1, 22),
    );
    expect(daily, 'kakuro:20260701');
    expect(
      service.getDailySeedForDate('kakuro', DateTime.utc(2026, 7, 2)),
      'kakuro:20260702',
    );
    expect(service.isDailySeed(daily), isTrue);
    expect(service.extractDateFromDailySeed(daily), DateTime.utc(2026, 7, 1));

    final randomPlay = service.generateRandomPlaySeed(
      'sudoku_classic',
      'user-1',
      'session-1',
    );
    expect(randomPlay, 'sudoku_classic:user-1:session-1');
    expect(service.isRandomPlaySeed(randomPlay), isTrue);

    final testSeed = service.generateTestSeed('takuzu_binary', 12);
    expect(testSeed, 'test:takuzu_binary:12');
    expect(service.parseSeed(testSeed).testIndex, 12);
    expect(service.isTestSeed(testSeed), isTrue);

    final randomSeed = service.generateRandomSeed('nonogram_mono');
    final randomComponents = service.parseSeed(randomSeed);
    expect(randomComponents.type, SeedType.random);
    expect(randomComponents.puzzleId, 'nonogram_mono');
    expect(randomComponents.timestamp, isNotNull);
    expect(randomComponents.random, isNotNull);
    expect(service.isRandomSeed(randomSeed), isTrue);

    expect(service.extractPuzzleId(randomPlay), 'sudoku_classic');
    expect(service.generateSessionNonce(), startsWith('session_'));
    expect(service.generateUserId(), startsWith('user_'));
    expect(
      service.getTodaysDailySeed('mathdoku_classic'),
      startsWith('mathdoku_classic:'),
    );
  });

  test(
    'invalid seed shapes fail validation and safe extractors return null',
    () {
      final service = SeedService();

      for (final seed in <String>[
        '',
        'test:only-two',
        'random:too:few',
        'a:b:c:d:e',
      ]) {
        expect(service.isValidSeed(seed), isFalse);
        expect(service.extractPuzzleId(seed), isNull);
      }

      expect(() => service.parseSeed(''), throwsArgumentError);
      expect(() => service.parseSeed('test:only-two'), throwsArgumentError);
      expect(() => service.parseSeed('random:too:few'), throwsArgumentError);
      expect(service.extractDateFromDailySeed('kakuro:not-a-date'), isNull);
      expect(service.extractDateFromDailySeed('kakuro:202607'), isNull);
      expect(service.isDailySeed('invalid'), isFalse);
      expect(service.isRandomPlaySeed('invalid'), isFalse);
      expect(service.isTestSeed('invalid'), isFalse);
      expect(service.isRandomSeed('invalid'), isFalse);
    },
  );

  test('parsed components expose readable debugging text', () {
    const components = SeedComponents(
      type: SeedType.daily,
      puzzleId: 'kakuro',
      dateStr: '20260701',
    );

    expect(
      components.toString(),
      'SeedComponents(type: SeedType.daily, puzzleId: kakuro)',
    );
  });
}
