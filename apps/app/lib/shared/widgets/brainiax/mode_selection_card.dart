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
    this.leading,
    this.badgeLabel,
    this.footer,
    this.selected = false,
    this.enabled = true,
    this.showSelectedIndicator = true,
    this.selectedBackgroundColor,
    this.selectedBorderColor,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String? secondaryLine;
  final IconData? icon;
  final Widget? leading;
  final String? badgeLabel;
  final Widget? footer;
  final bool selected;
  final bool enabled;
  final bool showSelectedIndicator;
  final Color? selectedBackgroundColor;
  final Color? selectedBorderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();
    final Color? backgroundColor = selected ? selectedBackgroundColor : null;
    final Color? borderColor = selected ? selectedBorderColor : null;
    final Color? selectedContentColor = selected && backgroundColor != null
        ? (ThemeData.estimateBrightnessForColor(backgroundColor) ==
                  Brightness.dark
              ? Colors.white
              : colorScheme.onSurface)
        : null;
    final Color titleColor = selectedContentColor ?? colorScheme.onSurface;
    final Color subtitleColor =
        selectedContentColor?.withValues(alpha: 0.82) ??
        colorScheme.onSurfaceVariant;
    final Color secondaryLineColor =
        selectedContentColor?.withValues(alpha: 0.9) ??
        (selected ? colorScheme.primary : colorScheme.onSurfaceVariant);
    final Color iconColor =
        selectedContentColor ??
        (selected ? colorScheme.primary : colorScheme.onSurfaceVariant);
    final Widget? resolvedLeading =
        leading ?? (icon == null ? null : Icon(icon, color: iconColor));

    Widget content = BrainiaxCard(
      onTap: enabled ? onTap : null,
      selected: selected,
      emphasized: !selected,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (resolvedLeading != null) ...[
            resolvedLeading,
            SizedBox(width: spacing.m),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                    ),
                    if (badgeLabel != null) ...[
                      SizedBox(width: spacing.s),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              selectedContentColor?.withValues(alpha: 0.14) ??
                              colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeLabel!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color:
                                selectedContentColor ??
                                colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ] else if (selected && showSelectedIndicator) ...[
                      SizedBox(width: spacing.s),
                      Icon(Icons.check_circle, color: iconColor),
                    ],
                  ],
                ),
                SizedBox(height: spacing.xs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: subtitleColor,
                  ),
                ),
                if (secondaryLine != null) ...[
                  SizedBox(height: spacing.s),
                  Text(
                    secondaryLine!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: secondaryLineColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (footer != null) ...[SizedBox(height: spacing.m), footer!],
              ],
            ),
          ),
        ],
      ),
    );

    if (!enabled) {
      content = Opacity(opacity: 0.55, child: content);
    }

    return content;
  }
}
