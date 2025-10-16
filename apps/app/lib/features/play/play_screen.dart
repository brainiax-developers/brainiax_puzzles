import 'package:flutter/material.dart';
import '../../shared/models/models.dart';

/// Screen for playing a specific puzzle type in a specific mode.
class PlayScreen extends StatelessWidget {
  const PlayScreen({
    super.key,
    required this.puzzleType,
    required this.mode,
  });

  final PuzzleType puzzleType;
  final PuzzleMode mode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${puzzleType.displayName} - ${mode.displayName}'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.play_circle,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              'Playing ${puzzleType.displayName}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mode: ${mode.displayName}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Puzzle Type: ${puzzleType.key}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            Text(
              'Mode: ${mode.key}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}