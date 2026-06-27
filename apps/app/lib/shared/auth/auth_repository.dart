import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_sign_in;

import 'auth_state.dart';
import 'user_identity.dart';

abstract interface class AuthRepository {
  AuthState get currentAuthState;

  Stream<AuthState> authStateChanges();

  Future<AuthState> signInAnonymously({
    Duration timeout = const Duration(seconds: 5),
  });

  Future<GoogleSignInResult> signInWithGoogle();

  Future<AppleSignInResult> linkWithApple();
}

enum GoogleSignInResultStatus {
  linked,
  signedIn,
  cancelled,
  recoverableFailure,
}

class GoogleSignInResult {
  const GoogleSignInResult._({
    required this.status,
    this.authState,
    this.failure,
  });

  const GoogleSignInResult.linked(AuthState authState)
    : this._(status: GoogleSignInResultStatus.linked, authState: authState);

  const GoogleSignInResult.signedIn(AuthState authState)
    : this._(status: GoogleSignInResultStatus.signedIn, authState: authState);

  const GoogleSignInResult.cancelled()
    : this._(status: GoogleSignInResultStatus.cancelled);

  const GoogleSignInResult.recoverableFailure({
    required GoogleSignInFailure failure,
    AuthState? authState,
  }) : this._(
         status: GoogleSignInResultStatus.recoverableFailure,
         authState: authState,
         failure: failure,
       );

  final GoogleSignInResultStatus status;
  final AuthState? authState;
  final GoogleSignInFailure? failure;

  bool get succeeded =>
      status == GoogleSignInResultStatus.linked ||
      status == GoogleSignInResultStatus.signedIn;
}

class GoogleSignInFailure {
  const GoogleSignInFailure({required this.code, required this.message});

  final String code;
  final String message;
}

enum AppleSignInResultStatus { linked, signedIn, cancelled, recoverableFailure }

class AppleSignInResult {
  const AppleSignInResult._({
    required this.status,
    this.authState,
    this.failure,
  });

  const AppleSignInResult.linked(AuthState authState)
    : this._(status: AppleSignInResultStatus.linked, authState: authState);

  const AppleSignInResult.signedIn(AuthState authState)
    : this._(status: AppleSignInResultStatus.signedIn, authState: authState);

  const AppleSignInResult.cancelled()
    : this._(status: AppleSignInResultStatus.cancelled);

  const AppleSignInResult.recoverableFailure({
    required AppleSignInFailure failure,
    AuthState? authState,
  }) : this._(
         status: AppleSignInResultStatus.recoverableFailure,
         authState: authState,
         failure: failure,
       );

  final AppleSignInResultStatus status;
  final AuthState? authState;
  final AppleSignInFailure? failure;

  bool get succeeded =>
      status == AppleSignInResultStatus.linked ||
      status == AppleSignInResultStatus.signedIn;
}

class AppleSignInFailure {
  const AppleSignInFailure({required this.code, required this.message});

  final String code;
  final String message;
}

class GoogleSignInTokens {
  const GoogleSignInTokens({required this.idToken, this.accessToken});

  final String idToken;
  final String? accessToken;
}

abstract interface class GoogleSignInClient {
  Future<GoogleSignInTokens?> signIn();
}

class GoogleSignInUnavailableException implements Exception {
  const GoogleSignInUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GoogleSignInPluginClient implements GoogleSignInClient {
  GoogleSignInPluginClient(this._googleSignIn);

  final google_sign_in.GoogleSignIn _googleSignIn;

  static Future<void>? _initializeFuture;
  static bool _initialized = false;

  @override
  Future<GoogleSignInTokens?> signIn() async {
    await _ensureInitialized();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw const GoogleSignInUnavailableException(
        'Interactive Google sign-in is unavailable on this platform.',
      );
    }

    try {
      final google_sign_in.GoogleSignInAccount account = await _googleSignIn
          .authenticate();
      final String? idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleSignInUnavailableException(
          'Google did not return an ID token.',
        );
      }
      return GoogleSignInTokens(idToken: idToken);
    } on google_sign_in.GoogleSignInException catch (error) {
      if (_isGoogleCancellation(error)) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    try {
      await (_initializeFuture ??= _googleSignIn.initialize());
      _initialized = true;
    } catch (_) {
      _initializeFuture = null;
      rethrow;
    }
  }
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(
    this._firebaseAuth, {
    GoogleSignInClient? googleSignInClient,
  }) : _googleSignInClient =
           googleSignInClient ??
           GoogleSignInPluginClient(google_sign_in.GoogleSignIn.instance);

  final firebase_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignInClient _googleSignInClient;

  @override
  AuthState get currentAuthState => _mapUser(_firebaseAuth.currentUser);

