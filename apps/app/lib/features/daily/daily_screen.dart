import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/puzzle_type.dart';
import '../../shared/widgets/async_value_view.dart';
import 'daily_providers.dart';
import 'daily_seed_generator.dart';

class DailyScreen extends ConsumerWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const puzzleType = PuzzleType.sudokuClassic;
    final seedGenerator = ref.watch(dailySeedGeneratorProvider);
    final DailySeed todaysSeed = seedGenerator.generate(puzzleType.key);
    final puzzleAsync = ref.watch(dailyPuzzleProvider(puzzleType.key));

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Challenge')),
      body: AsyncValueView(
        value: puzzleAsync,
        onRetry: () => ref.refresh(dailyPuzzleProvider(puzzleType.key)),
        data: (puzzle) => Center(
          child: Text(
            'Type=${puzzleType.key} • ${todaysSeed.formattedDate} • seed64=${puzzle.meta.seed64}',
          ),
        ),
      ),
    );
  }
}
