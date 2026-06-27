import 'package:flutter/foundation.dart';

@immutable
class UserIdentity {
  const UserIdentity({
    required this.uid,
    required this.isAnonymous,
    this.providerIds = const <String>[],
  });

  final String uid;
  final bool isAnonymous;
  final List<String> providerIds;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UserIdentity &&
            runtimeType == other.runtimeType &&
            uid == other.uid &&
            isAnonymous == other.isAnonymous &&
            listEquals(providerIds, other.providerIds);
  }

  @override
  int get hashCode =>
      Object.hash(uid, isAnonymous, Object.hashAll(providerIds));

  @override
  String toString() {
    return 'UserIdentity(uid: $uid, isAnonymous: $isAnonymous, providerIds: $providerIds)';
  }
}
