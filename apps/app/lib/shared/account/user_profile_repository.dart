import 'user_profile.dart';

/// Abstraction for loading and saving the current user's profile.
abstract interface class UserProfileRepository {
  UserProfile? get currentUserProfile;

  Stream<UserProfile?> watchCurrentUserProfile();

  Future<void> saveUserProfile(UserProfile profile);
}

class UnavailableUserProfileRepository implements UserProfileRepository {
  const UnavailableUserProfileRepository(this.message);

  final String message;

  @override
  UserProfile? get currentUserProfile => null;

  @override
  Stream<UserProfile?> watchCurrentUserProfile() {
    return Stream<UserProfile?>.value(null);
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) {
    throw StateError(message);
  }
}
