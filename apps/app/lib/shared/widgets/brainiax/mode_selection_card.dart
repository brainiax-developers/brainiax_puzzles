import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'brainiax_card.dart';

class ModeSelectionCard extends StatelessWidget {
  const ModeSelectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.secondaryLine,
    this.icon,
    this.selected = false,
    this.enabled = true,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String? secondaryLine;
  final IconData? icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();

    Widget content = BrainiaxCard(
      onTap: enabled ? onTap : null,
      selected: selected,
      emphasized: !selected,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: selected ? colorScheme.primary : null),
            SizedBox(width: spacing.m),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (secondaryLine != null) ...[
                  SizedBox(height: spacing.s),
                  Text(
                    secondaryLine!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (selected) ...[
            SizedBox(width: spacing.s),
            Icon(Icons.check_circle, color: colorScheme.primary),
          ],
        ],
      ),
    );

    if (!enabled) {
      content = Opacity(opacity: 0.55, child: content);
    }

    return content;
  }
}
