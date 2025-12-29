import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../providers/daily_status_provider.dart';

/// A surface widget showing daily challenge status and time until reset.
class DailySurface extends ConsumerWidget {
  const DailySurface({
    super.key,
    this.puzzleType,
    this.showPuzzleName = false,
    this.compact = false,
  });

  /// Specific puzzle type for this daily surface (null for overall status).
  final PuzzleType? puzzleType;
  
  /// Whether to show the puzzle name in the surface.
  final bool showPuzzleName;
  
  /// Whether to show a compact version of the surface.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (puzzleType != null) {
      return _buildPuzzleSpecificSurface(context, ref, theme, colorScheme);
    } else {
      return _buildOverallSurface(context, ref, theme, colorScheme);
    }
  }

  Widget _buildPuzzleSpecificSurface(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final statusAsync = ref.watch(dailyStatusForPuzzleProvider(puzzleType!));
    
    return statusAsync.when(
      data: (status) {
        if (status == null) {
          return const SizedBox.shrink();
        }
        return _DailySurfaceCard(
          compact: compact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: status.isCompleted 
                        ? Colors.green 
                        : colorScheme.primary,
                    size: compact ? 16 : 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      showPuzzleName 
                          ? 'Daily ${puzzleType!.displayName}'
                          : 'Daily Challenge',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (!compact)
                    Text(
                      status.formattedTimeUntilReset,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
              if (compact) ...[
                const SizedBox(height: 4),
                Text(
                  status.formattedTimeUntilReset,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _DailyActionButton(
                status: status,
                puzzleType: puzzleType!,
                compact: compact,
              ),
            ],
          ),
        );
      },
      loading: () => _DailySurfaceCard(
        compact: compact,
        child: _buildLoadingState(colorScheme),
      ),
      error: (_, __) => _DailySurfaceCard(
        compact: compact,
        child: _buildErrorState(theme, colorScheme),
      ),
    );
  }

  Widget _buildOverallSurface(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final overallStatusAsync = ref.watch(dailyOverallStatusProvider);

    return overallStatusAsync.when(
      data: (overallStatus) => _DailySurfaceCard(
        compact: compact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  overallStatus.isAllCompleted ? Icons.emoji_events : Icons.calendar_today,
                  color: overallStatus.isAllCompleted 
                      ? Colors.amber 
                      : colorScheme.primary,
                  size: compact ? 16 : 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Daily Challenges',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (!compact)
                  Text(
                    overallStatus.formattedTimeUntilReset,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
            if (compact) ...[
              const SizedBox(height: 4),
              Text(
                overallStatus.formattedTimeUntilReset,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              overallStatus.completionText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            _DailyProgressBar(
              progress: overallStatus.completionPercentage,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 8),
            _DailyActionButton(
              status: null,
              puzzleType: null,
              compact: compact,
            ),
          ],
        ),
      ),
      loading: () => _DailySurfaceCard(
        compact: compact,
        child: _buildLoadingState(colorScheme),
      ),
      error: (_, __) => _DailySurfaceCard(
        compact: compact,
        child: _buildErrorState(theme, colorScheme),
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return SizedBox(
      height: compact ? 40 : 56,
      child: Center(
        child: SizedBox(
          width: compact ? 16 : 20,
          height: compact ? 16 : 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
      child: Text(
        'Unable to load daily status',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Card wrapper for daily surface.
class _DailySurfaceCard extends StatelessWidget {
  const _DailySurfaceCard({
    required this.child,
    this.compact = false,
  });

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Progress bar for daily completion.
class _DailyProgressBar extends StatelessWidget {
  const _DailyProgressBar({
    required this.progress,
    required this.colorScheme,
  });

  final double progress;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: colorScheme.outline.withOpacity(0.2),
        valueColor: AlwaysStoppedAnimation<Color>(
          progress >= 1.0 ? Colors.green : colorScheme.primary,
        ),
        minHeight: 6,
      ),
    );
  }
}

/// Action button for daily challenges.
class _DailyActionButton extends StatelessWidget {
  const _DailyActionButton({
    required this.status,
    required this.puzzleType,
    required this.compact,
  });

  final DailyStatus? status;
  final PuzzleType? puzzleType;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final isCompleted = status?.isCompleted ?? false;
    final buttonText = isCompleted ? 'Completed' : 'Start Daily';
    final buttonColor = isCompleted ? Colors.green : colorScheme.primary;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isCompleted ? null : () => _navigateToDaily(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor.withOpacity(0.1),
          foregroundColor: buttonColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: buttonColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          padding: EdgeInsets.symmetric(
            vertical: compact ? 8 : 12,
            horizontal: 16,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCompleted ? Icons.check : Icons.play_arrow,
              size: compact ? 16 : 18,
            ),
            const SizedBox(width: 8),
            Text(
              buttonText,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDaily(BuildContext context) {
    if (puzzleType != null) {
      context.push('/play/${puzzleType!.key}/daily');
    } else {
      context.push('/daily');
    }
  }
}
