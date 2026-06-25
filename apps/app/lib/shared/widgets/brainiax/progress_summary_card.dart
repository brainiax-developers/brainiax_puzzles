import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'brainiax_card.dart';

class ProgressSummaryCard extends StatelessWidget {
  const ProgressSummaryCard({
    super.key,
    required this.title,
    this.subtitle,
    this.progressValue,
    this.progressLabel,
    this.metadata = const <Widget>[],
    this.action,
    this.leading,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final double? progressValue;
  final String? progressLabel;
  final List<Widget> metadata;
  final Widget? action;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppSpacing spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing();

    return BrainiaxCard(
      emphasized: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[leading!, SizedBox(width: spacing.m)],
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
                    if (subtitle != null) ...[
                      SizedBox(height: spacing.xs),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (metadata.isNotEmpty) ...[
            SizedBox(height: spacing.m),
            Wrap(spacing: spacing.s, runSpacing: spacing.s, children: metadata),
          ],
          if (progressValue != null) ...[
            SizedBox(height: spacing.m),
            if (progressLabel != null) ...[
              Text(
                progressLabel!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: spacing.s),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progressValue!.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
          if (action != null) ...[SizedBox(height: spacing.l), action!],
        ],
      ),
    );
  }
}
