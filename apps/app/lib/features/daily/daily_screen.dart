import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/models.dart';
import '../../shared/navigation/app_routes.dart';
import '../../shared/providers/daily_status_provider.dart';

class DailyScreen extends ConsumerWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<PuzzleType, DailyStatus>> statusAsync = ref.watch(
      dailyStatusProvider,
    );
    final List<PuzzleType> puzzleTypes = ref.watch(dailyPuzzleTypesProvider);

    return statusAsync.when(
      data: (statuses) =>
          _DailyContent(puzzleTypes: puzzleTypes, statuses: statuses),
      loading: () => const _DailyLoadingState(),
      error: (error, stackTrace) =>
          _DailyErrorState(onRetry: () => ref.invalidate(dailyStatusProvider)),
    );
  }
}

class _DailyContent extends StatelessWidget {
  const _DailyContent({required this.puzzleTypes, required this.statuses});

  final List<PuzzleType> puzzleTypes;
  final Map<PuzzleType, DailyStatus> statuses;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int completedCount = statuses.values
        .where((DailyStatus status) => status.isCompleted)
        .length;
    final int totalCount = puzzleTypes.length;
    final PuzzleType? nextPuzzleType = _firstIncompletePuzzleType();
    final Duration resetDuration = statuses.values.isNotEmpty
        ? statuses.values.first.timeUntilReset
        : DailyUtcDate.timeUntilReset(now: DateTime.now().toUtc());
    final bool allCompleted = totalCount > 0 && completedCount == totalCount;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Daily Challenges',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Complete each daily puzzle before the UTC reset.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  label: 'Completed',
                  value: '$completedCount of $totalCount',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'UTC reset',
                  value: _formatDuration(resetDuration),
                ),
                const SizedBox(height: 16),
                if (allCompleted)
                  const _CompletedBanner()
                else if (nextPuzzleType != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push(
                        AppRoutes.play(
                          nextPuzzleType.key,
                          PuzzleMode.daily.key,
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: Text('Start ${nextPuzzleType.displayName}'),
                    ),
                  )
                else
                  const Text('No daily puzzles are currently available.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Today\'s puzzles',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (puzzleTypes.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No daily puzzle types are configured.'),
            ),
          )
        else
          ...puzzleTypes.map((PuzzleType type) {
            final DailyStatus? status = statuses[type];
            final bool isCompleted = status?.isCompleted ?? false;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isCompleted ? Colors.green : null,
                ),
                title: Text(type.displayName),
                subtitle: Text(
                  isCompleted
                      ? 'Completed for today'
                      : 'Available until ${_formatDuration(resetDuration)}',
                ),
                trailing: isCompleted
                    ? const Text('Done')
                    : TextButton(
                        onPressed: () => context.push(
                          AppRoutes.play(type.key, PuzzleMode.daily.key),
                        ),
                        child: const Text('Play'),
                      ),
              ),
            );
          }),
      ],
    );
  }

  PuzzleType? _firstIncompletePuzzleType() {
    for (final PuzzleType type in puzzleTypes) {
      final DailyStatus? status = statuses[type];
      if (status == null || !status.isCompleted) {
        return type;
      }
    }
    return null;
  }

  String _formatDuration(Duration duration) {
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
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

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'All daily puzzles completed.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
