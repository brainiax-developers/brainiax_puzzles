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
}

final featureFlagsProvider = StateProvider<FeatureFlags>((_) => const FeatureFlags());
