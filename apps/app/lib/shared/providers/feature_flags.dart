// apps/app/lib/shared/providers/feature_flags.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeatureFlags {
  final bool showBannerAds;
  final bool rewardedAdsEnabled;
  final int hintCost;
  final int interstitialEveryNCompletions;

  const FeatureFlags({
    this.showBannerAds = false,
    this.rewardedAdsEnabled = false,
    this.hintCost = 1,
    this.interstitialEveryNCompletions = 0,
  });

  FeatureFlags copyWith({
    bool? showBannerAds,
    bool? rewardedAdsEnabled,
    int? hintCost,
    int? interstitialEveryNCompletions,
  }) {
    return FeatureFlags(
      showBannerAds: showBannerAds ?? this.showBannerAds,
      rewardedAdsEnabled: rewardedAdsEnabled ?? this.rewardedAdsEnabled,
      hintCost: hintCost ?? this.hintCost,
      interstitialEveryNCompletions:
          interstitialEveryNCompletions ?? this.interstitialEveryNCompletions,
    );
  }
}

/// Modern Riverpod v3 Notifier holding FeatureFlags state.
class FeatureFlagsNotifier extends Notifier<FeatureFlags> {
  @override
  FeatureFlags build() {
    // initial/default flags; you can later hydrate from Remote Config here
    return const FeatureFlags();
  }

  void setAll(FeatureFlags flags) => state = flags;

  // Example granular updaters (handy for Settings toggles)
  void setShowBannerAds(bool value) =>
      state = state.copyWith(showBannerAds: value);

  void setRewardedAdsEnabled(bool value) =>
      state = state.copyWith(rewardedAdsEnabled: value);

  void setHintCost(int value) => state = state.copyWith(hintCost: value);

  void setInterstitialEveryN(int value) =>
      state = state.copyWith(interstitialEveryNCompletions: value);
}

/// Expose as a NotifierProvider (modern API)
final featureFlagsProvider =
    NotifierProvider<FeatureFlagsNotifier, FeatureFlags>(FeatureFlagsNotifier.new);
