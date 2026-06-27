import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_sign_in;

import '../analytics/analytics_providers.dart';
import 'auth_repository.dart';
import 'auth_state.dart';
import 'user_identity.dart';

const Duration authBootstrapTimeout = Duration(seconds: 5);

final googleSignInClientProvider = Provider<GoogleSignInClient>((ref) {
  return GoogleSignInPluginClient(google_sign_in.GoogleSignIn.instance);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Firebase.apps.isEmpty) {
    return const UnavailableAuthRepository(
      'Firebase is not initialized; anonymous authentication is unavailable.',
    );
  }

  try {
    return FirebaseAuthRepository(
      firebase_auth.FirebaseAuth.instance,
      googleSignInClient: ref.watch(googleSignInClientProvider),
      analyticsService: ref.watch(analyticsServiceProvider),
    );
  } catch (error) {
    return UnavailableAuthRepository('FirebaseAuth is unavailable: $error');
  }
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges();
});

final currentUserIdentityProvider = Provider<UserIdentity?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final authStateAsync = ref.watch(authStateProvider);

  return authStateAsync.maybeWhen(
    data: (authState) => authState.identity,
    orElse: () => repository.currentAuthState.identity,
  );
});

final authBootstrapControllerProvider =
    AsyncNotifierProvider<AuthBootstrapController, void>(
      AuthBootstrapController.new,
    );

class AuthBootstrapController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> bootstrapAnonymousSignIn({
    Duration timeout = authBootstrapTimeout,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    if (repository.currentAuthState.isAuthenticated) {
      state = const AsyncData(null);
      return;
    }

    state = const AsyncLoading();
    await _trackAnalytics(
      () => ref.read(analyticsServiceProvider).authAnonymousBootstrapStarted(),
    );

    try {
      final authState = await repository.signInAnonymously(timeout: timeout);
      if (kDebugMode) {
        if (authState.isAnonymous) {
          debugPrint(
            'Anonymous authentication ready for ${authState.identity?.uid}.',
          );
        } else {
          debugPrint(
            'Authentication bootstrap completed without an anonymous user.',
          );
        }
      }
      await _trackAnalytics(
        () => ref
            .read(analyticsServiceProvider)
            .authAnonymousBootstrapSucceeded(),
      );
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Anonymous authentication bootstrap failed: $error');
        debugPrint('App will continue without authentication.');
      }
      await _trackAnalytics(
        () => ref
            .read(analyticsServiceProvider)
            .authAnonymousBootstrapFailed(reason: error.runtimeType.toString()),
      );
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> _trackAnalytics(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Analytics failures must never block account bootstrap.
    }
  }
}
