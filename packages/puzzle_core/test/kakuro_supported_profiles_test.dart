import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

void main() {
  group('KakuroSupportedProfiles', () {
    test('marks fixed portrait profiles as shipping-safe', () {
      expect(
        KakuroSupportedProfiles.isShippingSafe(
          sizeId: '7x9',
          difficulty: 'easy',
        ),
        isTrue,
      );
      expect(
        KakuroSupportedProfiles.isShippingSafe(
          sizeId: '7x10',
          difficulty: 'medium',
        ),
        isTrue,
      );
      expect(
        KakuroSupportedProfiles.isShippingSafe(
          sizeId: '8x11',
          difficulty: 'hard',
        ),
        isTrue,
      );
      expect(
        KakuroSupportedProfiles.isShippingSafe(
          sizeId: '9x12',
          difficulty: 'expert',
        ),
        isTrue,
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

    test('app surface exposes fixed portrait profile sizes by difficulty', () {
      final List<String> difficulties =
          KakuroSupportedProfiles.appDifficultiesForSurface(
            KakuroAppProfileSurface.nonProduction,
          );
      expect(difficulties, <String>['easy', 'medium', 'hard', 'expert']);
      expect(
        KakuroSupportedProfiles.appSizesForSurface(
          KakuroAppProfileSurface.nonProduction,
        ),
        <String>['7x9', '7x10', '8x11', '9x12'],
      );

      expect(
        KakuroSupportedProfiles.isAppProfileAllowed(
          sizeId: '7x10',
          difficulty: 'medium',
          surface: KakuroAppProfileSurface.nonProduction,
        ),
        isTrue,
      );
      expect(
        KakuroSupportedProfiles.isAppProfileAllowed(
          sizeId: '9x9',
          difficulty: 'expert',
          surface: KakuroAppProfileSurface.nonProduction,
        ),
        isFalse,
      );
    });

    test('supports exact rectangular profiles for generation', () {
      expect(
        KakuroSupportedProfiles.isGeneratorSizeSupported(width: 7, height: 9),
        isTrue,
      );
      expect(
        KakuroSupportedProfiles.isGeneratorSizeSupported(width: 7, height: 10),
        isTrue,
      );
      expect(
        KakuroSupportedProfiles.isGeneratorSizeSupported(width: 8, height: 11),
        isTrue,
      );
      expect(
        KakuroSupportedProfiles.isGeneratorSizeSupported(width: 9, height: 12),
        isTrue,
      );
      expect(
        KakuroSupportedProfiles.isGeneratorSizeSupported(width: 9, height: 9),
        isTrue,
      );
      expect(
        KakuroSupportedProfiles.isGeneratorSizeSupported(width: 13, height: 11),
        isTrue,
      );
      expect(
        KakuroSupportedProfiles.isGeneratorSizeSupported(width: 9, height: 7),
        isFalse,
      );
    });

    test('does not allow generated difficulty fallback', () {
      for (final profile in KakuroSupportedProfiles.shippingProfiles) {
        expect(
          KakuroSupportedProfiles.allowsDifficultyFallback(
            sizeId: profile.sizeId,
            difficulty: profile.difficulty,
          ),
          isFalse,
        );
      }
    });
  });
}
