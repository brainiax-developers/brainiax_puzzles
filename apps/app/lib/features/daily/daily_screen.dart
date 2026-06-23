import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/models.dart';
import '../../shared/navigation/app_routes.dart';
import '../../shared/services/puzzle_registry.dart';
import '../../shared/theme/app_theme.dart';
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

    return SafeArea(
      bottom: false,
      child: hubAsync.when(
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
      ),
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
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();
    final List<DailyHubPuzzleEntry> visibleEntries = _filteredEntries();
    final String countdownText = _formatResetCountdown(view.timeUntilReset);
    final DailyHubWeekday? today = _currentWeekday(view.week);

    return ListView(
      padding: EdgeInsets.fromLTRB(spacing.l, spacing.m, spacing.l, spacing.xl),
      children: [
        _DailyHeroHeader(
          subtitle: _headerSubtitle(today, countdownText),
          streakCount: view.streakCount,
        ),
        SizedBox(height: spacing.l),
        _WeeklyProgressCard(week: view.week),
        SizedBox(height: spacing.l),
        _DailyStatusCard(
          card: view.statusCard,
          countdownText: countdownText,
          onPressed: view.statusCard.isActionEnabled
              ? () => _openRandomUncompletedPuzzle(context, view)
              : null,
        ),
        SizedBox(height: spacing.xl),
        SectionHeader(
          title: 'Today\'s Puzzles',
          trailing: _ProgressBadge(
            completedCount: view.completedCount,
            totalCount: view.totalCount,
          ),
        ),
        SizedBox(height: spacing.m),
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
        SizedBox(height: spacing.m),
        if (visibleEntries.isEmpty)
          const EmptyStateCard(
            title: 'No puzzles match this filter',
            body:
                'Try a different filter to see the rest of today\'s daily set.',
            icon: Icons.filter_list_off,
          )
        else
          ...visibleEntries.map((entry) {
            return Padding(
              padding: EdgeInsets.only(bottom: spacing.s),
              child: _DailyPuzzleCard(
                entry: entry,
                metadata: metadataByType[entry.puzzleType],
                onPressed: () => context.push(
                  AppRoutes.play(entry.puzzleType.key, PuzzleMode.daily.key),
                ),
              ),
            );
          }),
        SizedBox(height: spacing.s),
        const _OfflineHelperNote(),
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

class _DailyHeroHeader extends StatelessWidget {
  const _DailyHeroHeader({required this.subtitle, required this.streakCount});

  final String subtitle;
  final int streakCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SectionHeader(title: 'Daily Challenges', subtitle: subtitle),
        ),
        const SizedBox(width: 12),
        _StreakBadge(streakCount: streakCount),
      ],
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streakCount});

  final int streakCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      key: const ValueKey('daily-streak-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        '\u{1F525} $streakCount day streak',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({required this.week});

  final List<DailyHubWeekday> week;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();

    return BrainiaxCard(
      emphasized: true,
      child: Column(
        key: const ValueKey('daily-weekly-calendar'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: spacing.s),
              Expanded(
                child: Text(
                  'This Week',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _weekRangeLabel(week),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.m),
          _WeeklyCalendarStrip(week: week),
        ],
      ),
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
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();
    final _CalendarVisual visual = _calendarVisual(
      Theme.of(context).colorScheme,
      day.state,
    );

    return Container(
      key: ValueKey('daily-weekday-${day.dateKeyUtc}-${day.state.name}'),
      padding: EdgeInsets.symmetric(vertical: spacing.xs, horizontal: 2),
      child: Column(
        children: [
          Text(
            _compactWeekdayLabel(day.label),
            style: theme.textTheme.labelSmall?.copyWith(
              color: visual.labelColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: spacing.s),
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: visual.backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: visual.borderColor,
                width: visual.borderWidth,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '${day.dateUtc.day}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: visual.foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (visual.icon != null)
                  Positioned(
                    right: 5,
                    bottom: 4,
                    child: Icon(visual.icon, size: 12, color: visual.iconColor),
                  ),
              ],
            ),
          ),
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
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();
    final bool isEnabled = onPressed != null;
    final Color foregroundColor = colorScheme.onPrimary;

    return BrainiaxCard(
      backgroundColor: colorScheme.primary,
      borderColor: colorScheme.primary.withValues(alpha: 0.72),
      child: Column(
        key: const ValueKey('daily-status-card'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: foregroundColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isEnabled
                      ? Icons.local_fire_department_outlined
                      : Icons.check_circle_outline,
                  color: foregroundColor,
                ),
              ),
              SizedBox(width: spacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      card.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foregroundColor.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.m),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: foregroundColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: foregroundColor.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_outlined, size: 16, color: foregroundColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isEnabled
                        ? 'Resets in $countdownText'
                        : 'Next set in $countdownText',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: spacing.l),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.surface,
                foregroundColor: colorScheme.onSurface,
              ),
              child: Text(card.ctaLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({
    required this.completedCount,
    required this.totalCount,
  });

  final int completedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: colorScheme.tertiary,
          ),
          const SizedBox(width: 6),
          Text(
            '$completedCount/$totalCount done',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.tertiary,
            ),
          ),
        ],
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
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();
    final Color accentColor =
        metadata?.primaryAccentColor ?? colorScheme.primary;
    final String title = metadata?.displayName ?? entry.puzzleType.displayName;
    final String actionLabel = switch (entry.cardState) {
      DailyHubCardState.play => 'Play',
      DailyHubCardState.resume => 'Resume',
      DailyHubCardState.completed => 'View',
    };
    final String subtitle = switch (entry.cardState) {
      DailyHubCardState.play => 'Ready for today\'s challenge',
      DailyHubCardState.resume => 'Saved run ready to resume',
      DailyHubCardState.completed =>
        entry.solvedDuration == null
            ? 'Completed today'
            : 'Solved in ${_formatSolveDuration(entry.solvedDuration!)}',
    };

    return BrainiaxCard(
      onTap: onPressed,
      padding: EdgeInsets.zero,
      child: Container(
        key: ValueKey('daily-puzzle-${entry.puzzleType.key}'),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accentColor, width: 4)),
        ),
        padding: EdgeInsets.all(spacing.m),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool stacked = constraints.maxWidth < 420;
            final Widget actionButton = ElevatedButton(
              onPressed: onPressed,
              child: Text(actionLabel),
            );

            return stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DailyPuzzleCardBody(
                        entry: entry,
                        metadata: metadata,
                        accentColor: accentColor,
                        title: title,
                        subtitle: subtitle,
                      ),
                      SizedBox(height: spacing.m),
                      SizedBox(width: double.infinity, child: actionButton),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _DailyPuzzleCardBody(
                          entry: entry,
                          metadata: metadata,
                          accentColor: accentColor,
                          title: title,
                          subtitle: subtitle,
                        ),
                      ),
                      SizedBox(width: spacing.m),
                      actionButton,
                    ],
                  );
          },
        ),
      ),
    );
  }
}

