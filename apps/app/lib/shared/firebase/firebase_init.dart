import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform, FlutterError;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../firebase_options.dart';

bool get _crashlyticsSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
     defaultTargetPlatform == TargetPlatform.iOS ||
     defaultTargetPlatform == TargetPlatform.macOS);

// Compile-time flavor (set via --dart-define=APP_FLAVOR=dev|staging|prod)
const String _appFlavor = String.fromEnvironment('APP_FLAVOR', defaultValue: 'dev');

bool get _enableAnalytics =>
  !kDebugMode && (_appFlavor == 'staging' || _appFlavor == 'prod');

bool get _enableCrashlytics =>
  _crashlyticsSupported &&
  (_appFlavor == 'dev' || _appFlavor == 'staging' || _appFlavor == 'prod');

Future<void> initFirebase() async {
  try {
    // Add timeout to prevent long waits during initialization
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        throw TimeoutException('Firebase init timeout', const Duration(seconds: 3));
      },
    );
    if (kDebugMode) {
      print('✅ Firebase initialized successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Firebase initialization failed: $e');
      print('📱 App will continue without Firebase services');
    }
    // Don't throw - let the app continue without Firebase
    return;
  }

  // Analytics: enable collection only for staging/prod (non-debug)
  if (_enableAnalytics) {
    try {
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(true);
      if (kDebugMode) {
        print('✅ Firebase Analytics initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Firebase Analytics initialization failed: $e');
      }
      // Analytics failures should not block app startup
    }
  } else if (kDebugMode) {
    print('ℹ️ Firebase Analytics disabled for this flavor / build type');
  }

  // Crashlytics: enabled on supported platforms for dev/staging/prod flavors
  if (_enableCrashlytics) {
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(true);
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      if (kDebugMode) {
        print('✅ Firebase Crashlytics initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Firebase Crashlytics initialization failed: $e');
      }
      // Don't let Crashlytics init block first frame
    }
  }
}
