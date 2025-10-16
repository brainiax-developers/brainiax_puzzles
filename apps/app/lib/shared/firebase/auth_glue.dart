import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

Future<void> ensureAnonAuth() async {
  try {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      // Add timeout to prevent long waits
      await auth.signInAnonymously().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Firebase auth timeout', const Duration(seconds: 5));
        },
      );
      if (kDebugMode) {
        print('✅ Anonymous authentication successful');
      }
    } else {
      if (kDebugMode) {
        print('✅ User already authenticated: ${auth.currentUser?.uid}');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Firebase authentication failed: $e');
      print('📱 App will continue without authentication');
    }
    // Don't throw - let the app continue without authentication
    // This allows the app to work offline or when Firebase is unavailable
  }
}
