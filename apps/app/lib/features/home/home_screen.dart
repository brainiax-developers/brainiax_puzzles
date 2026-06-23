import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/models.dart';
import '../../shared/navigation/app_routes.dart';
import '../../shared/providers/puzzle_local_store_providers.dart';
import '../../shared/services/puzzle_registry.dart';
import '../../shared/widgets/brainiax/brainiax_widgets.dart';
import '../../shared/widgets/active_run_card.dart';
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
    final AsyncValue<ActivePuzzleRun?> latestActiveRunAsync = ref.watch(
      latestActiveRunProvider,
    );
    final AsyncValue<HomeStatsSnapshot> homeStatsAsync = ref.watch(
      homeStatsProvider,
    );
    final String todayKey = DailyUtcDate.todayKey();
    final AsyncValue<PuzzleType?> nextDailyTypeAsync = ref.watch(
      nextUncompletedDailyPuzzleTypeProvider(todayKey),
    );
    final AsyncValue<List<PuzzleType>> favouritesAsync = ref.watch(
      favouritePuzzleTypesProvider,
    );

    final List<PuzzleType> favourites =
        favouritesAsync.asData?.value ?? const [];
    final PuzzleType? nextDailyType = nextDailyTypeAsync.asData?.value;
    final bool hasIncompleteDaily =
        nextDailyTypeAsync.asData == null || nextDailyType != null;
    final PuzzleType heroType =
        nextDailyType ?? PuzzleType.dailyChallengeTypes.first;
    final PuzzleMetadata? heroMetadata = _metadataByType[heroType];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (heroMetadata != null)
          _TodayChallengeCard(
            metadata: heroMetadata,
            hasIncompleteDaily: hasIncompleteDaily,
          ),
        if (heroMetadata != null) const SizedBox(height: 16),
        latestActiveRunAsync.when(
          data: (run) {
            if (run == null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Quick Play'),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool twoColumn = constraints.maxWidth >= 520;
                    final List<Widget> buttons = [
                      _QuickPlayButton(
                        icon: Icons.casino_outlined,
                        title: 'Random',
                        subtitle: 'Surprise me',
                        onTap: () => context.go(AppRoutes.puzzles),
                      ),
                      _QuickPlayButton(
                        icon: Icons.star_outline,
                        title: 'Favourite Puzzle',
                        subtitle: favourites.isEmpty
                            ? 'Pick one in the library'
                            : favourites.first.displayName,
                        onTap: () => _openFavourite(favourites),
                      ),
                    ];

                    if (twoColumn) {
                      return Row(
                        children: [
                          Expanded(child: buttons[0]),
                          const SizedBox(width: 12),
                          Expanded(child: buttons[1]),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        buttons[0],
                        const SizedBox(height: 12),
                        buttons[1],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        homeStatsAsync.when(
          data: (stats) => InkWell(
            onTap: () => context.go(AppRoutes.profile),
            borderRadius: BorderRadius.circular(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Your Stats'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: 'Total Solved',
                            value: stats.totalSolved.toString(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatTile(
                            label: 'Today Completed',
                            value: stats.todayCompleted.toString(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatTile(
                            label: 'Completed This Week',
                            value: stats.completedThisWeek.toString(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 72,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          error: (error, stackTrace) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _openFavourite(List<PuzzleType> favourites) {
    if (favourites.isEmpty) {
      context.go(AppRoutes.puzzles);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Star a puzzle to add a favourite first.'),
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
}

class _TodayChallengeCard extends ConsumerWidget {
  const _TodayChallengeCard({
    required this.metadata,
    required this.hasIncompleteDaily,
  });

  final PuzzleMetadata metadata;
  final bool hasIncompleteDaily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Challenge',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                PuzzleIconBadge(metadata: metadata, size: 44, borderRadius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metadata.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasIncompleteDaily
                            ? 'Daily difficulty set for today'
                            : 'All daily puzzles completed',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(metadata.description),
            const SizedBox(height: 12),
            const _ResetCountdownBanner(prefix: 'Resets in '),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (hasIncompleteDaily) {
                    context.push(
                      AppRoutes.play(metadata.type.key, PuzzleMode.daily.key),
                    );
                  } else {
                    context.go(AppRoutes.daily);
                  }
                },
                child: Text(
                  hasIncompleteDaily ? 'Open Daily Challenge' : 'View Daily',
                ),
              ),
            ),
          ],
        ),
      ),
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetCountdownBanner extends StatelessWidget {
  const _ResetCountdownBanner({required this.prefix});

  final String prefix;

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
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$prefix${_formatCountdown(duration)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
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
