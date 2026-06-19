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
  bool _allCompleted = false;

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
          data: (_) => _allCompleted
              ? _buildAllCompletedContent()
              : _buildLoadingContent(),
          loading: () => _buildLoadingContent(),
          error: (error, stackTrace) => _buildErrorContent(),
        ),
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        const Text("Preparing today's daily puzzle..."),
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

  Widget _buildAllCompletedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline, size: 40),
        const SizedBox(height: 12),
        const Text("You've completed today's Daily Challenges."),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.go('/'),
          child: const Text('Back Home'),
        ),
      ],
    );
  }

  void _navigateToDaily({Map<PuzzleType, DailyStatus>? statuses}) {
    if (_navigated) return;
    final puzzleTypes = ref.read(dailyPuzzleTypesProvider);
    if (puzzleTypes.isEmpty) return;

    final PuzzleType? targetType = _selectTargetType(puzzleTypes, statuses);
    if (targetType == null) {
      if (mounted) {
        setState(() {
          _allCompleted = true;
        });
      }
      return;
    }
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.replace('/play/${targetType.key}/daily');
    });
  }

  PuzzleType? _selectTargetType(
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
      return null;
    }
    return puzzleTypes.first;
  }
}
