import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/models.dart';
import '../../shared/navigation/app_routes.dart';
import '../../shared/providers/puzzle_local_store_providers.dart';
import '../../shared/services/puzzle_progress_service.dart';
import '../../shared/widgets/puzzle_generation_modal.dart';


Future<void> resumePuzzleRun({
  required BuildContext context,
  required WidgetRef ref,
  required PuzzleType puzzleType,
}) async {
  if (!puzzleType.isPlayable) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(puzzleType.unavailableMessage ?? 'Unavailable.'),
        ),
      );
    }
    return;
  }

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final PuzzleProgressService progress = PuzzleProgressService(prefs);
  final ActivePuzzleRun? run = await progress.loadActiveRun(puzzleType);
  final core.GeneratedPuzzle<dynamic>? puzzle = run == null
      ? null
      : progress.loadPuzzleForRun(run);

  if (!context.mounted) {
    return;
  }

  if (run == null || puzzle == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to resume that saved game.')),
    );
    ref.read(puzzleProgressControllerProvider).refresh();
    return;
  }

  context.push(AppRoutes.play(puzzleType.key, run.mode.key), extra: puzzle);
}

Future<void> startRandomPuzzleFlow({
  required BuildContext context,
  required WidgetRef ref,
  required PuzzleType puzzleType,
  required String difficulty,
}) async {
  if (!puzzleType.isPlayable) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(puzzleType.unavailableMessage ?? 'Unavailable.'),
        ),
      );
    }
    return;
  }

  await _clearProgress(ref, puzzleType);

  if (!context.mounted) {
    return;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PuzzleGenerationModal(
      puzzleType: puzzleType,
      difficulty: difficulty,
      onPuzzleGenerated: (puzzleInstance) {
        Navigator.of(dialogContext).pop();
        context.push(
          AppRoutes.play(puzzleType.key, PuzzleMode.random.key),
          extra: puzzleInstance,
        );
      },
      onCancel: () {
        Navigator.of(dialogContext).pop();
      },
    ),
  );
}

Future<void> _clearProgress(WidgetRef ref, PuzzleType puzzleType) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final PuzzleProgressService progress = PuzzleProgressService(prefs);
    await progress.clearRun(type: puzzleType, mode: PuzzleMode.random);
  } catch (_) {
    // Ignore persistence failures and allow the new launch flow to continue.
  } finally {
    ref.read(puzzleProgressControllerProvider).refresh();
  }
}
