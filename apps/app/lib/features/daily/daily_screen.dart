import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/models.dart';
import '../../shared/navigation/app_routes.dart';
import '../../shared/services/puzzle_registry.dart';
import '../../shared/widgets/brainiax/brainiax_widgets.dart';
import 'daily_hub_provider.dart';

enum DailyPuzzleFilter { all, unplayed, completed }

class DailyScreen extends ConsumerStatefulWidget {
  const DailyScreen({super.key});

  @override
  ConsumerState<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends ConsumerState<DailyScreen> {
  final PuzzleRegistry _registry = PuzzleRegistry();
  late final Map<PuzzleType, PuzzleMetadata> _metadataByType;
  DailyPuzzleFilter _filter = DailyPuzzleFilter.all;

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
    final AsyncValue<DailyHubViewData> hubAsync = ref.watch(dailyHubProvider);

    return hubAsync.when(
      data: (view) => _DailyHubContent(
        view: view,
        filter: _filter,
        metadataByType: _metadataByType,
        onFilterChanged: (filter) {
          setState(() {
            _filter = filter;
          });
        },
      ),
      loading: () => const _DailyLoadingState(),
      error: (error, stackTrace) =>
          _DailyErrorState(onRetry: () => ref.invalidate(dailyHubProvider)),
    );
  }
}

class _DailyHubContent extends StatelessWidget {
  const _DailyHubContent({
    required this.view,
    required this.filter,
    required this.metadataByType,
    required this.onFilterChanged,
  });

