import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/models.dart';
import '../../shared/navigation/app_routes.dart';
import '../../shared/providers/puzzle_local_store_providers.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/active_run_card.dart';
import '../../shared/widgets/brainiax/brainiax_widgets.dart';
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
  bool _hasUserSelectedDifficulty = false;

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
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();
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
      if (_didApplyPreferredDifficulty || _hasUserSelectedDifficulty) {
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
    final bool dailyCompletionResolved = dailyCompletedAsync.asData != null;
    final bool dailyCompleted = dailyCompletedAsync.asData?.value ?? false;
    final ActivePuzzleRun? activeRun = activeRunAsync.asData?.value;
    final bool isFavourite = isFavouriteAsync.asData?.value ?? false;
    final bool isAvailable = widget.metadata.isAvailable;
    final List<String> supportedDifficulties =
        widget.metadata.supportedDifficulties;
    final String dailyDifficultyLabel =
        activeRun?.mode == PuzzleMode.daily && activeRun!.difficulty.isNotEmpty
        ? activeRun.difficulty
        : 'Daily Set';

    final _SheetCallToAction cta;
    if (!isAvailable) {
      cta = _SheetCallToAction(
        label: widget.metadata.availabilityBadgeLabel ?? 'Coming Soon',
        icon: Icons.hourglass_top_rounded,
      );
    } else if (_selectedMode == PuzzleMode.daily) {
      if (!dailyEligible) {
        cta = const _SheetCallToAction(
          label: 'Daily Unavailable',
          icon: Icons.event_busy_outlined,
        );
      } else if (!dailyCompletionResolved) {
        cta = const _SheetCallToAction(
          label: 'Checking Daily...',
          icon: Icons.schedule_outlined,
        );
      } else if (dailyCompleted) {
        cta = _SheetCallToAction(
          label: 'View Daily',
          icon: Icons.visibility_outlined,
          onPressed: _viewDaily,
        );
      } else {
        cta = _SheetCallToAction(
          label: 'Start Daily Challenge',
          icon: Icons.play_arrow_rounded,
          onPressed: _startDaily,
        );
      }
    } else if (_selectedDifficulty.isEmpty) {
      cta = const _SheetCallToAction(
        label: 'Random Unavailable',
        icon: Icons.shuffle_outlined,
      );
    } else {
      cta = _SheetCallToAction(
        label: 'Start Random Puzzle',
        icon: Icons.shuffle_rounded,
        onPressed: () => _startRandom(_selectedDifficulty),
      );
    }

    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final double buttonBottomPadding =
        MediaQuery.of(context).viewPadding.bottom + spacing.m;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, spacing.xl + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PuzzleIconBadge(
                        metadata: widget.metadata,
                        size: 56,
                        borderRadius: 18,
                      ),
                      SizedBox(width: spacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.metadata.displayName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: spacing.xs),
                            Text(
                              _categoryLabelFor(
                                widget.metadata.type,
                              ).toUpperCase(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: isFavourite
                            ? 'Remove favourite'
                            : 'Add favourite',
                        onPressed: () => ref
                            .read(favouritePuzzleControllerProvider)
                            .toggle(puzzleType),
                        icon: Icon(
                          isFavourite ? Icons.star : Icons.star_outline,
                          color: isFavourite
                              ? widget.metadata.primaryAccentColor
                              : null,
                        ),
                      ),
                      SizedBox(width: spacing.xs),
                      IconButton.filledTonal(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.l),
                  BrainiaxCard(
                    emphasized: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Objective',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: spacing.s),
                        Text(
                          widget.metadata.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing.s),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _showHowToPlayPlaceholder,
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('How to Play'),
                    ),
                  ),
                  SizedBox(height: spacing.l),
                  if (!isAvailable)
                    BrainiaxCard(
                      emphasized: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.metadata.availabilityBadgeLabel ??
                                'Coming Soon',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: spacing.s),
                          Text(
                            widget.metadata.unavailableMessage ??
                                'Kakuro is coming soon.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    const SectionHeader(title: 'Choose Mode'),
                    SizedBox(height: spacing.m),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final bool useRow = constraints.maxWidth >= 560;
                        final Widget dailyCard = ModeSelectionCard(
                          title: 'Daily Challenge',
                          subtitle: dailyEligible
                              ? 'Same puzzle for everyone'
                              : 'Not part of the daily rotation yet',
                          leading: _buildModeIcon(
                            context,
                            icon: Icons.calendar_today_outlined,
                            accentColor: widget.metadata.primaryAccentColor,
                            selected:
                                _selectedMode == PuzzleMode.daily &&
                                dailyEligible,
                            useDarkSelectedStyle: true,
                          ),
                          badgeLabel: dailyCompleted ? 'Completed Today' : null,
                          footer: dailyEligible
                              ? _ResetCountdownFooter(
                                  selected: _selectedMode == PuzzleMode.daily,
                                  accentColor:
                                      widget.metadata.primaryAccentColor,
                                )
                              : Text(
                                  'Daily unavailable',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                          selected: _selectedMode == PuzzleMode.daily,
                          enabled: dailyEligible,
                          showSelectedIndicator: false,
                          selectedBackgroundColor:
                              widget.metadata.secondaryAccentColor,
                          selectedBorderColor:
                              widget.metadata.secondaryAccentColor,
                          onTap: () => setState(() {
                            _selectedMode = PuzzleMode.daily;
                          }),
                        );
                        final Widget randomCard = ModeSelectionCard(
                          title: 'Random Play',
                          subtitle: 'Infinite variety',
                          secondaryLine: 'Unique to you',
                          leading: _buildModeIcon(
                            context,
                            icon: Icons.shuffle_rounded,
                            accentColor: colorScheme.primary,
                            selected: _selectedMode == PuzzleMode.random,
                            useDarkSelectedStyle: false,
                          ),
                          selected: _selectedMode == PuzzleMode.random,
                          showSelectedIndicator: false,
                          selectedBackgroundColor: colorScheme.primaryContainer
                              .withValues(alpha: 0.7),
                          selectedBorderColor: colorScheme.primary.withValues(
                            alpha: 0.45,
                          ),
                          onTap: () => setState(() {
                            _selectedMode = PuzzleMode.random;
                          }),
                        );

                        if (useRow) {
                          return Row(
                            children: [
                              Expanded(child: dailyCard),
                              SizedBox(width: spacing.m),
                              Expanded(child: randomCard),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            dailyCard,
                            SizedBox(height: spacing.m),
                            randomCard,
                          ],
                        );
                      },
                    ),
                    SizedBox(height: spacing.l),
                    if (_selectedMode == PuzzleMode.daily) ...[
                      const SectionHeader(
                        title: 'Daily Difficulty',
                        subtitle:
                            'Today\'s daily challenge uses a fixed setup.',
                      ),
                      SizedBox(height: spacing.m),
                      BrainiaxCard(
                        emphasized: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: spacing.s,
                              runSpacing: spacing.s,
                              children: [
                                DifficultyChip(
                                  label: dailyDifficultyLabel,
                                  selected: true,
                                  readOnly: true,
                                ),
                                if (dailyCompleted)
                                  const DifficultyChip(
                                    label: 'Completed Today',
                                    readOnly: true,
                                  ),
                              ],
                            ),
                            SizedBox(height: spacing.s),
                            Text(
                              dailyCompleted
                                  ? 'Today\'s daily is already complete. Use View Daily to reopen the solved puzzle safely.'
                                  : 'Difficulty is set by the daily challenge and cannot be changed here.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SectionHeader(
                        title: 'Difficulty',
                        subtitle:
                            'Pick the challenge level for your next random puzzle.',
                      ),
                      SizedBox(height: spacing.m),
                      if (supportedDifficulties.isEmpty)
                        BrainiaxCard(
                          emphasized: true,
                          child: Text(
                            'Difficulty selection is unavailable for this puzzle type.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: spacing.s,
                          runSpacing: spacing.s,
                          children: supportedDifficulties
                              .map((difficulty) {
                                return DifficultyChip(
                                  label: difficulty,
                                  selected: _selectedDifficulty == difficulty,
                                  onTap: () => _selectRandomDifficulty(
                                    puzzleType,
                                    difficulty,
                                  ),
                                );
                              })
                              .toList(growable: false),
                        ),
                    ],
                  ],
                  if (activeRun != null && isAvailable) ...[
                    SizedBox(height: spacing.l),
                    ActiveRunCard(
                      run: activeRun,
                      title: 'Saved Game',
                      subtitle: widget.metadata.displayName,
                      onResume: _resumeActiveRun,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              spacing.m,
              20,
              buttonBottomPadding,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: cta.onPressed,
                icon: Icon(cta.icon),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  backgroundColor: widget.metadata.primaryAccentColor,
                  foregroundColor:
                      ThemeData.estimateBrightnessForColor(
                            widget.metadata.primaryAccentColor,
                          ) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  disabledBackgroundColor: colorScheme.surfaceContainerHighest,
                  disabledForegroundColor: colorScheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                label: Text(cta.label),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _resolveDefaultDifficulty(
    List<String> supportedDifficulties, {
    String? preferred,
  }) {
    if (supportedDifficulties.isEmpty) {
      return '';
    }
    if (preferred != null && supportedDifficulties.contains(preferred)) {
      return preferred;
    }
    if (supportedDifficulties.contains('Medium')) {
      return 'Medium';
    }
    return supportedDifficulties.first;
  }

  Widget _buildModeIcon(
    BuildContext context, {
    required IconData icon,
    required Color accentColor,
    required bool selected,
    required bool useDarkSelectedStyle,
  }) {
    final Color iconColor = selected && useDarkSelectedStyle
        ? Colors.white
        : accentColor;
    final Color backgroundColor = selected
        ? (useDarkSelectedStyle
              ? Colors.white.withValues(alpha: 0.12)
              : accentColor.withValues(alpha: 0.12))
        : accentColor.withValues(alpha: 0.1);
    final Color borderColor = selected && useDarkSelectedStyle
        ? Colors.white.withValues(alpha: 0.22)
        : accentColor.withValues(alpha: 0.18);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }

  void _selectRandomDifficulty(PuzzleType puzzleType, String difficulty) {
    setState(() {
      _selectedMode = PuzzleMode.random;
      _selectedDifficulty = difficulty;
      _hasUserSelectedDifficulty = true;
    });
    ref
        .read(difficultyPreferenceControllerProvider)
        .setPreferredDifficulty(puzzleType, difficulty);
  }

  void _showHowToPlayPlaceholder() {
    ScaffoldMessenger.of(
      widget.hostContext,
    ).showSnackBar(const SnackBar(content: Text('Tutorial coming soon.')));
  }

  Future<void> _resumeActiveRun() async {
    _closeSheet();
    await resumePuzzleRun(
      context: widget.hostContext,
      ref: ref,
      puzzleType: widget.metadata.type,
    );
  }

  void _startDaily() {
    _closeSheet();
    widget.hostContext.push(
      AppRoutes.play(widget.metadata.type.key, PuzzleMode.daily.key),
    );
  }

  void _viewDaily() {
    _closeSheet();
    widget.hostContext.go(AppRoutes.daily);
  }

  Future<void> _startRandom(String difficulty) async {
    _closeSheet();
    await startRandomPuzzleFlow(
      context: widget.hostContext,
      ref: ref,
      puzzleType: widget.metadata.type,
      difficulty: difficulty,
    );
  }

  void _closeSheet() {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}

class _SheetCallToAction {
  const _SheetCallToAction({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
}

class _ResetCountdownFooter extends StatelessWidget {
  const _ResetCountdownFooter({
    required this.selected,
    required this.accentColor,
  });

  final bool selected;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color footerColor = selected ? Colors.white : accentColor;

    return Row(
      children: [
        Icon(Icons.schedule_outlined, size: 16, color: footerColor),
        const SizedBox(width: 6),
        Flexible(
          child: DefaultTextStyle(
            style: theme.textTheme.labelMedium!.copyWith(
              color: footerColor,
              fontWeight: FontWeight.w700,
            ),
            child: const _ResetCountdownLabel(prefix: 'Resets in '),
          ),
        ),
      ],
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
