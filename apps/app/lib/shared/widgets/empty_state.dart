import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>() ?? const AppSpacing();
    final theme = Theme.of(context);

    return Semantics(
      label: title,
      hint: message,
      child: Padding(
        padding: EdgeInsets.all(spacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: theme.colorScheme.outline),
                SizedBox(height: spacing.l),
                Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                SizedBox(height: spacing.s),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                if (action != null) ...[
                  SizedBox(height: spacing.l),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
