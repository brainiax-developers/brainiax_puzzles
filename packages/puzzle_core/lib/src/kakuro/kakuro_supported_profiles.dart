class KakuroProfile {
  const KakuroProfile({required this.sizeId, required this.difficulty});

  final String sizeId;
  final String difficulty;
}

enum KakuroProfileTier { shipping, benchmarkOnly, experimental }

enum KakuroAppProfileSurface { production, nonProduction }

/// Central policy for Kakuro profile exposure.
///
/// Shipping tier controls what production app surfaces by default.
/// Benchmark tier remains available for calibration runs.
/// Experimental tier remains available for R&D and local verification.
class KakuroSupportedProfiles {
  const KakuroSupportedProfiles._();

  static const List<KakuroProfile> shippingProfiles = <KakuroProfile>[
    KakuroProfile(sizeId: '7x9', difficulty: 'easy'),
    KakuroProfile(sizeId: '7x10', difficulty: 'medium'),
    KakuroProfile(sizeId: '8x11', difficulty: 'hard'),
    KakuroProfile(sizeId: '9x12', difficulty: 'expert'),
  ];

  // Bench calibration profiles that are not shown in production app UX.
  static const List<KakuroProfile> benchmarkOnlyProfiles = <KakuroProfile>[
    KakuroProfile(sizeId: '9x9', difficulty: 'medium'),
    KakuroProfile(sizeId: '9x9', difficulty: 'hard'),
    KakuroProfile(sizeId: '9x9', difficulty: 'expert'),
  ];

  // Experimental profiles are available for local verification only.
  static const List<KakuroProfile> experimentalProfiles = <KakuroProfile>[
    KakuroProfile(sizeId: '5x5', difficulty: 'easy'),
    KakuroProfile(sizeId: '5x5', difficulty: 'medium'),
    KakuroProfile(sizeId: '5x5', difficulty: 'hard'),
    KakuroProfile(sizeId: '5x5', difficulty: 'expert'),
    KakuroProfile(sizeId: '11x11', difficulty: 'expert'),
  ];

  // App UX exposes the fixed mobile portrait profiles.
  static const List<KakuroProfile> nonProductionAppProfiles = <KakuroProfile>[
    ...shippingProfiles,
  ];

  static const Set<String> _difficultyFallbackAllowedProfiles = <String>{
    // Temporary fallback is only allowed for early easy-profile bring-up.
    '7x9:easy',
  };

  static const Set<String> supportedDifficulties = <String>{
    'easy',
    'medium',
    'hard',
    'expert',
  };

  static const Set<String> supportedGeneratorSizeIds = <String>{
    '5x5',
    '7x9',
    '7x10',
    '8x11',
    '9x9',
    '9x12',
    '11x9',
    '11x11',
    '13x11',
  };

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

  static List<KakuroProfile> appProfilesForSurface(
    KakuroAppProfileSurface surface,
  ) {
    // App UI should expose the same Kakuro testable profiles across flavors.
    // Shipping/benchmark/experimental tiers still exist for benchmark reporting
    // and future Remote Config/product gating, but local app testing should not
    // silently hide Medium/Hard just because APP_FLAVOR resolves to prod.
    return nonProductionAppProfiles;
  }

  static bool isAppProfileAllowed({
    required String sizeId,
    required String difficulty,
    required KakuroAppProfileSurface surface,
  }) {
    final String normalizedDifficulty = normalizeDifficulty(difficulty);
    return _contains(
      appProfilesForSurface(surface),
      sizeId,
      normalizedDifficulty,
    );
  }

  static String appSizeForDifficulty({
    required String difficulty,
    required KakuroAppProfileSurface surface,
  }) {
    final String normalized = normalizeDifficulty(difficulty);
    final List<KakuroProfile> visibleProfiles = appProfilesForSurface(surface);
    for (final KakuroProfile profile in visibleProfiles) {
      if (profile.difficulty == normalized) {
        return profile.sizeId;
      }
    }
    return visibleProfiles.first.sizeId;
  }

  static String generatorSizeForDifficulty(String difficulty) {
    final String normalized = normalizeDifficulty(difficulty);
    for (final KakuroProfile profile in shippingProfiles) {
      if (profile.difficulty == normalized) {
        return profile.sizeId;
      }
    }
    return shippingProfiles.first.sizeId;
  }

  static List<String> appDifficultiesForSurface(
    KakuroAppProfileSurface surface,
  ) {
    return appProfilesForSurface(surface)
        .map((KakuroProfile profile) => profile.difficulty)
        .toSet()
        .toList(growable: false);
  }

  static List<String> appSizesForSurface(KakuroAppProfileSurface surface) {
    return appProfilesForSurface(surface)
        .map((KakuroProfile profile) => profile.sizeId)
        .toSet()
        .toList(growable: false);
  }

  static bool isDifficultySupported(String difficulty) {
    return supportedDifficulties.contains(normalizeDifficulty(difficulty));
  }

  static bool isGeneratorSizeSupported({
    required int width,
    required int height,
  }) {
    return supportedGeneratorSizeIds.contains('${width}x$height');
  }

  static bool isAdhocBenchmarkSupported({
    required int width,
    required int height,
    required String difficulty,
  }) {
    return isGeneratorSizeSupported(width: width, height: height) &&
        isDifficultySupported(difficulty);
  }

  static bool allowsDifficultyFallback({
    required String sizeId,
    required String difficulty,
  }) {
    final String normalizedDifficulty = normalizeDifficulty(difficulty);
    return _difficultyFallbackAllowedProfiles.contains(
      '$sizeId:$normalizedDifficulty',
    );
  }

  static String appDifficultyLabel({
    required String difficulty,
    required KakuroAppProfileSurface surface,
  }) {
    final String normalizedDifficulty = normalizeDifficulty(difficulty);
    return '${normalizedDifficulty[0].toUpperCase()}${normalizedDifficulty.substring(1)}';
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
