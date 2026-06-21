import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/config/app_environment.dart';
import '../../shared/models/models.dart';
import '../../shared/navigation/app_routes.dart';
import '../../shared/providers/puzzle_local_store_providers.dart';
import '../../shared/services/puzzle_progress_service.dart';
import '../../shared/widgets/puzzle_generation_modal.dart';
import '../../shared/services/kakuro_on_demand_service.dart';

Future<void> resumePuzzleRun({
  required BuildContext context,
  required WidgetRef ref,
  required PuzzleType puzzleType,
}) async {
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
  await _clearProgress(ref, puzzleType);

  if (!context.mounted) {
    return;
  }

  if (puzzleType == PuzzleType.kakuroClassic) {
    bool dialogOpen = true;
    bool cancelled = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async {
          cancelled = true;
          return true;
        },
        child: const _KakuroLoadingDialog(),
      ),
    ).then((_) {
      dialogOpen = false;
      cancelled = true;
    });

    try {
      final service = ref.read(kakuroOnDemandProvider);
      final surface = AppEnvironment.isProduction
          ? core.KakuroAppProfileSurface.production
          : core.KakuroAppProfileSurface.nonProduction;

      final String sizeStr = core.KakuroSupportedProfiles.appSizeForDifficulty(
        difficulty: difficulty,
        surface: surface,
      );
      final List<String> parts = sizeStr.split('x');
      final int width = int.tryParse(parts.first) ?? 9;
      final int height =
          int.tryParse(parts.length > 1 ? parts.last : '') ?? width;
      final generated = await service.nextPuzzle(
        difficulty: difficulty,
        width: width,
        height: height,
      );

      if (cancelled) {
        return;
      }

      if (dialogOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }

      if (!context.mounted) {
        return;
      }

      if (kDebugMode) {
        debugPrint(
          '[Navigation][NewGame] kakuro seed=${generated.meta.seedStr} '
          'difficulty=$difficulty source=new',
        );
      }

      context.push(
        AppRoutes.play(puzzleType.key, PuzzleMode.random.key),
        extra: generated,
      );
      return;
    } catch (_) {
      if (dialogOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
      if (!context.mounted || cancelled) {
        return;
      }
    }
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

class _KakuroLoadingDialog extends StatelessWidget {
  const _KakuroLoadingDialog();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            const SizedBox(height: 16),
            Text('Generating Kakuro...', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
