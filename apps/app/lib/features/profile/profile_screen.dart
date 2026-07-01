import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/analytics/analytics_providers.dart';
import '../../shared/navigation/app_routes.dart';
import '../../shared/account/account_upgrade_prompt_providers.dart';
import '../../shared/account/account_upgrade_prompt_service.dart';
import '../../shared/auth/auth_providers.dart';
import '../../shared/auth/auth_repository.dart';
import '../../shared/auth/auth_state.dart';
import '../../shared/crash/crash_reporting_providers.dart';
import '../../shared/models/puzzle_type.dart';
import '../../shared/providers/puzzle_local_store_providers.dart';
import '../../shared/sync/sync_engine.dart';
import '../../shared/sync/sync_providers.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/brainiax/brainiax_widgets.dart';
import 'profile_dashboard.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isSyncing = false;
  bool _isSigningInWithGoogle = false;
  bool _isSigningInWithApple = false;
  bool _trackedProfileView = false;
  bool _trackedUpgradePromptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _trackedProfileView) {
        return;
      }
      _trackedProfileView = true;
      unawaited(ref.read(analyticsServiceProvider).profileViewed());
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileDashboardProvider);
    final AccountUpgradePromptEligibility upgradePrompt = ref.watch(
      accountUpgradePromptEligibilityProvider,
    );
    if (upgradePrompt.shouldShow && !_trackedUpgradePromptShown) {
      _trackedUpgradePromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          ref
              .read(analyticsServiceProvider)
              .authUpgradePromptShown(upgradePrompt),
        );
      });
    }

    return SafeArea(
      bottom: false,
      child: profileAsync.when(
        data: (dashboard) => _ProfileBody(
          dashboard: dashboard,
          upgradePrompt: upgradePrompt,
          isSyncing: _isSyncing,
          isSigningInWithGoogle: _isSigningInWithGoogle,
          isSigningInWithApple: _isSigningInWithApple,
          onSyncNow: dashboard.syncSummary.canSyncNow ? _handleSyncNow : null,
          onSignInWithGoogle:
              dashboard.authAvailable &&
                  dashboard.accountState != ProfileAccountState.signedIn
              ? _handleSignInWithGoogle
              : null,
          onSignInWithApple:
              dashboard.authAvailable &&
                  dashboard.accountState != ProfileAccountState.signedIn &&
                  _supportsAppleSignIn()
              ? _handleSignInWithApple
              : null,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ProfileLoadError(
          onOpenSettings: () => context.push(AppRoutes.settings),
        ),
      ),
    );
  }

  Future<void> _handleSyncNow() async {
    if (_isSyncing) {
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final SyncEngineResult result = await ref
          .read(syncControllerProvider)
          .retryFailedAndProcessPending();
      ref.invalidate(profileDashboardProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_syncResultMessage(result))));
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _handleSignInWithGoogle() async {
    if (_isSigningInWithGoogle) {
      return;
    }

    setState(() {
      _isSigningInWithGoogle = true;
    });

    try {
      final bool wasAnonymous =
          ref.read(currentUserIdentityProvider)?.isAnonymous ?? false;
      final GoogleSignInResult result = await ref
          .read(authRepositoryProvider)
          .signInWithGoogle();

      if (result.status == GoogleSignInResultStatus.recoverableFailure) {
        await _reportAuthLinkFailure(
          provider: 'google',
          stage: 'sign_in',
          upgradePath: wasAnonymous ? 'anonymous_link' : 'direct_sign_in',
          resultStatus: result.status.name,
          failureCode: result.failure?.code,
        );
      }

      if (result.succeeded) {
        await _triggerProfileSyncAfterAccountSignIn(
          result.authState,
          provider: 'google',
        );
      }

      ref.invalidate(authStateProvider);
      ref.invalidate(currentUserIdentityProvider);
      ref.invalidate(profileDashboardProvider);
      ref.invalidate(accountUpgradePromptEligibilityProvider);

      if (!mounted || result.status == GoogleSignInResultStatus.cancelled) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_googleSignInResultMessage(result))),
      );
    } catch (error, stackTrace) {
      await _reportUnexpectedAuthLinkFailure(
        provider: 'google',
        stage: 'sign_in',
        error: error,
        stackTrace: stackTrace,
      );
      if (kDebugMode) {
        debugPrint('Google sign-in failed unexpectedly: $error');
        debugPrint('$stackTrace');
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google sign-in is unavailable right now. You can keep playing normally.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningInWithGoogle = false;
        });
      }
    }
  }

  Future<void> _handleSignInWithApple() async {
    if (_isSigningInWithApple) {
      return;
    }

    setState(() {
      _isSigningInWithApple = true;
    });

    try {
      final bool wasAnonymous =
          ref.read(currentUserIdentityProvider)?.isAnonymous ?? false;
      final AppleSignInResult result = await ref
          .read(authRepositoryProvider)
          .linkWithApple();

      if (result.status == AppleSignInResultStatus.recoverableFailure) {
        await _reportAuthLinkFailure(
          provider: 'apple',
          stage: 'link',
          upgradePath: wasAnonymous ? 'anonymous_link' : 'direct_sign_in',
          resultStatus: result.status.name,
          failureCode: result.failure?.code,
        );
      }

      if (result.succeeded) {
        await _triggerProfileSyncAfterAccountSignIn(
          result.authState,
          provider: 'apple',
        );
      }

      ref.invalidate(authStateProvider);
      ref.invalidate(currentUserIdentityProvider);
      ref.invalidate(profileDashboardProvider);
      ref.invalidate(accountUpgradePromptEligibilityProvider);

      if (!mounted || result.status == AppleSignInResultStatus.cancelled) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_appleSignInResultMessage(result))),
      );
    } catch (error, stackTrace) {
      await _reportUnexpectedAuthLinkFailure(
        provider: 'apple',
        stage: 'link',
        error: error,
        stackTrace: stackTrace,
      );
      if (kDebugMode) {
        debugPrint('Apple sign-in failed unexpectedly: $error');
        debugPrint('$stackTrace');
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Apple sign-in is unavailable right now. You can keep playing normally.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningInWithApple = false;
        });
      }
    }
  }

  Future<void> _triggerProfileSyncAfterAccountSignIn(
    AuthState? authState, {
    required String provider,
  }) async {
    final identity = authState?.identity;
    if (identity == null) {
      return;
    }

    try {
      await ref
          .read(firestoreSyncRepositoryProvider)
          ?.ensureUserProfile(identity);
      await ref.read(syncControllerProvider).retryFailedAndProcessPending();
    } catch (error, stackTrace) {
      await _reportUnexpectedAuthLinkFailure(
        provider: provider,
        stage: 'post_sign_in_sync',
        error: error,
        stackTrace: stackTrace,
      );
      if (kDebugMode) {
        debugPrint('Post Google sign-in profile sync failed: $error');
        debugPrint('$stackTrace');
      }
    }
  }

  Future<void> _reportAuthLinkFailure({
    required String provider,
    required String stage,
    required String upgradePath,
    required String resultStatus,
    String? failureCode,
  }) {
    return ref
        .read(crashReportingServiceProvider)
        .reportNonFatal(
          reason: 'auth_link_failure',
          error: StateError('Auth link failure'),
          stackTrace: StackTrace.current,
          context: <String, Object?>{
            'provider': provider,
            'stage': stage,
            'upgradePath': upgradePath,
            'resultStatus': resultStatus,
            'failureCode': failureCode,
          },
        );
  }

  Future<void> _reportUnexpectedAuthLinkFailure({
    required String provider,
    required String stage,
    required Object error,
    required StackTrace stackTrace,
  }) {
    return ref
        .read(crashReportingServiceProvider)
        .reportNonFatal(
          reason: 'auth_link_failure',
          error: error,
          stackTrace: stackTrace,
          context: <String, Object?>{'provider': provider, 'stage': stage},
        );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.dashboard,
    required this.upgradePrompt,
    required this.isSyncing,
    required this.isSigningInWithGoogle,
    required this.isSigningInWithApple,
    required this.onSyncNow,
    required this.onSignInWithGoogle,
    required this.onSignInWithApple,
  });

  final ProfileDashboardData dashboard;
  final AccountUpgradePromptEligibility? upgradePrompt;
  final bool isSyncing;
  final bool isSigningInWithGoogle;
  final bool isSigningInWithApple;
  final VoidCallback? onSyncNow;
  final VoidCallback? onSignInWithGoogle;
  final VoidCallback? onSignInWithApple;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();

    return ListView(
      padding: EdgeInsets.fromLTRB(spacing.l, spacing.m, spacing.l, spacing.xl),
      children: [
        _AccountStatusCard(
          dashboard: dashboard,
          isSyncing: isSyncing,
          isSigningInWithGoogle: isSigningInWithGoogle,
          isSigningInWithApple: isSigningInWithApple,
          onSyncNow: onSyncNow,
          onSignInWithGoogle: onSignInWithGoogle,
          onSignInWithApple: onSignInWithApple,
        ),
        SizedBox(height: spacing.l),
        _OverviewCard(overview: dashboard.overview),
        SizedBox(height: spacing.l),
        _StreakCard(streak: dashboard.dailyStreak),
        SizedBox(height: spacing.l),
        if (upgradePrompt?.shouldShow ?? false) ...[
          const _AccountUpgradePromptCard(),
          SizedBox(height: spacing.l),
        ],
        if (dashboard.hasPuzzleHistory)
          _PuzzleBreakdownCard(summaries: dashboard.puzzleSummaries)
        else
          const EmptyStateCard(
            title: 'No puzzle history yet',
            body:
                'Finish any puzzle to see completion counts and best times here. Local stats still work offline.',
            icon: Icons.insights_outlined,
          ),
        SizedBox(height: spacing.l),
        const _FutureAccountCopyCard(),
        SizedBox(height: spacing.l),
        BrainiaxCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            subtitle: const Text('Open app preferences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.settings),
          ),
        ),
      ],
    );
  }
}

