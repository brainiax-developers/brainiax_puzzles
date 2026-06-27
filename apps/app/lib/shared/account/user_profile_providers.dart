import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_profile.dart';
import 'user_profile_repository.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return const UnavailableUserProfileRepository(
    'User profile persistence is unavailable until the repository is implemented.',
  );
});

final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  final repository = ref.watch(userProfileRepositoryProvider);
  return repository.currentUserProfile;
});

final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final repository = ref.watch(userProfileRepositoryProvider);
  return repository.watchCurrentUserProfile();
});
