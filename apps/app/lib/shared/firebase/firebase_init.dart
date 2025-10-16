import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform, FlutterError;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../firebase_options.dart';

bool get _crashlyticsSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
     defaultTargetPlatform == TargetPlatform.iOS ||
     defaultTargetPlatform == TargetPlatform.macOS);

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

  // Crashlytics: ONLY on supported platforms
  if (_crashlyticsSupported) {
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
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
