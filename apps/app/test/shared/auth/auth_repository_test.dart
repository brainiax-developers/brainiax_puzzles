import 'package:app/shared/auth/auth_repository.dart';
import 'package:app/shared/auth/auth_state.dart';
import 'package:app/shared/auth/user_identity.dart';
import 'package:app/shared/analytics/analytics_events.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../analytics/fake_analytics_service.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(GoogleAuthProvider.credential(idToken: 'fallback'));
  });

  group('FirebaseAuthRepository', () {
    late MockFirebaseAuth firebaseAuth;
    late MockGoogleSignInClient googleSignInClient;
    late FakeAnalyticsService analyticsService;
    late FirebaseAuthRepository repository;

    setUp(() {
      firebaseAuth = MockFirebaseAuth();
      googleSignInClient = MockGoogleSignInClient();
      analyticsService = FakeAnalyticsService();
      repository = FirebaseAuthRepository(
        firebaseAuth,
        googleSignInClient: googleSignInClient,
        analyticsService: analyticsService,
      );
    });

    test('maps the current Firebase user into authenticated state', () {
      final user = MockUser();
      when(() => firebaseAuth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('anon-user');
      when(() => user.isAnonymous).thenReturn(true);

      expect(
        repository.currentAuthState,
        const AuthState.authenticated(
          UserIdentity(
            uid: 'anon-user',
            isAnonymous: true,
            providerIds: <String>['anonymous'],
          ),
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
        () => firebaseAuth.userChanges(),
      ).thenAnswer((_) => Stream<User?>.value(user));

      await expectLater(
        repository.authStateChanges(),
        emits(
          const AuthState.authenticated(
            UserIdentity(
              uid: 'stream-user',
              isAnonymous: true,
              providerIds: <String>['anonymous'],
            ),
          ),
        ),
      );
    });

    test('links Google credentials to the current anonymous user', () async {
      final anonUser = MockUser();
      final linkedUser = MockUser();
      final userCredential = MockUserCredential();
      when(() => firebaseAuth.currentUser).thenReturn(anonUser);
      when(() => anonUser.uid).thenReturn('anon-user');
      when(() => anonUser.isAnonymous).thenReturn(true);
      when(() => linkedUser.uid).thenReturn('anon-user');
      when(() => linkedUser.isAnonymous).thenReturn(false);
      when(() => linkedUser.providerData).thenReturn(const <UserInfo>[]);
      when(() => userCredential.user).thenReturn(linkedUser);
      when(
        () => googleSignInClient.signIn(),
      ).thenAnswer((_) async => const GoogleSignInTokens(idToken: 'id-token'));
      when(
        () => anonUser.linkWithCredential(any()),
      ).thenAnswer((_) async => userCredential);

      final result = await repository.signInWithGoogle();

      expect(result.status, GoogleSignInResultStatus.linked);
      expect(result.authState?.identity?.uid, 'anon-user');
      expect(result.authState?.isAnonymous, isFalse);
      expect(
        analyticsService
            .lastEventNamed(AnalyticsEvents.authLinkSucceeded)
            ?.parameters,
        <String, Object?>{
          'provider': 'google',
          'upgrade_path': 'anonymous_link',
          'result_status': 'linked',
        },
      );
      expect(
        analyticsService
            .lastEventNamed(AnalyticsEvents.authLinkStarted)
            ?.parameters,
        <String, Object?>{
          'provider': 'google',
          'upgrade_path': 'anonymous_link',
        },
      );
      verify(() => anonUser.linkWithCredential(any())).called(1);
      verifyNever(() => firebaseAuth.signInWithCredential(any()));
    });

    test('signs in with Google when there is no current user', () async {
      final signedInUser = MockUser();
      final userCredential = MockUserCredential();
      when(() => firebaseAuth.currentUser).thenReturn(null);
      when(() => signedInUser.uid).thenReturn('google-user');
      when(() => signedInUser.isAnonymous).thenReturn(false);
      when(() => signedInUser.providerData).thenReturn(const <UserInfo>[]);
      when(() => userCredential.user).thenReturn(signedInUser);
      when(
        () => googleSignInClient.signIn(),
      ).thenAnswer((_) async => const GoogleSignInTokens(idToken: 'id-token'));
      when(
        () => firebaseAuth.signInWithCredential(any()),
      ).thenAnswer((_) async => userCredential);

      final result = await repository.signInWithGoogle();

      expect(result.status, GoogleSignInResultStatus.signedIn);
      expect(result.authState?.identity?.uid, 'google-user');
      expect(
        analyticsService
            .lastEventNamed(AnalyticsEvents.authSignInSucceeded)
            ?.parameters,
        <String, Object?>{
          'provider': 'google',
          'upgrade_path': 'direct_sign_in',
          'result_status': 'signedIn',
        },
      );
      expect(
        analyticsService
            .lastEventNamed(AnalyticsEvents.authSignInStarted)
            ?.parameters,
        <String, Object?>{
          'provider': 'google',
          'upgrade_path': 'direct_sign_in',
        },
      );
      verify(() => firebaseAuth.signInWithCredential(any())).called(1);
    });

    test('treats Google cancellation as a non-error result', () async {
      final anonUser = MockUser();
      when(() => firebaseAuth.currentUser).thenReturn(anonUser);
      when(() => anonUser.uid).thenReturn('anon-user');
      when(() => anonUser.isAnonymous).thenReturn(true);
      when(() => googleSignInClient.signIn()).thenAnswer((_) async => null);

      final result = await repository.signInWithGoogle();

      expect(result.status, GoogleSignInResultStatus.cancelled);
      expect(
        analyticsService
            .lastEventNamed(AnalyticsEvents.authLinkCancelled)
            ?.parameters,
        <String, Object?>{
          'provider': 'google',
          'upgrade_path': 'anonymous_link',
          'result_status': 'cancelled',
        },
      );
      verifyNever(() => anonUser.linkWithCredential(any()));
      verifyNever(() => firebaseAuth.signInWithCredential(any()));
    });

    test(
      'keeps anonymous user when Google credential is already in use',
      () async {
        final anonUser = MockUser();
        when(() => firebaseAuth.currentUser).thenReturn(anonUser);
        when(() => anonUser.uid).thenReturn('anon-user');
        when(() => anonUser.isAnonymous).thenReturn(true);
        when(() => googleSignInClient.signIn()).thenAnswer(
          (_) async => const GoogleSignInTokens(idToken: 'id-token'),
        );
        when(
          () => anonUser.linkWithCredential(any()),
        ).thenThrow(FirebaseAuthException(code: 'credential-already-in-use'));

        final result = await repository.signInWithGoogle();

        expect(result.status, GoogleSignInResultStatus.recoverableFailure);
        expect(result.failure?.code, 'credential-already-in-use');
        expect(result.authState?.identity?.uid, 'anon-user');
        expect(result.authState?.isAnonymous, isTrue);
        expect(
          analyticsService
              .lastEventNamed(AnalyticsEvents.authLinkFailed)
              ?.parameters,
          <String, Object?>{
            'provider': 'google',
            'upgrade_path': 'anonymous_link',
            'reason': 'credential-already-in-use',
            'result_status': 'recoverableFailure',
          },
        );
        verify(() => anonUser.linkWithCredential(any())).called(1);
        verifyNever(() => firebaseAuth.signInWithCredential(any()));
      },
    );

    test('reports network failures as recoverable', () async {
      when(() => firebaseAuth.currentUser).thenReturn(null);
      when(
        () => googleSignInClient.signIn(),
      ).thenAnswer((_) async => const GoogleSignInTokens(idToken: 'id-token'));
      when(
        () => firebaseAuth.signInWithCredential(any()),
      ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      final result = await repository.signInWithGoogle();

      expect(result.status, GoogleSignInResultStatus.recoverableFailure);
      expect(result.failure?.code, 'network-request-failed');
      expect(result.failure?.message, contains('network connection'));
      expect(
        analyticsService
            .lastEventNamed(AnalyticsEvents.authSignInFailed)
            ?.parameters,
        <String, Object?>{
          'provider': 'google',
          'upgrade_path': 'direct_sign_in',
          'reason': 'network-request-failed',
          'result_status': 'recoverableFailure',
        },
      );
    });

    test('reports Google provider unavailability distinctly', () async {
      when(() => firebaseAuth.currentUser).thenReturn(null);
      when(
        () => googleSignInClient.signIn(),
      ).thenThrow(const GoogleSignInUnavailableException('Google unavailable'));

      final result = await repository.signInWithGoogle();

      expect(result.status, GoogleSignInResultStatus.recoverableFailure);
      expect(result.failure?.code, 'google-unavailable');
      expect(
        analyticsService
            .lastEventNamed(AnalyticsEvents.authSignInUnavailable)
            ?.parameters,
        <String, Object?>{
          'provider': 'google',
          'upgrade_path': 'direct_sign_in',
          'reason': 'google-unavailable',
          'result_status': 'recoverableFailure',
        },
      );
    });

    test(
      'returns a recoverable Apple result on Android without touching Firebase',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });

        when(() => firebaseAuth.currentUser).thenReturn(null);

        final result = await repository.linkWithApple();

        expect(result.status, AppleSignInResultStatus.recoverableFailure);
        expect(result.failure?.code, 'apple-unavailable');
        expect(result.failure?.message, contains('Android'));
        expect(
          analyticsService
              .lastEventNamed(AnalyticsEvents.authSignInUnavailable)
              ?.parameters,
          <String, Object?>{
            'provider': 'apple',
            'upgrade_path': 'direct_sign_in',
            'reason': 'apple-unavailable',
            'result_status': 'recoverableFailure',
          },
        );
        verifyNever(() => firebaseAuth.signInAnonymously());
        verifyNever(() => firebaseAuth.signInWithCredential(any()));
      },
    );
  });
}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockGoogleSignInClient extends Mock implements GoogleSignInClient {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}
