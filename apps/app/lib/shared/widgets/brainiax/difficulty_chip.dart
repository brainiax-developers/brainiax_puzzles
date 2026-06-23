import 'package:flutter/material.dart';

class DifficultyChip extends StatelessWidget {
  const DifficultyChip({
    super.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool interactive = enabled && !readOnly && onTap != null;

    Widget chip = ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: interactive && selected,
      onSelected: interactive ? (_) => onTap?.call() : null,
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        color: !enabled
            ? colorScheme.onSurface.withValues(alpha: 0.5)
            : readOnly && !selected
            ? colorScheme.onSurfaceVariant
            : null,
      ),
      side: BorderSide(
        color: !enabled
            ? colorScheme.outline.withValues(alpha: 0.2)
            : selected
            ? colorScheme.primary.withValues(alpha: 0.6)
            : colorScheme.outlineVariant,
      ),
    );

    if (!enabled) {
      chip = Opacity(opacity: 0.55, child: chip);
    }

    return chip;
  }
}
