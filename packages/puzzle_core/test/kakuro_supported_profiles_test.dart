import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart';

void main() {
  group('KakuroSupportedProfiles', () {
    test('marks only 7x7 easy as shipping-safe', () {
      expect(
        KakuroSupportedProfiles.isShippingSafe(
          sizeId: '7x7',
          difficulty: 'easy',
        ),
        isTrue,
      );
      expect(
        KakuroSupportedProfiles.isShippingSafe(
          sizeId: '9x9',
          difficulty: 'medium',
        ),
        isFalse,
      );
      expect(
        KakuroSupportedProfiles.isShippingSafe(
          sizeId: '5x5',
          difficulty: 'easy',
        ),
        isFalse,
      );
    });

    test('keeps 9x9 medium/hard/expert benchmark-eligible', () {
      expect(
        KakuroSupportedProfiles.tierFor(sizeId: '9x9', difficulty: 'medium'),
        KakuroProfileTier.benchmarkOnly,
      );
      expect(
        KakuroSupportedProfiles.tierFor(sizeId: '9x9', difficulty: 'hard'),
        KakuroProfileTier.benchmarkOnly,
      );
      expect(
        KakuroSupportedProfiles.tierFor(sizeId: '9x9', difficulty: 'expert'),
        KakuroProfileTier.benchmarkOnly,
      );
    });

    test('keeps experimental profiles benchmark-eligible', () {
      expect(
        KakuroSupportedProfiles.isBenchmarkEligible(
          sizeId: '5x5',
          difficulty: 'expert',
        ),
        isTrue,
      );
      expect(
        KakuroSupportedProfiles.isBenchmarkEligible(
          sizeId: '11x11',
          difficulty: 'expert',
        ),
        isTrue,
      );
    });
  });
}
