import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLoadingIndicator extends StatelessWidget {
  final String? label;
  final bool inline;

  const AppLoadingIndicator({super.key, this.label, this.inline = false});

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>() ?? const AppSpacing();
    final indicator = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3)),
        if (label != null) ...[
          SizedBox(width: spacing.m),
          Text(label!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );

    if (inline) return indicator;

    return Semantics(
      label: label ?? 'Loading',
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.all(spacing.xl),
        child: Center(child: indicator),
      ),
    );
  }
}
