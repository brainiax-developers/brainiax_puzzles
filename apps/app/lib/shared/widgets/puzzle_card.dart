import 'package:flutter/material.dart';

import '../models/models.dart';

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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: metadata.primaryAccentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      metadata.icon,
                      color: metadata.primaryAccentColor,
                    ),
                  ),
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
              Text(
                metadata.description,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: metadata.supportedDifficulties.map((difficulty) {
                  return Chip(label: Text(difficulty));
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
        ),
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
      return 'Numbers';
    case PuzzleType.nonogramMono:
    case PuzzleType.slitherlinkLoop:
    case PuzzleType.killerQueens:
      return 'Visual';
  }
}
