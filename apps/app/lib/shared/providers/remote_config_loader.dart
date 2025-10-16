import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../firebase/remote_config_service.dart';
import 'feature_flags.dart';

final remoteConfigLoaderProvider = FutureProvider<void>((ref) async {
  final rc = await RemoteConfigService.init();
  ref.read(featureFlagsProvider.notifier).setAll(
    FeatureFlags(
      showBannerAds: rc.showBannerAds,
      rewardedAdsEnabled: rc.rewardedAdsEnabled,
      hintCost: rc.hintCost,
      interstitialEveryNCompletions: rc.interstitialEveryN,
    ),
  );
});
