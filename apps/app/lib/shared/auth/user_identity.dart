import 'package:flutter/foundation.dart';

@immutable
class UserIdentity {
  const UserIdentity({required this.uid, required this.isAnonymous});

  final String uid;
  final bool isAnonymous;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UserIdentity &&
            runtimeType == other.runtimeType &&
            uid == other.uid &&
            isAnonymous == other.isAnonymous;
  }

  @override
  int get hashCode => Object.hash(uid, isAnonymous);

  @override
  String toString() {
    return 'UserIdentity(uid: $uid, isAnonymous: $isAnonymous)';
  }
}
