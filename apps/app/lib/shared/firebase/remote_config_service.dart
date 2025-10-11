import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  final FirebaseRemoteConfig _rc;
  RemoteConfigService(this._rc);

  static Future<RemoteConfigService> init() async {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setDefaults({
      'show_banner_ads': false,
      'rewarded_ads_enabled': false,
      'hint_cost': 1,
      'interstitial_every_n_completions': 0,
    });
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 5),
      minimumFetchInterval: kDebugMode ? const Duration(minutes: 1) : const Duration(hours: 1),
    ));
    await rc.fetchAndActivate();
    return RemoteConfigService(rc);
  }

  bool get showBannerAds => _rc.getBool('show_banner_ads');
  bool get rewardedAdsEnabled => _rc.getBool('rewarded_ads_enabled');
  int get hintCost => _rc.getInt('hint_cost');
  int get interstitialEveryN => _rc.getInt('interstitial_every_n_completions');
}
