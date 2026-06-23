import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/models.dart';
import '../../shared/navigation/app_routes.dart';
import '../../shared/providers/puzzle_local_store_providers.dart';
import '../../shared/services/puzzle_registry.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/active_run_card.dart';
import '../../shared/widgets/brainiax/brainiax_widgets.dart';
import '../select/puzzle_detail_sheet.dart';
import '../select/puzzle_launch_actions.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PuzzleRegistry _registry = PuzzleRegistry();
  late final Map<PuzzleType, PuzzleMetadata> _metadataByType;
  int _brandTapCount = 0;
  DateTime? _lastBrandTapAt;

  @override
  void initState() {
    super.initState();
    _registry.initialize();
    _metadataByType = <PuzzleType, PuzzleMetadata>{
      for (final metadata in _registry.getAllPuzzleMetadata())
        metadata.type: metadata,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppSpacing spacing =
        Theme.of(context).extension<AppSpacing>() ?? const AppSpacing();
    final AsyncValue<DailyStreakStatus> streakAsync = ref.watch(
      dailyStreakStatusProvider,
    );
    final AsyncValue<ActivePuzzleRun?> latestActiveRunAsync = ref.watch(
      latestActiveRunProvider,
    );
    final AsyncValue<HomeStatsSnapshot> homeStatsAsync = ref.watch(
      homeStatsProvider,
    );
    final DateTime nowUtc = ref.watch(dailyNowProvider);
    final String todayKey = DailyUtcDate.todayKey(now: nowUtc);
    final AsyncValue<PuzzleType?> nextDailyTypeAsync = ref.watch(
      nextUncompletedDailyPuzzleTypeProvider(todayKey),
    );
    final AsyncValue<List<PuzzleType>> favouritesAsync = ref.watch(
      favouritePuzzleTypesProvider,
    );

    final _DailyChallengeView dailyView = _buildDailyChallengeView(
      nextDailyTypeAsync,
    );
    final PuzzleMetadata? dailyMetadata = dailyView.puzzleType == null
        ? null
        : _metadataByType[dailyView.puzzleType!];
    final HomeStatsSnapshot? stats = homeStatsAsync.asData?.value;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          spacing.l,
          spacing.m,
          spacing.l,
          spacing.xl,
        ),
        children: [
          _HomeHeader(
            streak: streakAsync.asData?.value.currentStreak,
            onBrandTap: _handleBrandTap,
            onOpenSettings: () => context.push(AppRoutes.settings),
          ),
          SizedBox(height: spacing.l),
          _TodayChallengeCard(
            view: dailyView,
            metadata: dailyMetadata,
            onPressed: () => _openDailyChallenge(dailyView),
          ),
          SizedBox(height: spacing.l),
          latestActiveRunAsync.when(
            data: (run) {
              if (run == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: EdgeInsets.only(bottom: spacing.l),
                child: ActiveRunCard(
                  run: run,
                  title: 'Continue',
                  subtitle: run.puzzleType.displayName,
                  onResume: () => resumePuzzleRun(
                    context: context,
                    ref: ref,
                    puzzleType: run.puzzleType,
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
          _QuickPlaySection(
            favouritesAsync: favouritesAsync,
            metadataByType: _metadataByType,
            onOpenRandom: () => context.go(AppRoutes.puzzles),
            onOpenFavourite: _openFavourite,
          ),
          SizedBox(height: spacing.l),
          if (!homeStatsAsync.hasError)
            _StatsPreviewCard(
              stats: stats,
              onTap: () => context.go(AppRoutes.profile),
            ),
        ],
      ),
    );
  }

  _DailyChallengeView _buildDailyChallengeView(
    AsyncValue<PuzzleType?> nextDailyTypeAsync,
  ) {
    return nextDailyTypeAsync.when(
      data: (puzzleType) {
        if (puzzleType == null) {
          return const _DailyChallengeView(
            title: 'Daily Challenge',
            supportingCopy:
                'Today\'s set is complete. Review your solved puzzles before the next UTC reset.',
            actionLabel: 'View Daily',
            action: _DailyChallengeAction.viewDaily,
          );
        }
        return _DailyChallengeView(
          puzzleType: puzzleType,
          title: puzzleType.displayName,
          supportingCopy:
              'Continue today\'s shared challenge set before the UTC reset.',
          actionLabel: 'Open Daily Challenge',
          action: _DailyChallengeAction.openPuzzle,
        );
      },
      loading: () => const _DailyChallengeView(
        title: 'Daily Challenge',
        supportingCopy:
            'Checking today\'s next puzzle. Open the daily hub while the set loads.',
        actionLabel: 'Open Daily',
        action: _DailyChallengeAction.viewDaily,
      ),
      error: (error, stackTrace) => const _DailyChallengeView(
        title: 'Daily Challenge',
        supportingCopy:
            'Open today\'s challenge hub to see what is still available before reset.',
        actionLabel: 'Open Daily',
        action: _DailyChallengeAction.viewDaily,
      ),
    );
  }

  void _openDailyChallenge(_DailyChallengeView view) {
    if (view.action == _DailyChallengeAction.openPuzzle) {
      final PuzzleType? puzzleType = view.puzzleType;
      if (puzzleType != null) {
        context.push(AppRoutes.play(puzzleType.key, PuzzleMode.daily.key));
        return;
      }
    }

    context.go(AppRoutes.daily);
  }

  void _openFavourite(AsyncValue<List<PuzzleType>> favouritesAsync) {
    final List<PuzzleType>? favourites = favouritesAsync.asData?.value;
    if (favourites == null || favourites.isEmpty) {
      context.go(AppRoutes.puzzles);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pick a favourite in Puzzle Library to launch it fast.',
          ),
        ),
      );
      return;
    }

    final PuzzleMetadata? metadata = _metadataByType[favourites.first];
    if (metadata == null) {
      context.go(AppRoutes.puzzles);
      return;
    }

    unawaited(showPuzzleDetailSheet(context: context, metadata: metadata));
  }

  void _handleBrandTap() {
    final DateTime now = DateTime.now();
    if (_lastBrandTapAt != null &&
        now.difference(_lastBrandTapAt!).inSeconds < 2) {
      _brandTapCount += 1;
    } else {
      _brandTapCount = 1;
    }
    _lastBrandTapAt = now;

    if (_brandTapCount >= 5) {
      _brandTapCount = 0;
      context.push(AppRoutes.bench);
    }
  }
}

