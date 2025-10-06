import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../firebase_options.dart';

Future<void> initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Crashlytics
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Analytics
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(!kDebugMode);
}