  @override
  Stream<AuthState> authStateChanges() {
    return _firebaseAuth.userChanges().map(_mapUser);
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

  @override
  Future<GoogleSignInResult> signInWithGoogle() async {
    final AuthState currentState = currentAuthState;
    final firebase_auth.User? currentUser = _firebaseAuth.currentUser;
    if (currentUser != null && !currentUser.isAnonymous) {
      return GoogleSignInResult.signedIn(currentState);
    }

    final GoogleSignInTokens? tokens;
    try {
      tokens = await _googleSignInClient.signIn();
    } on google_sign_in.GoogleSignInException catch (error) {
      if (_isGoogleCancellation(error)) {
        return const GoogleSignInResult.cancelled();
      }
      return GoogleSignInResult.recoverableFailure(
        authState: currentState,
        failure: GoogleSignInFailure(
          code: 'google-${error.code.name}',
          message:
              error.description ??
              'Google sign-in is unavailable right now. Please try again.',
        ),
      );
    } on GoogleSignInUnavailableException catch (error) {
      return GoogleSignInResult.recoverableFailure(
        authState: currentState,
        failure: GoogleSignInFailure(
          code: 'google-unavailable',
          message: error.message,
        ),
      );
    }

    if (tokens == null) {
      return const GoogleSignInResult.cancelled();
    }

    final firebase_auth.AuthCredential credential =
        firebase_auth.GoogleAuthProvider.credential(
          idToken: tokens.idToken,
          accessToken: tokens.accessToken,
        );

    try {
      if (currentUser != null && currentUser.isAnonymous) {
        final firebase_auth.UserCredential linkedCredential = await currentUser
            .linkWithCredential(credential);
        return GoogleSignInResult.linked(
          _mapUser(linkedCredential.user ?? _firebaseAuth.currentUser),
        );
      }

      final firebase_auth.UserCredential signedInCredential =
          await _firebaseAuth.signInWithCredential(credential);
      return GoogleSignInResult.signedIn(
        _mapUser(signedInCredential.user ?? _firebaseAuth.currentUser),
      );
    } on firebase_auth.FirebaseAuthException catch (error) {
      return GoogleSignInResult.recoverableFailure(
        authState: currentState,
        failure: GoogleSignInFailure(
          code: error.code,
          message: _googleSignInFailureMessage(error),
        ),
      );
    }
  }

  @override
  Future<AppleSignInResult> linkWithApple() async {
    final AuthState currentState = currentAuthState;
    final firebase_auth.User? currentUser = _firebaseAuth.currentUser;
    if (currentUser != null && !currentUser.isAnonymous) {
      return AppleSignInResult.signedIn(currentState);
    }

    // TODO(bx-0411): Wire up `sign_in_with_apple` and the Firebase credential
    // exchange once the iOS/macOS setup is ready.
    return AppleSignInResult.recoverableFailure(
      authState: currentState,
      failure: AppleSignInFailure(
        code: 'apple-unavailable',
        message: _appleSignInUnavailableMessage(),
      ),
    );
  }

  AuthState _mapUser(firebase_auth.User? user) {
    if (user == null) {
      return const AuthState.signedOut();
    }

    return AuthState.authenticated(
      UserIdentity(
        uid: user.uid,
        isAnonymous: user.isAnonymous,
        providerIds: _providerIds(user),
      ),
    );
  }

  List<String> _providerIds(firebase_auth.User user) {
    if (user.isAnonymous) {
      return const <String>['anonymous'];
    }

    try {
      final ids =
          user.providerData
              .map((provider) => provider.providerId)
              .where((providerId) => providerId.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      return List<String>.unmodifiable(ids);
    } catch (_) {
      return const <String>[];
    }
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

  @override
  Future<GoogleSignInResult> signInWithGoogle() async {
    return GoogleSignInResult.recoverableFailure(
      authState: currentAuthState,
      failure: GoogleSignInFailure(code: 'auth-unavailable', message: message),
    );
  }

  @override
  Future<AppleSignInResult> linkWithApple() async {
    return AppleSignInResult.recoverableFailure(
      authState: currentAuthState,
      failure: AppleSignInFailure(code: 'auth-unavailable', message: message),
    );
  }
}

bool _isGoogleCancellation(google_sign_in.GoogleSignInException error) {
  switch (error.code) {
    case google_sign_in.GoogleSignInExceptionCode.canceled:
    case google_sign_in.GoogleSignInExceptionCode.interrupted:
    case google_sign_in.GoogleSignInExceptionCode.uiUnavailable:
      return true;
    default:
      return false;
  }
}

String _googleSignInFailureMessage(firebase_auth.FirebaseAuthException error) {
  switch (error.code) {
    case 'credential-already-in-use':
    case 'account-exists-with-different-credential':
    case 'email-already-in-use':
      return 'That Google account is already connected to another Brainiax profile. Your anonymous progress is still saved on this device.';
    case 'network-request-failed':
      return 'Google sign-in needs a network connection. Your local progress is still saved on this device.';
    default:
      return error.message ??
          'Google sign-in could not finish. Your local progress is still saved on this device.';
  }
}

String _appleSignInUnavailableMessage() {
  if (kIsWeb) {
    return 'Apple sign-in is unavailable in this build.';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return 'Apple sign-in is not wired up yet. You can keep playing normally.';
    case TargetPlatform.android:
      return 'Apple sign-in is unavailable on Android.';
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return 'Apple sign-in is unavailable on this platform.';
  }
}