class _DailyPuzzleCardBody extends StatelessWidget {
  const _DailyPuzzleCardBody({
    required this.entry,
    required this.metadata,
    required this.accentColor,
    required this.title,
    required this.subtitle,
  });

  final DailyHubPuzzleEntry entry;
  final PuzzleMetadata? metadata;
  final Color accentColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PuzzleIconBadge(
          puzzleType: entry.puzzleType,
          metadata: metadata,
          size: 52,
          borderRadius: 18,
        ),
        SizedBox(width: spacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: spacing.s),
              Wrap(
                spacing: spacing.s,
                runSpacing: spacing.s,
                children: [
                  _MetadataChip(
                    label: _displayDifficultyLabel(entry.difficultyLabel),
                    icon: Icons.tune,
                    tintColor: accentColor,
                  ),
                  _MetadataChip(
                    label: _cardStateLabel(entry.cardState),
                    icon: _cardStateIcon(entry.cardState),
                  ),
                ],
              ),
              SizedBox(height: spacing.s),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({
    required this.label,
    required this.icon,
    this.tintColor,
  });

  final String label;
  final IconData icon;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color resolvedTint = tintColor ?? colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: resolvedTint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: resolvedTint),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: resolvedTint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineHelperNote extends StatelessWidget {
  const _OfflineHelperNote();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Today\'s set stays playable offline once opened.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyLoadingState extends StatelessWidget {
  const _DailyLoadingState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();

    return ListView(
      padding: EdgeInsets.fromLTRB(spacing.l, spacing.m, spacing.l, spacing.xl),
      children: [
        const SectionHeader(
          title: 'Daily Challenges',
          subtitle: 'Loading today\'s daily hub...',
        ),
        SizedBox(height: spacing.l),
        const BrainiaxCard(
          emphasized: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(),
              SizedBox(height: 12),
              Text('Checking streak, reset countdown, and today\'s puzzles...'),
            ],
          ),
        ),
        SizedBox(height: spacing.l),
        const BrainiaxCard(emphasized: true, child: SizedBox(height: 88)),
        SizedBox(height: spacing.s),
        const BrainiaxCard(emphasized: true, child: SizedBox(height: 88)),
      ],
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
        child: EmptyStateCard(
          title: 'Unable to load daily challenges',
          body:
              'The Daily Hub could not refresh right now. Try again to reload your streak and today\'s set.',
          icon: Icons.error_outline,
          action: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Try Again'),
          ),
        ),
      ),
    );
  }
}

