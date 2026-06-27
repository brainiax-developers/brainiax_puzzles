import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_service.dart';

final firebaseAnalyticsProvider = Provider<FirebaseAnalytics?>((ref) {
  if (Firebase.apps.isEmpty) {
    return null;
  }

  try {
    return FirebaseAnalytics.instance;
  } catch (_) {
    return null;
  }
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final FirebaseAnalytics? analytics = ref.watch(firebaseAnalyticsProvider);
  if (analytics == null) {
    return const NoopAnalyticsService();
  }
  return FirebaseAnalyticsService(analytics: analytics);
});
