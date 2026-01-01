import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/puzzle_type.dart';
import '../../shared/providers/daily_status_provider.dart';

class DailyScreen extends ConsumerStatefulWidget {
  const DailyScreen({super.key});

  @override
  ConsumerState<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends ConsumerState<DailyScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToDaily());
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(dailyStatusProvider);

    statusAsync.whenData((statuses) {
      _navigateToDaily(statuses: statuses);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Challenge')),
      body: Center(
        child: statusAsync.when(
          data: (_) => _buildLoadingContent(),
          loading: () => _buildLoadingContent(),
          error: (_, __) => _buildErrorContent(),
        ),
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text("Preparing today's daily puzzle..."),
      ],
    );
  }

  Widget _buildErrorContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Starting the daily puzzle...'),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _navigateToDaily,
          child: const Text('Try Again'),
        ),
      ],
    );
  }

  void _navigateToDaily({Map<PuzzleType, DailyStatus>? statuses}) {
    if (_navigated) return;
    final puzzleTypes = ref.read(dailyPuzzleTypesProvider);
    if (puzzleTypes.isEmpty) return;

    final PuzzleType targetType = _selectTargetType(puzzleTypes, statuses);
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.replace('/play/${targetType.key}/daily');
    });
  }

  PuzzleType _selectTargetType(
    List<PuzzleType> puzzleTypes,
    Map<PuzzleType, DailyStatus>? statuses,
  ) {
    if (statuses != null && statuses.isNotEmpty) {
      for (final type in puzzleTypes) {
        final DailyStatus? status = statuses[type];
        if (status == null || !status.isCompleted) {
          return type;
        }
      }
    }
    return puzzleTypes.first;
  }
}