enum _DailyChallengeAction { openPuzzle, viewDaily }

class _DailyChallengeView {
  const _DailyChallengeView({
    required this.title,
    required this.supportingCopy,
    required this.actionLabel,
    required this.action,
    this.puzzleType,
  });

  final PuzzleType? puzzleType;
  final String title;
  final String supportingCopy;
  final String actionLabel;
  final _DailyChallengeAction action;
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.streak,
    required this.onBrandTap,
    required this.onOpenSettings,
  });

  final int? streak;
  final VoidCallback onBrandTap;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();
    final String streakLabel = streak == null ? '--' : '$streak';

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBrandTap,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14213D),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.extension_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                SizedBox(width: spacing.m),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Brainiax',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F2D4A),
                      ),
                    ),
                    Text(
                      'Puzzles',
                      style: theme.textTheme.labelLarge?.copyWith(
                        letterSpacing: 0.8,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: spacing.s),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6D8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF3D06B)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department_outlined,
                size: 16,
                color: Color(0xFFF4A100),
              ),
              const SizedBox(width: 6),
              Text(
                streakLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFB26A00),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: spacing.xs),
        IconButton(
          onPressed: onOpenSettings,
          tooltip: 'Settings',
          icon: Icon(
            Icons.settings_outlined,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TodayChallengeCard extends StatelessWidget {
  const _TodayChallengeCard({
    required this.view,
    required this.metadata,
    required this.onPressed,
  });

  final _DailyChallengeView view;
  final PuzzleMetadata? metadata;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();
    final bool hasPuzzleMetadata = metadata != null;
    const Color backgroundColor = Color(0xFF162846);
    const Color outlineColor = Color(0xFF223A61);
    const Color mutedTextColor = Color(0xFFAAB6CC);
    const Color surfaceColor = Color(0xFF2A3E61);

    return BrainiaxCard(
      backgroundColor: backgroundColor,
      borderColor: outlineColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Challenge',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            'UTC reset drives the next daily puzzle.',
            style: theme.textTheme.bodyMedium?.copyWith(color: mutedTextColor),
          ),
          SizedBox(height: spacing.m),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(spacing.l),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF324B74)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PuzzleIconBadge(
                  metadata: metadata,
                  icon: hasPuzzleMetadata
                      ? null
                      : Icons.calendar_today_outlined,
                  accentColor: hasPuzzleMetadata
                      ? null
                      : const Color(0xFF7D8CFF),
                  size: 60,
                  borderRadius: 20,
                ),
                SizedBox(width: spacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        view.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: spacing.xs),
                      Text(
                        view.supportingCopy,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: mutedTextColor,
                        ),
                      ),
                      SizedBox(height: spacing.s),
                      Text(
                        metadata?.description ??
                            'Play the shared daily puzzle set and keep your streak moving.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFD6DDED),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: spacing.m),
          const _ResetCountdownBanner(
            prefix: 'Resets in ',
            backgroundColor: Color(0xFF223555),
            foregroundColor: Colors.white,
            iconColor: Color(0xFFFFC857),
          ),
          SizedBox(height: spacing.l),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7A400),
                foregroundColor: const Color(0xFF14213D),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: Icon(
                view.action == _DailyChallengeAction.openPuzzle
                    ? Icons.play_arrow
                    : Icons.calendar_today_outlined,
              ),
              label: Text(view.actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPlaySection extends StatelessWidget {
  const _QuickPlaySection({
    required this.favouritesAsync,
    required this.metadataByType,
    required this.onOpenRandom,
    required this.onOpenFavourite,
  });

  final AsyncValue<List<PuzzleType>> favouritesAsync;
  final Map<PuzzleType, PuzzleMetadata> metadataByType;
  final VoidCallback onOpenRandom;
  final ValueChanged<AsyncValue<List<PuzzleType>>> onOpenFavourite;

  @override
  Widget build(BuildContext context) {
    final AppSpacing spacing =
        Theme.of(context).extension<AppSpacing>() ?? const AppSpacing();
    final List<PuzzleType>? favourites = favouritesAsync.asData?.value;
    final PuzzleMetadata? favouriteMetadata =
        favourites == null || favourites.isEmpty
        ? null
        : metadataByType[favourites.first];
    final String favouriteSubtitle = favourites == null
        ? 'Checking your favourites'
        : favouriteMetadata?.displayName ?? 'Pick one in Puzzle Library';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Play',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: spacing.m),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool twoColumn = constraints.maxWidth >= 520;
            final List<Widget> buttons = [
              _QuickPlayButton(
                icon: Icons.casino_outlined,
                title: 'Random',
                subtitle: 'Surprise me',
                onTap: onOpenRandom,
              ),
              _QuickPlayButton(
                icon: Icons.star_outline,
                title: 'Favourite Puzzle',
                subtitle: favouriteSubtitle,
                onTap: () => onOpenFavourite(favouritesAsync),
              ),
            ];

            if (twoColumn) {
              return Row(
                children: [
                  Expanded(child: buttons[0]),
                  SizedBox(width: spacing.m),
                  Expanded(child: buttons[1]),
                ],
              );
            }

            return Column(
              children: [
                buttons[0],
                SizedBox(height: spacing.m),
                buttons[1],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _QuickPlayButton extends StatelessWidget {
  const _QuickPlayButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();

    return BrainiaxCard(
      emphasized: true,
      onTap: onTap,
      borderRadius: 22,
      child: Row(
        children: [
          PuzzleIconBadge(
            icon: icon,
            accentColor: colorScheme.primary,
            size: 48,
            borderRadius: 16,
          ),
          SizedBox(width: spacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: spacing.s),
          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _StatsPreviewCard extends StatelessWidget {
  const _StatsPreviewCard({required this.stats, required this.onTap});

  final HomeStatsSnapshot? stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppSpacing spacing =
        Theme.of(context).extension<AppSpacing>() ?? const AppSpacing();

    return BrainiaxCard(
      emphasized: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Your Stats',
            subtitle: 'Tap through to Profile for the full breakdown.',
            trailing: Icon(Icons.arrow_outward),
          ),
          SizedBox(height: spacing.m),
          LayoutBuilder(
            builder: (context, constraints) {
              final double itemWidth = constraints.maxWidth >= 440
                  ? (constraints.maxWidth - (spacing.s * 2)) / 3
                  : (constraints.maxWidth - spacing.s) / 2;
              final List<Widget> tiles = [
                SizedBox(
                  width: itemWidth,
                  child: StatTile(
                    label: 'Total Solved',
                    value: stats?.totalSolved.toString() ?? '--',
                    icon: Icons.emoji_events_outlined,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: StatTile(
                    label: 'Today Completed',
                    value: stats?.todayCompleted.toString() ?? '--',
                    icon: Icons.today_outlined,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: StatTile(
                    label: 'Completed This Week',
                    value: stats?.completedThisWeek.toString() ?? '--',
                    icon: Icons.calendar_view_week_outlined,
                  ),
                ),
              ];

              return Wrap(
                spacing: spacing.s,
                runSpacing: spacing.s,
                children: tiles,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ResetCountdownBanner extends StatelessWidget {
  const _ResetCountdownBanner({
    required this.prefix,
    this.backgroundColor,
    this.foregroundColor,
    this.iconColor,
  });

  final String prefix;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return StreamBuilder<int>(
      stream: Stream<int>.periodic(
        const Duration(minutes: 1),
        (count) => count,
      ).startWith(0),
      builder: (context, snapshot) {
        final Duration duration = DailyUtcDate.timeUntilReset();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor ?? colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 18,
                color: iconColor ?? theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$prefix${_formatCountdown(duration)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foregroundColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}

String _formatCountdown(Duration duration) {
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}
