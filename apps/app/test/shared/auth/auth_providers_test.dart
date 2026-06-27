import 'dart:async';

import 'package:app/shared/auth/auth_providers.dart';
import 'package:app/shared/auth/auth_repository.dart';
import 'package:app/shared/auth/auth_state.dart';
import 'package:app/shared/auth/user_identity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('auth providers', () {
    test('current identity follows auth state stream', () async {
      final repository = _FakeAuthRepository(
        initialState: const AuthState.signedOut(),
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
      });

      expect(container.read(currentUserIdentityProvider), isNull);

      final completer = Completer<AuthState>();
      final subscription = container.listen<AsyncValue<AuthState>>(
        authStateProvider,
        (previous, next) {
          final authState = next.asData?.value;
          if (authState != null && !completer.isCompleted) {
            completer.complete(authState);
          }
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      repository.emit(
        const AuthState.authenticated(
          UserIdentity(uid: 'anon-user', isAnonymous: true),
        ),
      );

      final authState = await completer.future;
      expect(authState.isAnonymous, isTrue);
      expect(container.read(currentUserIdentityProvider)?.uid, 'anon-user');
    });

    test('bootstrap signs in anonymously with the provided timeout', () async {
      final repository = _FakeAuthRepository(
        initialState: const AuthState.signedOut(),
        signInResult: const AuthState.authenticated(
          UserIdentity(uid: 'anon-user', isAnonymous: true),
        ),
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
      });

      await container
          .read(authBootstrapControllerProvider.notifier)
          .bootstrapAnonymousSignIn(timeout: const Duration(milliseconds: 250));

      expect(repository.signInCalls, 1);
      expect(repository.lastTimeout, const Duration(milliseconds: 250));
      expect(container.read(currentUserIdentityProvider)?.uid, 'anon-user');
      expect(container.read(authBootstrapControllerProvider).hasError, isFalse);
    });

    test('bootstrap records errors without rethrowing', () async {
      final repository = _FakeAuthRepository(
        initialState: const AuthState.signedOut(),
        signInError: TimeoutException(
          'auth timeout',
          const Duration(milliseconds: 50),
        ),
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
      });

      await container
          .read(authBootstrapControllerProvider.notifier)
          .bootstrapAnonymousSignIn(timeout: const Duration(milliseconds: 50));

      final bootstrapState = container.read(authBootstrapControllerProvider);
      expect(bootstrapState.hasError, isTrue);
      expect(bootstrapState.error, isA<TimeoutException>());
      expect(repository.signInCalls, 1);
      expect(container.read(currentUserIdentityProvider), isNull);
    });

    test('bootstrap skips sign-in when already authenticated', () async {
      final repository = _FakeAuthRepository(
        initialState: const AuthState.authenticated(
          UserIdentity(uid: 'existing-user', isAnonymous: true),
        ),
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
      });

      await container
          .read(authBootstrapControllerProvider.notifier)
          .bootstrapAnonymousSignIn();

      expect(repository.signInCalls, 0);
      expect(container.read(currentUserIdentityProvider)?.uid, 'existing-user');
      expect(container.read(authBootstrapControllerProvider).hasError, isFalse);
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    required AuthState initialState,
    this.signInResult,
    this.signInError,
  }) : _currentState = initialState;

  final AuthState? signInResult;
  final Object? signInError;
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();

  AuthState _currentState;
  int signInCalls = 0;
  Duration? lastTimeout;

  @override
  AuthState get currentAuthState => _currentState;

  @override
  Stream<AuthState> authStateChanges() => _controller.stream;

  @override
  Future<AuthState> signInAnonymously({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    signInCalls++;
    lastTimeout = timeout;

    if (signInError != null) {
      throw signInError!;
    }

    final nextState = signInResult ?? _currentState;
    emit(nextState);
    return nextState;
  }

  void emit(AuthState nextState) {
    _currentState = nextState;
    _controller.add(nextState);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
