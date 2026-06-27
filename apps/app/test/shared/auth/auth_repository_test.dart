import 'package:app/shared/auth/auth_repository.dart';
import 'package:app/shared/auth/auth_state.dart';
import 'package:app/shared/auth/user_identity.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  group('FirebaseAuthRepository', () {
    late MockFirebaseAuth firebaseAuth;
    late FirebaseAuthRepository repository;

    setUp(() {
      firebaseAuth = MockFirebaseAuth();
      repository = FirebaseAuthRepository(firebaseAuth);
    });

    test('maps the current Firebase user into authenticated state', () {
      final user = MockUser();
      when(() => firebaseAuth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('anon-user');
      when(() => user.isAnonymous).thenReturn(true);

      expect(
        repository.currentAuthState,
        const AuthState.authenticated(
          UserIdentity(uid: 'anon-user', isAnonymous: true),
        ),
      );
    });

    test(
      'returns the existing current user without reauthenticating',
      () async {
        final user = MockUser();
        when(() => firebaseAuth.currentUser).thenReturn(user);
        when(() => user.uid).thenReturn('existing-user');
        when(() => user.isAnonymous).thenReturn(true);

        final authState = await repository.signInAnonymously();

        expect(authState.isAnonymous, isTrue);
        expect(authState.identity?.uid, 'existing-user');
        verifyNever(() => firebaseAuth.signInAnonymously());
      },
    );

    test('maps auth state changes into domain auth states', () async {
      final user = MockUser();
      when(() => user.uid).thenReturn('stream-user');
      when(() => user.isAnonymous).thenReturn(true);
      when(
        () => firebaseAuth.authStateChanges(),
      ).thenAnswer((_) => Stream<User?>.value(user));

      await expectLater(
        repository.authStateChanges(),
        emits(
          const AuthState.authenticated(
            UserIdentity(uid: 'stream-user', isAnonymous: true),
          ),
        ),
      );
    });
  });
}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}
