import 'package:flutter/material.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import '../models/models.dart';
import 'brainiax/brainiax_widgets.dart';

class ActiveRunCard extends StatelessWidget {
  const ActiveRunCard({
    super.key,
    required this.run,
    required this.title,
    required this.onResume,
    this.subtitle,
  });

  final ActivePuzzleRun run;
  final String title;
  final String? subtitle;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final _ActiveRunProgress? progress = _computeProgress(run);

    return ProgressSummaryCard(
      title: title,
      subtitle: subtitle,
      progressValue: progress?.fraction,
      progressLabel: progress == null
          ? null
          : '${progress.percentage}% progress',
      metadata: [
        _Pill(
          icon: run.mode == PuzzleMode.daily
              ? Icons.calendar_today_outlined
              : Icons.casino_outlined,
          label: run.mode == PuzzleMode.daily
              ? 'Daily Challenge'
              : 'Random Play',
        ),
        _Pill(icon: Icons.speed_outlined, label: run.difficulty),
        _Pill(
          icon: Icons.timer_outlined,
          label: _formatElapsed(Duration(milliseconds: run.elapsedMs)),
        ),
      ],
      action: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onResume,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Resume'),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 14), const SizedBox(width: 6), Text(label)],
      ),
    );
  }
}

class _ActiveRunProgress {
  _ActiveRunProgress({required this.fraction})
    : percentage = (fraction * 100).round();

  final double fraction;
  final int percentage;
}

_ActiveRunProgress? _computeProgress(ActivePuzzleRun run) {
  try {
    final state = run.generatedPuzzleJson['state'];
    if (state is! Map) {
      return null;
    }
    final Map<String, dynamic> board = Map<String, dynamic>.from(state);

    switch (run.puzzleType) {
      case PuzzleType.sudokuClassic:
      case PuzzleType.mathdokuClassic:
      case PuzzleType.killerQueens:
        return _filledCellProgress(board);

      case PuzzleType.nonogramMono:
        return _nonogramProgress(board);
      case PuzzleType.slitherlinkLoop:
        return _slitherlinkProgress(board);
      case PuzzleType.takuzuBinary:
        return _takuzuProgress(board);
    }
  } catch (_) {
    return null;
  }
}

_ActiveRunProgress? _filledCellProgress(Map<String, dynamic> board) {
  final List<dynamic>? cellsDynamic = board['cells'] as List<dynamic>?;
  if (cellsDynamic == null || cellsDynamic.isEmpty) {
    return null;
  }
  final List<int> cells = cellsDynamic.cast<int>();
  final List<bool> fixed = (board['fixed'] as List<dynamic>? ?? const [])
      .map((value) => value as bool)
      .toList();
  final int totalEditable = fixed.isEmpty
      ? cells.length
      : fixed.where((value) => !value).length;
  if (totalEditable <= 0) {
    return null;
  }

  int filled = 0;
  for (int index = 0; index < cells.length; index++) {
    final bool isFixed = fixed.isNotEmpty && fixed[index];
    if (!isFixed && cells[index] != 0) {
      filled += 1;
    }
  }
  return _ActiveRunProgress(fraction: filled / totalEditable);
}

_ActiveRunProgress? _nonogramProgress(Map<String, dynamic> board) {
  final List<dynamic>? cells = board['cells'] as List<dynamic>?;
  if (cells == null || cells.isEmpty) {
    return null;
  }
  final List<dynamic>? rowClues = board['rowClues'] as List<dynamic>?;
  final int totalRequired = rowClues == null
      ? cells.length
      : rowClues.fold<int>(0, (int total, dynamic row) {
          if (row is! List<dynamic>) {
            return total;
          }
          return total +
              row.fold<int>(0, (int lineTotal, dynamic clue) {
                return lineTotal + (clue as int);
              });
        });
  if (totalRequired <= 0) {
    return null;
  }
  final int filled = cells.where((value) => value == 1).length;
  return _ActiveRunProgress(fraction: (filled / totalRequired).clamp(0.0, 1.0));
}


_ActiveRunProgress? _slitherlinkProgress(Map<String, dynamic> board) {
  final List<dynamic>? edges = board['edges'] as List<dynamic>?;
  if (edges == null || edges.isEmpty) {
    return null;
  }
  final int drawn = edges
      .cast<int>()
      .where((value) => value == core.SlitherlinkBoard.edgeOn)
      .length;
  return _ActiveRunProgress(fraction: drawn / edges.length);
}

_ActiveRunProgress? _takuzuProgress(Map<String, dynamic> board) {
  final List<dynamic>? cellsDynamic = board['cells'] as List<dynamic>?;
  if (cellsDynamic == null || cellsDynamic.isEmpty) {
    return null;
  }
  final List<int> cells = cellsDynamic.cast<int>();
  final List<bool> fixed = (board['fixed'] as List<dynamic>? ?? const [])
      .map((value) => value as bool)
      .toList();
  final int totalEditable = fixed.where((value) => !value).length;
  if (totalEditable <= 0) {
    return null;
  }

  int filled = 0;
  for (int index = 0; index < cells.length; index++) {
    if (!fixed[index] && cells[index] != core.TakuzuBoard.emptyValue) {
      filled += 1;
    }
  }
  return _ActiveRunProgress(fraction: filled / totalEditable);
}

String _formatElapsed(Duration duration) {
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