class _AccountStatusCard extends StatelessWidget {
  const _AccountStatusCard({
    required this.dashboard,
    required this.isSyncing,
    required this.isSigningInWithGoogle,
    required this.isSigningInWithApple,
    required this.onSyncNow,
    required this.onSignInWithGoogle,
    required this.onSignInWithApple,
  });

  final ProfileDashboardData dashboard;
  final bool isSyncing;
  final bool isSigningInWithGoogle;
  final bool isSigningInWithApple;
  final VoidCallback? onSyncNow;
  final VoidCallback? onSignInWithGoogle;
  final VoidCallback? onSignInWithApple;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();

    return BrainiaxCard(
      backgroundColor: const Color(0xFF162846),
      borderColor: const Color(0xFF223A61),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      'Local-first progress, streaks, and account status.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFAAB6CC),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.s),
              IconButton(
                tooltip: 'Settings',
                onPressed: () => context.push(AppRoutes.settings),
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
              ),
            ],
          ),
          SizedBox(height: spacing.m),
          Wrap(
            spacing: spacing.s,
            runSpacing: spacing.s,
            children: [
              _StatusPill(
                icon: _accountIcon(dashboard.accountState),
                label: _accountLabel(dashboard.accountState),
                backgroundColor: const Color(0xFF223555),
                foregroundColor: Colors.white,
              ),
              _StatusPill(
                icon: _syncIcon(dashboard.syncSummary.state),
                label: _syncLabel(dashboard.syncSummary.state),
                backgroundColor: _syncPillColor(dashboard.syncSummary.state),
                foregroundColor: _syncPillForeground(
                  dashboard.syncSummary.state,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.m),
          Text(
            _accountCopy(dashboard),
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
          SizedBox(height: spacing.s),
          Text(
            _syncCopy(dashboard.syncSummary),
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFFD6DDED),
            ),
          ),
          if (dashboard.syncSummary.latestError != null) ...[
            SizedBox(height: spacing.s),
            Text(
              'Latest issue: ${dashboard.syncSummary.latestError}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFFFFD7D7),
              ),
            ),
          ],
          if (onSyncNow != null) ...[
            SizedBox(height: spacing.l),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('profile-sync-now-button'),
                onPressed: isSyncing ? null : onSyncNow,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF7B91B6)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_outlined),
                label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
              ),
            ),
          ],
          if (onSignInWithGoogle != null) ...[
            SizedBox(height: spacing.s),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('profile-google-sign-in-button'),
                onPressed: isSigningInWithGoogle ? null : onSignInWithGoogle,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF162846),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: isSigningInWithGoogle
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_outlined),
                label: Text(
                  isSigningInWithGoogle
                      ? 'Connecting...'
                      : 'Continue with Google',
                ),
              ),
            ),
          ],
          if (onSignInWithApple != null) ...[
            SizedBox(height: spacing.s),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('profile-apple-sign-in-button'),
                onPressed: isSigningInWithApple ? null : onSignInWithApple,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: isSigningInWithApple
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.apple),
                label: Text(
                  isSigningInWithApple
                      ? 'Connecting...'
                      : 'Continue with Apple',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.overview});

  final HomeStatsSnapshot overview;

  @override
  Widget build(BuildContext context) {
    final AppSpacing spacing =
        Theme.of(context).extension<AppSpacing>() ?? const AppSpacing();

    return BrainiaxCard(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Overview',
            subtitle: 'Offline totals from local puzzle history.',
          ),
          SizedBox(height: spacing.m),
          LayoutBuilder(
            builder: (context, constraints) {
              final double itemWidth = constraints.maxWidth >= 440
                  ? (constraints.maxWidth - (spacing.s * 2)) / 3
                  : (constraints.maxWidth - spacing.s) / 2;
              return Wrap(
                spacing: spacing.s,
                runSpacing: spacing.s,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: StatTile(
                      label: 'Total Solved',
                      value: overview.totalSolved.toString(),
                      icon: Icons.emoji_events_outlined,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: StatTile(
                      label: 'Today Completed',
                      value: overview.todayCompleted.toString(),
                      icon: Icons.today_outlined,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: StatTile(
                      label: 'Completed This Week',
                      value: overview.completedThisWeek.toString(),
                      icon: Icons.calendar_view_week_outlined,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final DailyStreakStatus streak;

  @override
  Widget build(BuildContext context) {
    final AppSpacing spacing =
        Theme.of(context).extension<AppSpacing>() ?? const AppSpacing();

    return BrainiaxCard(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Daily Challenge',
            subtitle:
                'Current and best streaks from local Daily Challenge play.',
          ),
          SizedBox(height: spacing.m),
          LayoutBuilder(
            builder: (context, constraints) {
              final double itemWidth = constraints.maxWidth >= 440
                  ? (constraints.maxWidth - spacing.s) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: spacing.s,
                runSpacing: spacing.s,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: StatTile(
                      label: 'Current Streak',
                      value: streak.currentStreak.toString(),
                      icon: Icons.local_fire_department_outlined,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: StatTile(
                      label: 'Best Streak',
                      value: streak.bestStreak.toString(),
                      icon: Icons.workspace_premium_outlined,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PuzzleBreakdownCard extends StatelessWidget {
  const _PuzzleBreakdownCard({required this.summaries});

  final List<ProfilePuzzleSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final AppSpacing spacing =
        Theme.of(context).extension<AppSpacing>() ?? const AppSpacing();

    return BrainiaxCard(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Puzzle Breakdown',
            subtitle:
                'Completion counts and best times where local data exists.',
          ),
          SizedBox(height: spacing.m),
          ...[
            for (int index = 0; index < summaries.length; index++) ...[
              _PuzzleSummaryTile(summary: summaries[index]),
              if (index != summaries.length - 1) SizedBox(height: spacing.s),
            ],
          ],
        ],
      ),
    );
  }
}

class _PuzzleSummaryTile extends StatelessWidget {
  const _PuzzleSummaryTile({required this.summary});

  final ProfilePuzzleSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();

    return BrainiaxCard(
      key: ValueKey('profile-puzzle-${summary.puzzleType.key}'),
      padding: EdgeInsets.all(spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PuzzleIconBadge(
                icon: _puzzleIcon(summary.puzzleType),
                accentColor: _puzzleAccent(summary.puzzleType),
                size: 46,
                borderRadius: 16,
              ),
              SizedBox(width: spacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.puzzleType.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      '${summary.totalCompletions} completions',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                summary.bestTime == null
                    ? '--'
                    : _formatDuration(summary.bestTime),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.s),
          Wrap(
            spacing: spacing.s,
            runSpacing: spacing.s,
            children: [
              _MetricChip(label: '${summary.randomCompletions} random'),
              _MetricChip(label: '${summary.dailyCompletions} daily'),
              _MetricChip(
                label: summary.bestTime == null
                    ? 'Best time unavailable'
                    : 'Best ${_formatDuration(summary.bestTime)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _FutureAccountCopyCard extends StatelessWidget {
  const _FutureAccountCopyCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();

    return BrainiaxCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline),
          SizedBox(width: spacing.m),
          Expanded(
            child: Text(
              'More account tools will appear here when they are available. Until then, profile stats and streaks stay usable offline on this device.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountUpgradePromptCard extends ConsumerStatefulWidget {
  const _AccountUpgradePromptCard();

  @override
  ConsumerState<_AccountUpgradePromptCard> createState() =>
      _AccountUpgradePromptCardState();
}

class _AccountUpgradePromptCardState
    extends ConsumerState<_AccountUpgradePromptCard> {
  bool _isDismissing = false;

  @override
  Widget build(BuildContext context) {
    final AccountUpgradePromptEligibility prompt = ref.watch(
      accountUpgradePromptEligibilityProvider,
    );
    if (!prompt.shouldShow) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();

    return BrainiaxCard(
      emphasized: true,
      backgroundColor: const Color(0xFFFFF7E8),
      borderColor: const Color(0xFFF1D08A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.upgrade_outlined, color: colorScheme.primary),
              SizedBox(width: spacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Save progress with an account',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      'You can keep playing anonymously. This reminder appears after a few completions or a streak milestone, and it never blocks gameplay.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.m),
          Wrap(
            spacing: spacing.s,
            runSpacing: spacing.s,
            children: [
              _MetricChip(label: '${prompt.totalCompletions} completions'),
              _MetricChip(label: '${prompt.currentDailyStreak} day streak'),
              const _MetricChip(label: 'Dismiss for 7 days'),
            ],
          ),
          SizedBox(height: spacing.m),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isDismissing ? null : _handleDismiss,
              child: Text(_isDismissing ? 'Dismissing...' : 'Dismiss'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDismiss() async {
    setState(() {
      _isDismissing = true;
    });

    try {
      await ref.read(accountUpgradePromptControllerProvider).dismiss();
    } finally {
      if (mounted) {
        setState(() {
          _isDismissing = false;
        });
      }
    }
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final AppSpacing spacing =
        Theme.of(context).extension<AppSpacing>() ?? const AppSpacing();

    return ListView(
      padding: EdgeInsets.all(spacing.l),
      children: [
        const EmptyStateCard(
          title: 'Profile is unavailable',
          body:
              'The dashboard could not load right now. Your local progress is still stored on this device.',
          icon: Icons.person_off_outlined,
        ),
        SizedBox(height: spacing.l),
        BrainiaxCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            subtitle: const Text('Open app preferences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenSettings,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

String _accountLabel(ProfileAccountState state) {
  switch (state) {
    case ProfileAccountState.guest:
      return 'Guest';
    case ProfileAccountState.anonymous:
      return 'Anonymous';
    case ProfileAccountState.signedIn:
      return 'Signed in';
  }
}

IconData _accountIcon(ProfileAccountState state) {
  switch (state) {
    case ProfileAccountState.guest:
      return Icons.person_off_outlined;
    case ProfileAccountState.anonymous:
      return Icons.person_outline;
    case ProfileAccountState.signedIn:
      return Icons.verified_user_outlined;
  }
}

String _accountCopy(ProfileDashboardData dashboard) {
  switch (dashboard.accountState) {
    case ProfileAccountState.guest:
      return dashboard.authAvailable
          ? 'You are playing as a guest right now. Local progress is available immediately, and cloud sync can attach once account services are active.'
          : 'You are playing locally on this device. Account services are not available in this build, so progress stays offline-first.';
    case ProfileAccountState.anonymous:
      return 'You have an anonymous account. Local stats remain the source of truth while pending cloud sync catches up.';
    case ProfileAccountState.signedIn:
      return 'Your puzzle history is connected to a signed-in account. Local stats still load first so Profile works offline.';
  }
}

String _syncLabel(ProfileSyncState state) {
  switch (state) {
    case ProfileSyncState.localOnly:
      return 'Local only';
    case ProfileSyncState.upToDate:
      return 'Up to date';
    case ProfileSyncState.pending:
      return 'Sync pending';
    case ProfileSyncState.error:
      return 'Sync error';
  }
}

IconData _syncIcon(ProfileSyncState state) {
  switch (state) {
    case ProfileSyncState.localOnly:
      return Icons.cloud_off_outlined;
    case ProfileSyncState.upToDate:
      return Icons.cloud_done_outlined;
    case ProfileSyncState.pending:
      return Icons.cloud_upload_outlined;
    case ProfileSyncState.error:
      return Icons.error_outline;
  }
}

Color _syncPillColor(ProfileSyncState state) {
  switch (state) {
    case ProfileSyncState.localOnly:
      return const Color(0xFF324764);
    case ProfileSyncState.upToDate:
      return const Color(0xFFE6F6EA);
    case ProfileSyncState.pending:
      return const Color(0xFFFFF4D7);
    case ProfileSyncState.error:
      return const Color(0xFFFDE2E1);
  }
}

Color _syncPillForeground(ProfileSyncState state) {
  switch (state) {
    case ProfileSyncState.localOnly:
      return Colors.white;
    case ProfileSyncState.upToDate:
      return const Color(0xFF176A3A);
    case ProfileSyncState.pending:
      return const Color(0xFF9A5B00);
    case ProfileSyncState.error:
      return const Color(0xFFAD2E24);
  }
}

String _syncCopy(ProfileSyncSummary summary) {
  switch (summary.state) {
    case ProfileSyncState.localOnly:
      return 'Cloud sync is unavailable right now. Offline stats and streaks continue to update locally.';
    case ProfileSyncState.upToDate:
      return 'No pending sync work. Local profile data and queued cloud state are aligned.';
    case ProfileSyncState.pending:
      final String itemLabel = summary.pendingCount == 1 ? 'item' : 'items';
      return '${summary.pendingCount} $itemLabel waiting to sync. Local progress is already saved on this device.';
    case ProfileSyncState.error:
      final String itemLabel = summary.failedCount == 1
          ? 'item needs'
          : 'items need';
      return '${summary.failedCount} $itemLabel retry before cloud sync is current. Local stats are still safe.';
  }
}

String _syncResultMessage(SyncEngineResult result) {
  if (result.retryFailed && result.attempted == 0) {
    return 'Could not retry failed sync items right now. Local stats are still safe.';
  }

  if (result.skipped) {
    switch (result.skippedReason) {
      case 'already-processing':
        return 'Sync is already running.';
      case 'auth-unavailable':
        return 'Sync could not start because account auth is unavailable.';
      case 'firestore-unavailable':
        return 'Cloud sync is unavailable right now.';
      default:
        return 'Sync was skipped.';
    }
  }

  if (result.attempted == 0) {
    if (result.retriedFailed > 0) {
      return 'Retried ${result.retriedFailed} failed item${result.retriedFailed == 1 ? '' : 's'}; nothing else is pending.';
    }
    return 'Nothing to sync right now.';
  }
  if (result.failed == 0) {
    if (result.retriedFailed > 0) {
      return 'Retried ${result.retriedFailed} failed item${result.retriedFailed == 1 ? '' : 's'} and synced ${result.synced} item${result.synced == 1 ? '' : 's'}.';
    }
    return 'Synced ${result.synced} item${result.synced == 1 ? '' : 's'}.';
  }
  if (result.synced == 0) {
    return 'Sync failed for ${result.failed} item${result.failed == 1 ? '' : 's'}.';
  }
  return 'Synced ${result.synced} item${result.synced == 1 ? '' : 's'}; ${result.failed} still need attention.';
}

String _googleSignInResultMessage(GoogleSignInResult result) {
  switch (result.status) {
    case GoogleSignInResultStatus.linked:
      return 'Google account connected. Your existing progress stayed attached.';
    case GoogleSignInResultStatus.signedIn:
      return 'Signed in with Google. You can keep playing normally.';
    case GoogleSignInResultStatus.cancelled:
      return '';
    case GoogleSignInResultStatus.recoverableFailure:
      return result.failure?.message ??
          'Google sign-in could not finish. You can keep playing normally.';
  }
}

String _appleSignInResultMessage(AppleSignInResult result) {
  switch (result.status) {
    case AppleSignInResultStatus.linked:
      return 'Apple account connected. Your existing progress stayed attached.';
    case AppleSignInResultStatus.signedIn:
      return 'Signed in with Apple. You can keep playing normally.';
    case AppleSignInResultStatus.cancelled:
      return '';
    case AppleSignInResultStatus.recoverableFailure:
      return result.failure?.message ??
          'Apple sign-in could not finish. You can keep playing normally.';
  }
}

bool _supportsAppleSignIn() {
  if (kIsWeb) {
    return false;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return false;
  }
}

String _formatDuration(Duration? duration) {
  if (duration == null) {
    return '--';
  }

  final int totalSeconds = duration.inSeconds;
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

IconData _puzzleIcon(PuzzleType puzzleType) {
  switch (puzzleType) {
    case PuzzleType.sudokuClassic:
      return Icons.grid_on;
    case PuzzleType.nonogramMono:
      return Icons.crop_square;
    case PuzzleType.kakuro:
      return Icons.add_box;
    case PuzzleType.slitherlinkLoop:
      return Icons.circle_outlined;
    case PuzzleType.mathdokuClassic:
      return Icons.calculate;
    case PuzzleType.killerQueens:
      return Icons.catching_pokemon;
    case PuzzleType.takuzuBinary:
      return Icons.code;
  }
}

Color _puzzleAccent(PuzzleType puzzleType) {
  switch (puzzleType) {
    case PuzzleType.sudokuClassic:
      return const Color(0xFF2196F3);
    case PuzzleType.nonogramMono:
      return const Color(0xFF4CAF50);
    case PuzzleType.kakuro:
      return const Color(0xFFFF9800);
    case PuzzleType.slitherlinkLoop:
      return const Color(0xFF9C27B0);
    case PuzzleType.mathdokuClassic:
      return const Color(0xFFE91E63);
    case PuzzleType.killerQueens:
      return const Color(0xFF26C6DA);
    case PuzzleType.takuzuBinary:
      return const Color(0xFF607D8B);
  }
}
