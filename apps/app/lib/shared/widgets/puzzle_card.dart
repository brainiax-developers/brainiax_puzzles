import 'package:flutter/material.dart';

import '../models/models.dart';
import 'brainiax/brainiax_widgets.dart';

class PuzzleCard extends StatelessWidget {
  const PuzzleCard({
    super.key,
    required this.metadata,
    required this.isFavourite,
    required this.isInProgress,
    required this.onTap,
    required this.onToggleFavourite,
    this.onResume,
  });

  final PuzzleMetadata metadata;
  final bool isFavourite;
  final bool isInProgress;
  final VoidCallback onTap;
  final VoidCallback onToggleFavourite;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return BrainiaxCard(
      emphasized: isInProgress,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PuzzleIconBadge(metadata: metadata),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _categoryLabelFor(metadata.type),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavourite ? 'Remove favourite' : 'Add favourite',
                onPressed: onToggleFavourite,
                icon: Icon(
                  isFavourite ? Icons.star : Icons.star_outline,
                  color: isFavourite ? Colors.amber[700] : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(metadata.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: metadata.supportedDifficulties.map((difficulty) {
              return DifficultyChip(label: difficulty, readOnly: true);
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isInProgress)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'In Progress',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              const Spacer(),
              if (onResume != null)
                TextButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Continue'),
                ),
            ],
          ),
        ],
      ),
    );
  }
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
