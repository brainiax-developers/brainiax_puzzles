import 'package:flutter/foundation.dart';

import 'user_identity.dart';

enum AuthStatus { signedOut, authenticated }

@immutable
class AuthState {
  const AuthState.signedOut() : status = AuthStatus.signedOut, identity = null;

  const AuthState.authenticated(this.identity)
    : status = AuthStatus.authenticated,
      assert(identity != null);

  final AuthStatus status;
  final UserIdentity? identity;

  bool get isAuthenticated => identity != null;
  bool get isAnonymous => identity?.isAnonymous ?? false;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthState &&
            runtimeType == other.runtimeType &&
            status == other.status &&
            identity == other.identity;
  }

  @override
  int get hashCode => Object.hash(status, identity);

  @override
  String toString() {
    return 'AuthState(status: $status, identity: $identity)';
  }
}
