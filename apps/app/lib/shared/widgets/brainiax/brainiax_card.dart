import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class BrainiaxCard extends StatelessWidget {
  const BrainiaxCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.selected = false,
    this.emphasized = false,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool selected;
  final bool emphasized;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();
    final Color resolvedBorderColor =
        borderColor ??
        (selected
            ? colorScheme.primary
            : emphasized
            ? colorScheme.outlineVariant.withValues(alpha: 0.5)
            : colorScheme.outlineVariant.withValues(alpha: 0.28));
    final Color resolvedBackgroundColor =
        backgroundColor ??
        (selected
            ? colorScheme.secondaryContainer.withValues(alpha: 0.38)
            : emphasized
            ? colorScheme.surfaceContainerLow
            : colorScheme.surface);
    final ShapeBorder shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side: BorderSide(color: resolvedBorderColor, width: selected ? 1.5 : 1),
    );

    Widget body = Padding(
      padding: padding ?? EdgeInsets.all(spacing.l),
      child: child,
    );

    if (onTap != null) {
      body = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: body,
      );
    }

    return Card(
      margin: margin ?? EdgeInsets.zero,
      elevation: 0,
      color: resolvedBackgroundColor,
      surfaceTintColor: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: body,
    );
  }
}
