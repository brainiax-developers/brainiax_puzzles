import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'auth_state.dart';
import 'user_identity.dart';

abstract interface class AuthRepository {
  AuthState get currentAuthState;

  Stream<AuthState> authStateChanges();

  Future<AuthState> signInAnonymously({
    Duration timeout = const Duration(seconds: 5),
  });
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._firebaseAuth);

  final firebase_auth.FirebaseAuth _firebaseAuth;

  @override
  AuthState get currentAuthState => _mapUser(_firebaseAuth.currentUser);

  @override
  Stream<AuthState> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_mapUser);
  }

  @override
  Future<AuthState> signInAnonymously({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final existingUser = _firebaseAuth.currentUser;
    if (existingUser != null) {
      return _mapUser(existingUser);
    }

    final credential = await _firebaseAuth.signInAnonymously().timeout(
      timeout,
      onTimeout: () {
        throw TimeoutException('Anonymous sign-in timed out.', timeout);
      },
    );

    return _mapUser(credential.user ?? _firebaseAuth.currentUser);
  }

  AuthState _mapUser(firebase_auth.User? user) {
    if (user == null) {
      return const AuthState.signedOut();
    }

    return AuthState.authenticated(
      UserIdentity(uid: user.uid, isAnonymous: user.isAnonymous),
    );
  }
}

class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository(this.message);

  final String message;

  @override
  AuthState get currentAuthState => const AuthState.signedOut();

  @override
  Stream<AuthState> authStateChanges() {
    return Stream<AuthState>.value(const AuthState.signedOut());
  }

  @override
  Future<AuthState> signInAnonymously({
    Duration timeout = const Duration(seconds: 5),
  }) {
    throw StateError(message);
  }
}
