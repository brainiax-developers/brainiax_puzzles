import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/models.dart';
import '../../shared/navigation/app_routes.dart';
import '../../shared/providers/puzzle_local_store_providers.dart';
import '../../shared/widgets/active_run_card.dart';
import 'puzzle_launch_actions.dart';

Future<void> showPuzzleDetailSheet({
  required BuildContext context,
  required PuzzleMetadata metadata,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return PuzzleDetailSheet(hostContext: context, metadata: metadata);
    },
  );
}

class PuzzleDetailSheet extends ConsumerStatefulWidget {
  const PuzzleDetailSheet({
    super.key,
    required this.hostContext,
    required this.metadata,
  });

  final BuildContext hostContext;
  final PuzzleMetadata metadata;

  @override
  ConsumerState<PuzzleDetailSheet> createState() => _PuzzleDetailSheetState();
}

class _PuzzleDetailSheetState extends ConsumerState<PuzzleDetailSheet> {
  late PuzzleMode _selectedMode;
  late String _selectedDifficulty;
  bool _didApplyPreferredDifficulty = false;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.metadata.type.isDailyEligible
        ? PuzzleMode.daily
        : PuzzleMode.random;
    _selectedDifficulty = _resolveDefaultDifficulty(
      widget.metadata.supportedDifficulties,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final PuzzleType puzzleType = widget.metadata.type;
    final AsyncValue<bool> isFavouriteAsync = ref.watch(
      isFavouritePuzzleTypeProvider(puzzleType),
    );
    final AsyncValue<ActivePuzzleRun?> activeRunAsync = ref.watch(
      activeRunForPuzzleTypeProvider(puzzleType),
    );
    final AsyncValue<bool> dailyCompletedAsync = ref.watch(
      puzzleTodayCompletionProvider(puzzleType),
    );
    final AsyncValue<String> preferredDifficultyAsync = ref.watch(
      preferredDifficultyProvider(puzzleType),
    );

    preferredDifficultyAsync.whenData((preferred) {
      if (_didApplyPreferredDifficulty) {
        return;
      }
      final String resolved = _resolveDefaultDifficulty(
        widget.metadata.supportedDifficulties,
        preferred: preferred,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedDifficulty = resolved;
          _didApplyPreferredDifficulty = true;
        });
      });
    });

    final bool dailyEligible = puzzleType.isDailyEligible;
    final bool dailyCompleted = dailyCompletedAsync.asData?.value ?? false;
    final ActivePuzzleRun? activeRun = activeRunAsync.asData?.value;
    final bool isFavourite = isFavouriteAsync.asData?.value ?? false;
    final List<String> supportedDifficulties =
        widget.metadata.supportedDifficulties;

    final String ctaLabel;
    final VoidCallback? ctaAction;
    if (_selectedMode == PuzzleMode.daily) {
      if (!dailyEligible) {
        ctaLabel = 'Daily Unavailable';
        ctaAction = null;
      } else if (dailyCompleted) {
        ctaLabel = 'View Daily';
        ctaAction = _viewDaily;
      } else {
        ctaLabel = 'Start Daily Challenge';
        ctaAction = _startDaily;
      }
    } else {
      ctaLabel = 'Start Random Puzzle';
      ctaAction = () => _startRandom(_selectedDifficulty);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.metadata.primaryAccentColor.withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.metadata.icon,
                  color: widget.metadata.primaryAccentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.metadata.displayName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _categoryLabelFor(widget.metadata.type),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavourite ? 'Remove favourite' : 'Add favourite',
                onPressed: () => ref
                    .read(favouritePuzzleControllerProvider)
                    .toggle(puzzleType),
                icon: Icon(
                  isFavourite ? Icons.star : Icons.star_outline,
                  color: isFavourite ? Colors.amber[700] : null,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Objective',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(widget.metadata.description),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(widget.hostContext).showSnackBar(
                const SnackBar(content: Text('Tutorial coming soon.')),
              );
            },
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('How to Play'),
          ),
          const SizedBox(height: 16),
          Text(
            'Choose mode',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final Axis axis = constraints.maxWidth >= 560
                  ? Axis.horizontal
                  : Axis.vertical;
              final List<Widget> cards = [
                if (dailyEligible)
                  _ModeCard(
                    title: 'Daily Challenge',
                    subtitle: 'Same puzzle for everyone',
                    detailBuilder: (_) =>
                        const _ResetCountdownLabel(prefix: 'Resets in '),
                    selected: _selectedMode == PuzzleMode.daily,
                    enabled: true,
                    badge: dailyCompleted ? 'Completed Today' : null,
                    onTap: () => setState(() {
                      _selectedMode = PuzzleMode.daily;
                    }),
                  )
                else
                  _ModeCard(
                    title: 'Daily Challenge',
                    subtitle: 'Not part of the daily rotation yet',
                    detailBuilder: (_) => const SizedBox.shrink(),
                    selected: false,
                    enabled: false,
                    onTap: null,
                  ),
                _ModeCard(
                  title: 'Random Play',
                  subtitle: 'Infinite variety',
                  secondaryLine: 'Unique to you',
                  detailBuilder: (_) => const SizedBox.shrink(),
                  selected: _selectedMode == PuzzleMode.random,
                  enabled: true,
                  onTap: () => setState(() {
                    _selectedMode = PuzzleMode.random;
                  }),
                ),
              ];

              if (axis == Axis.horizontal) {
                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                );
              }
              return Column(
                children: [cards[0], const SizedBox(height: 10), cards[1]],
              );
            },
          ),
          const SizedBox(height: 12),
          if (_selectedMode == PuzzleMode.daily)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: const Text('Daily difficulty set for today'),
            )
          else ...[
            Text(
              'Difficulty',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: supportedDifficulties.map((difficulty) {
                return ChoiceChip(
                  label: Text(difficulty),
                  selected: _selectedDifficulty == difficulty,
                  onSelected: (_) {
                    setState(() {
                      _selectedDifficulty = difficulty;
                    });
                    ref
                        .read(difficultyPreferenceControllerProvider)
                        .setPreferredDifficulty(puzzleType, difficulty);
                  },
                );
              }).toList(),
            ),
          ],
          if (activeRun != null) ...[
            const SizedBox(height: 12),
            ActiveRunCard(
              run: activeRun,
              title: 'Saved Game',
              subtitle: widget.metadata.displayName,
              onResume: _resumeActiveRun,
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: ctaAction, child: Text(ctaLabel)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _resolveDefaultDifficulty(
    List<String> supportedDifficulties, {
    String? preferred,
  }) {
    if (preferred != null && supportedDifficulties.contains(preferred)) {
      return preferred;
    }
    if (supportedDifficulties.contains('Medium')) {
      return 'Medium';
    }
    return supportedDifficulties.first;
  }

  Future<void> _resumeActiveRun() async {
    Navigator.of(context).pop();
    await resumePuzzleRun(
      context: widget.hostContext,
      ref: ref,
      puzzleType: widget.metadata.type,
    );
  }

  void _startDaily() {
    Navigator.of(context).pop();
    widget.hostContext.push(
      AppRoutes.play(widget.metadata.type.key, PuzzleMode.daily.key),
    );
  }

  void _viewDaily() {
    Navigator.of(context).pop();
    widget.hostContext.go(AppRoutes.daily);
  }

  Future<void> _startRandom(String difficulty) async {
    Navigator.of(context).pop();
    await startRandomPuzzleFlow(
      context: widget.hostContext,
      ref: ref,
      puzzleType: widget.metadata.type,
      difficulty: difficulty,
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.detailBuilder,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.secondaryLine,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String? secondaryLine;
  final String? badge;
  final WidgetBuilder detailBuilder;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(badge!, style: theme.textTheme.labelSmall),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle),
            if (secondaryLine != null) ...[
              const SizedBox(height: 4),
              Text(
                secondaryLine!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            detailBuilder(context),
          ],
        ),
      ),
    );
  }
}

class _ResetCountdownLabel extends StatelessWidget {
  const _ResetCountdownLabel({required this.prefix});

  final String prefix;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream<int>.periodic(
        const Duration(minutes: 1),
        (count) => count,
      ).startWith(0),
      builder: (context, snapshot) {
        final Duration duration = DailyUtcDate.timeUntilReset();
        return Text('$prefix${_formatCountdown(duration)}');
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

String _categoryLabelFor(PuzzleType puzzleType) {
  switch (puzzleType) {
    case PuzzleType.sudokuClassic:
    case PuzzleType.kakuroClassic:
    case PuzzleType.mathdokuClassic:
    case PuzzleType.takuzuBinary:
      return 'Number puzzle';
    case PuzzleType.nonogramMono:
    case PuzzleType.slitherlinkLoop:
    case PuzzleType.killerQueens:
      return 'Visual puzzle';
  }
}