class _CalendarVisual {
  const _CalendarVisual({
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
    required this.labelColor,
    required this.borderWidth,
    this.icon,
    this.iconColor,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final Color labelColor;
  final double borderWidth;
  final IconData? icon;
  final Color? iconColor;
}

_CalendarVisual _calendarVisual(
  ColorScheme colorScheme,
  DailyHubWeekdayState state,
) {
  const Color successColor = Color(0xFF3BAE73);
  const Color successSurface = Color(0xFFE4F5EB);

  switch (state) {
    case DailyHubWeekdayState.completed:
      return const _CalendarVisual(
        backgroundColor: successSurface,
        borderColor: successColor,
        foregroundColor: successColor,
        labelColor: successColor,
        borderWidth: 1,
        icon: Icons.check_rounded,
        iconColor: successColor,
      );
    case DailyHubWeekdayState.missed:
      return _CalendarVisual(
        backgroundColor: colorScheme.errorContainer,
        borderColor: colorScheme.error.withValues(alpha: 0.35),
        foregroundColor: colorScheme.onErrorContainer,
        labelColor: colorScheme.error,
        borderWidth: 1,
        icon: Icons.close_rounded,
        iconColor: colorScheme.error,
      );
    case DailyHubWeekdayState.todayIncomplete:
      return _CalendarVisual(
        backgroundColor: colorScheme.surface,
        borderColor: colorScheme.primary,
        foregroundColor: colorScheme.primary,
        labelColor: colorScheme.primary,
        borderWidth: 1.6,
      );
    case DailyHubWeekdayState.todayCompleted:
      return const _CalendarVisual(
        backgroundColor: successSurface,
        borderColor: successColor,
        foregroundColor: successColor,
        labelColor: successColor,
        borderWidth: 1.6,
        icon: Icons.check_rounded,
        iconColor: successColor,
      );
    case DailyHubWeekdayState.future:
      return _CalendarVisual(
        backgroundColor: colorScheme.surfaceContainerHighest,
        borderColor: colorScheme.outlineVariant,
        foregroundColor: colorScheme.onSurfaceVariant,
        labelColor: colorScheme.onSurfaceVariant,
        borderWidth: 1,
      );
    case DailyHubWeekdayState.unknown:
      return _CalendarVisual(
        backgroundColor: colorScheme.surfaceContainerLow,
        borderColor: colorScheme.outlineVariant,
        foregroundColor: colorScheme.onSurfaceVariant,
        labelColor: colorScheme.onSurfaceVariant,
        borderWidth: 1,
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

String _headerSubtitle(DailyHubWeekday? today, String countdownText) {
  final String prefix = today == null
      ? 'Today'
      : _formatLongDate(today.dateUtc);
  return '$prefix / Resets in $countdownText';
}

DailyHubWeekday? _currentWeekday(List<DailyHubWeekday> week) {
  for (final day in week) {
    if (day.state == DailyHubWeekdayState.todayCompleted ||
        day.state == DailyHubWeekdayState.todayIncomplete) {
      return day;
    }
  }
  return null;
}

String _weekRangeLabel(List<DailyHubWeekday> week) {
  if (week.isEmpty) {
    return '';
  }
  final DateTime start = week.first.dateUtc;
  final DateTime end = week.last.dateUtc;
  return '${_monthShort(start.month)} ${start.day} - ${_monthShort(end.month)} ${end.day}';
}

String _formatLongDate(DateTime dateUtc) {
  return '${_weekdayLong(dateUtc.weekday)}, ${_monthLong(dateUtc.month)} ${dateUtc.day}';
}

String _displayDifficultyLabel(String difficultyLabel) {
  if (difficultyLabel.isEmpty) {
    return 'Daily';
  }
  final String normalized = difficultyLabel.trim();
  if (normalized.toLowerCase() == 'daily') {
    return 'Daily';
  }
  return normalized[0].toUpperCase() + normalized.substring(1).toLowerCase();
}

String _cardStateLabel(DailyHubCardState state) {
  switch (state) {
    case DailyHubCardState.play:
      return 'Ready';
    case DailyHubCardState.resume:
      return 'Saved run';
    case DailyHubCardState.completed:
      return 'Completed';
  }
}

IconData _cardStateIcon(DailyHubCardState state) {
  switch (state) {
    case DailyHubCardState.play:
      return Icons.play_arrow_rounded;
    case DailyHubCardState.resume:
      return Icons.play_circle_outline_rounded;
    case DailyHubCardState.completed:
      return Icons.check_circle_outline_rounded;
  }
}

String _compactWeekdayLabel(String label) {
  if (label.length <= 1) {
    return label;
  }
  return label.substring(0, 1);
}

String _weekdayLong(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Monday';
    case DateTime.tuesday:
      return 'Tuesday';
    case DateTime.wednesday:
      return 'Wednesday';
    case DateTime.thursday:
      return 'Thursday';
    case DateTime.friday:
      return 'Friday';
    case DateTime.saturday:
      return 'Saturday';
    case DateTime.sunday:
      return 'Sunday';
  }
  return 'Today';
}

String _monthLong(int month) {
  switch (month) {
    case DateTime.january:
      return 'January';
    case DateTime.february:
      return 'February';
    case DateTime.march:
      return 'March';
    case DateTime.april:
      return 'April';
    case DateTime.may:
      return 'May';
    case DateTime.june:
      return 'June';
    case DateTime.july:
      return 'July';
    case DateTime.august:
      return 'August';
    case DateTime.september:
      return 'September';
    case DateTime.october:
      return 'October';
    case DateTime.november:
      return 'November';
    case DateTime.december:
      return 'December';
  }
  return '';
}

String _monthShort(int month) {
  switch (month) {
    case DateTime.january:
      return 'Jan';
    case DateTime.february:
      return 'Feb';
    case DateTime.march:
      return 'Mar';
    case DateTime.april:
      return 'Apr';
    case DateTime.may:
      return 'May';
    case DateTime.june:
      return 'Jun';
    case DateTime.july:
      return 'Jul';
    case DateTime.august:
      return 'Aug';
    case DateTime.september:
      return 'Sep';
    case DateTime.october:
      return 'Oct';
    case DateTime.november:
      return 'Nov';
    case DateTime.december:
      return 'Dec';
  }
  return '';
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
