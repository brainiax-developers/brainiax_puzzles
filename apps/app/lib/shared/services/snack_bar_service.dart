import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final snackBarServiceProvider = Provider<SnackBarService>((ref) {
  return SnackBarService();
});

class SnackBarService {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  void showInfo(String message) => _show(message, _Severity.info);
  void showSuccess(String message) => _show(message, _Severity.success);
  void showError(String message) => _show(message, _Severity.error);

  void _show(String message, _Severity severity) {
    final state = scaffoldMessengerKey.currentState;
    if (state == null) return;
    final theme = Theme.of(state.context);
    final cs = theme.colorScheme;

    Color bg;
    Color fg;
    IconData icon;
    switch (severity) {
      case _Severity.info:
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        icon = Icons.info_rounded;
        break;
      case _Severity.success:
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
        icon = Icons.check_circle_rounded;
        break;
      case _Severity.error:
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        icon = Icons.error_rounded;
        break;
    }

    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: bg,
      content: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: fg),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    state.clearSnackBars();
    state.showSnackBar(snackBar);
  }
}

enum _Severity { info, success, error }
