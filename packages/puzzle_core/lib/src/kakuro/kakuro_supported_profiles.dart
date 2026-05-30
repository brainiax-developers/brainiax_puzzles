class KakuroProfile {
  const KakuroProfile({
    required this.sizeId,
    required this.difficulty,
  });

  final String sizeId;
  final String difficulty;
}

enum KakuroProfileTier {
  shipping,
  benchmarkOnly,
  experimental,
}

/// Central policy for Kakuro profile exposure.
///
/// Shipping tier controls what production app surfaces by default.
/// Benchmark tier remains available for calibration runs.
/// Experimental tier remains available for R&D and local verification.
class KakuroSupportedProfiles {
  const KakuroSupportedProfiles._();

  static const List<KakuroProfile> shippingProfiles = <KakuroProfile>[
    KakuroProfile(sizeId: '7x7', difficulty: 'easy'),
  ];

  static const List<KakuroProfile> benchmarkOnlyProfiles = <KakuroProfile>[
    KakuroProfile(sizeId: '9x9', difficulty: 'medium'),
    KakuroProfile(sizeId: '9x9', difficulty: 'hard'),
    KakuroProfile(sizeId: '9x9', difficulty: 'expert'),
  ];

  static const List<KakuroProfile> experimentalProfiles = <KakuroProfile>[
    KakuroProfile(sizeId: '5x5', difficulty: 'easy'),
    KakuroProfile(sizeId: '5x5', difficulty: 'medium'),
    KakuroProfile(sizeId: '5x5', difficulty: 'hard'),
    KakuroProfile(sizeId: '5x5', difficulty: 'expert'),
    KakuroProfile(sizeId: '11x11', difficulty: 'expert'),
  ];

  static List<KakuroProfile> get benchmarkEligibleProfiles => <KakuroProfile>[
    ...shippingProfiles,
    ...benchmarkOnlyProfiles,
    ...experimentalProfiles,
  ];

  static String normalizeDifficulty(String difficulty) {
    return difficulty.trim().toLowerCase();
  }

  static KakuroProfileTier? tierFor({
    required String sizeId,
    required String difficulty,
  }) {
    final String normalizedDifficulty = normalizeDifficulty(difficulty);
    if (_contains(shippingProfiles, sizeId, normalizedDifficulty)) {
      return KakuroProfileTier.shipping;
    }
    if (_contains(benchmarkOnlyProfiles, sizeId, normalizedDifficulty)) {
      return KakuroProfileTier.benchmarkOnly;
    }
    if (_contains(experimentalProfiles, sizeId, normalizedDifficulty)) {
      return KakuroProfileTier.experimental;
    }
    return null;
  }

  static bool isShippingSafe({
    required String sizeId,
    required String difficulty,
  }) {
    return tierFor(sizeId: sizeId, difficulty: difficulty) ==
        KakuroProfileTier.shipping;
  }

  static bool isBenchmarkEligible({
    required String sizeId,
    required String difficulty,
  }) {
    return tierFor(sizeId: sizeId, difficulty: difficulty) != null;
  }

  static String shippingSizeForDifficulty(String difficulty) {
    final String normalized = normalizeDifficulty(difficulty);
    for (final KakuroProfile profile in shippingProfiles) {
      if (profile.difficulty == normalized) {
        return profile.sizeId;
      }
    }
    return shippingProfiles.first.sizeId;
  }

  static List<String> get shippingDifficulties => shippingProfiles
      .map((KakuroProfile profile) => profile.difficulty)
      .toSet()
      .toList(growable: false);

  static List<String> get shippingSizes => shippingProfiles
      .map((KakuroProfile profile) => profile.sizeId)
      .toSet()
      .toList(growable: false);

  static bool _contains(
    List<KakuroProfile> profiles,
    String sizeId,
    String difficulty,
  ) {
    for (final KakuroProfile profile in profiles) {
      if (profile.sizeId == sizeId && profile.difficulty == difficulty) {
        return true;
      }
    }
    return false;
  }
}
