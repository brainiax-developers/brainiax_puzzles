import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'crash_reporting_service.dart';

final crashReportingServiceProvider = Provider<CrashReportingService>((ref) {
  if (!_isCrashlyticsSupportedPlatform || Firebase.apps.isEmpty) {
    return const NoopCrashReportingService();
  }

  try {
    return FirebaseCrashReportingService(
      FirebaseCrashlyticsClient(FirebaseCrashlytics.instance),
    );
  } catch (_) {
    return const NoopCrashReportingService();
  }
});

bool get _isCrashlyticsSupportedPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

class FirebaseCrashlyticsClient implements CrashlyticsClient {
  const FirebaseCrashlyticsClient(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> recordError(
    Object exception,
    StackTrace stack, {
    String? reason,
    Iterable<Object> information = const <Object>[],
    bool fatal = false,
  }) {
    return _crashlytics.recordError(
      exception,
      stack,
      reason: reason,
      information: information,
      fatal: fatal,
    );
  }
}