  final DailyHubViewData view;
  final DailyPuzzleFilter filter;
  final Map<PuzzleType, PuzzleMetadata> metadataByType;
  final ValueChanged<DailyPuzzleFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<DailyHubPuzzleEntry> visibleEntries = _filteredEntries();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DailyHeader(
          countdownText: _formatResetCountdown(view.timeUntilReset),
          streakCount: view.streakCount,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This Week',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _WeeklyCalendarStrip(week: view.week),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _DailyStatusCard(
          card: view.statusCard,
          countdownText: _formatResetCountdown(view.timeUntilReset),
          onPressed: view.statusCard.isActionEnabled
              ? () => _openRandomUncompletedPuzzle(context, view)
              : null,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Today\'s Puzzles',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${view.completedCount}/${view.totalCount} done',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilterChipRow<DailyPuzzleFilter>(
          selectedValue: filter,
          onSelected: onFilterChanged,
          options: DailyPuzzleFilter.values
              .map(
                (value) =>
                    FilterChipOption(value: value, label: _filterLabel(value)),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        if (visibleEntries.isEmpty)
          const EmptyStateCard(
            title: 'No puzzles match this filter',
            body:
                'Try a different daily filter to see the rest of today\'s set.',
            icon: Icons.filter_list_off,
          )
        else
          ...visibleEntries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DailyPuzzleCard(
                entry: entry,
                metadata: metadataByType[entry.puzzleType],
                onPressed: () => context.push(
                  AppRoutes.play(entry.puzzleType.key, PuzzleMode.daily.key),
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
        Text(
          'Today\'s set stays playable offline once opened.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  List<DailyHubPuzzleEntry> _filteredEntries() {
    switch (filter) {
      case DailyPuzzleFilter.all:
        return view.entries;
      case DailyPuzzleFilter.unplayed:
        return view.entries.where((entry) => !entry.isCompleted).toList();
      case DailyPuzzleFilter.completed:
        return view.entries.where((entry) => entry.isCompleted).toList();
    }
  }

  void _openRandomUncompletedPuzzle(
    BuildContext context,
    DailyHubViewData view,
  ) {
    if (view.uncompletedPuzzleTypes.isEmpty) {
      return;
    }
    final PuzzleType puzzleType =
        view.uncompletedPuzzleTypes[Random().nextInt(
          view.uncompletedPuzzleTypes.length,
        )];
    context.push(AppRoutes.play(puzzleType.key, PuzzleMode.daily.key));
  }
}

class _DailyHeader extends StatelessWidget {
  const _DailyHeader({required this.countdownText, required this.streakCount});

  final String countdownText;
  final int streakCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String streakLabel = '$streakCount day streak';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Challenges',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Today\'s set · Resets in $countdownText',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_outlined, size: 18),
              const SizedBox(width: 6),
              Text(
                streakLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyCalendarStrip extends StatelessWidget {
  const _WeeklyCalendarStrip({required this.week});

  final List<DailyHubWeekday> week;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: week
          .map((day) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _WeeklyCalendarDay(day: day),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _WeeklyCalendarDay extends StatelessWidget {
  const _WeeklyCalendarDay({required this.day});

  final DailyHubWeekday day;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final _CalendarVisual visual = _calendarVisual(colorScheme, day.state);

    return Container(
      key: ValueKey('daily-weekday-${day.dateKeyUtc}-${day.state.name}'),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: visual.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: visual.borderColor,
          width:
              day.state == DailyHubWeekdayState.todayIncomplete ||
                  day.state == DailyHubWeekdayState.todayCompleted
              ? 1.5
              : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            day.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: visual.foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Icon(visual.icon, size: 18, color: visual.foregroundColor),
        ],
      ),
    );
  }
}

class _DailyStatusCard extends StatelessWidget {
  const _DailyStatusCard({
    required this.card,
    required this.countdownText,
    required this.onPressed,
  });

  final DailyHubStatusCard card;
  final String countdownText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(card.body),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_outlined, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Next set in $countdownText',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                child: Text(card.ctaLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyPuzzleCard extends StatelessWidget {
  const _DailyPuzzleCard({
    required this.entry,
    required this.metadata,
    required this.onPressed,
  });

  final DailyHubPuzzleEntry entry;
  final PuzzleMetadata? metadata;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color accentColor =
        metadata?.primaryAccentColor ?? colorScheme.primary;
    final IconData icon = metadata?.icon ?? Icons.extension_outlined;
    final String subtitle = switch (entry.cardState) {
      DailyHubCardState.play => 'Ready for today\'s challenge',
      DailyHubCardState.resume => 'In progress',
      DailyHubCardState.completed =>
        entry.solvedDuration == null
            ? 'Completed'
            : 'Solved in ${_formatSolveDuration(entry.solvedDuration!)}',
    };
    final String actionLabel = switch (entry.cardState) {
      DailyHubCardState.play => 'Play',
      DailyHubCardState.resume => 'Resume',
      DailyHubCardState.completed => 'View',
    };

    return Card(
      child: InkWell(
        key: ValueKey('daily-puzzle-${entry.puzzleType.key}'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.puzzleType.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _InfoPill(
                          text: entry.difficultyLabel,
                          icon: Icons.tune,
                        ),
                        if (entry.cardState == DailyHubCardState.resume)
                          const _InfoPill(
                            text: 'Saved run',
                            icon: Icons.play_circle_outline,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: onPressed, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text, required this.icon});

  final String text;
  final IconData icon;

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(text, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _DailyLoadingState extends StatelessWidget {
  const _DailyLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Loading daily challenge status...'),
        ],
      ),
    );
  }
}

class _DailyErrorState extends StatelessWidget {
  const _DailyErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 12),
            const Text(
              'Unable to load daily challenges right now.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

class _CalendarVisual {
  const _CalendarVisual({
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
}

_CalendarVisual _calendarVisual(
  ColorScheme colorScheme,
  DailyHubWeekdayState state,
) {
  switch (state) {
    case DailyHubWeekdayState.completed:
      return _CalendarVisual(
        icon: Icons.check,
        backgroundColor: Colors.green.withValues(alpha: 0.12),
        borderColor: Colors.green.withValues(alpha: 0.28),
        foregroundColor: Colors.green.shade700,
      );
    case DailyHubWeekdayState.missed:
      return _CalendarVisual(
        icon: Icons.close,
        backgroundColor: colorScheme.errorContainer,
        borderColor: colorScheme.error.withValues(alpha: 0.3),
        foregroundColor: colorScheme.onErrorContainer,
      );
    case DailyHubWeekdayState.todayIncomplete:
      return _CalendarVisual(
        icon: Icons.radio_button_unchecked,
        backgroundColor: colorScheme.surface,
        borderColor: colorScheme.primary,
        foregroundColor: colorScheme.primary,
      );
    case DailyHubWeekdayState.todayCompleted:
      return _CalendarVisual(
        icon: Icons.check,
        backgroundColor: Colors.green.withValues(alpha: 0.16),
        borderColor: Colors.green.shade600,
        foregroundColor: Colors.green.shade700,
      );
    case DailyHubWeekdayState.future:
      return _CalendarVisual(
        icon: Icons.remove,
        backgroundColor: colorScheme.surfaceContainerHighest,
        borderColor: colorScheme.outlineVariant,
        foregroundColor: colorScheme.onSurfaceVariant,
      );
    case DailyHubWeekdayState.unknown:
      return _CalendarVisual(
        icon: Icons.help_outline,
        backgroundColor: colorScheme.surfaceContainerHighest,
        borderColor: colorScheme.outlineVariant,
        foregroundColor: colorScheme.onSurfaceVariant,
      );
  }
}

String _filterLabel(DailyPuzzleFilter filter) {
  switch (filter) {
    case DailyPuzzleFilter.all:
      return 'All';
    case DailyPuzzleFilter.unplayed:
      return 'Unplayed';
    case DailyPuzzleFilter.completed:
      return 'Completed';
  }
}

String _formatResetCountdown(Duration duration) {
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}

String _formatSolveDuration(Duration duration) {
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  final int seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}
