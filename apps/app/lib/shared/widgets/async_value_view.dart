import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'empty_state.dart';
import 'error_state.dart';
import 'loading.dart';

class AsyncValueView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;

  final String? emptyTitle;
  final String? emptyMessage;
  final Widget Function()? emptyAction;
  final bool Function(T data)? isEmpty;
  final VoidCallback? onRetry;

  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyAction,
    this.isEmpty,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const AppLoadingIndicator(label: 'Loading'),
      error: (e, st) => AppErrorState(
        message: _formatError(e),
        onRetry: onRetry,
      ),
      data: (d) {
        if (isEmpty?.call(d) == true) {
          return AppEmptyState(
            title: emptyTitle ?? 'Nothing here yet',
            message: emptyMessage ?? 'Try changing filters or come back later.',
            action: emptyAction?.call(),
          );
        }
        return data(d);
      },
    );
  }

  String _formatError(Object e) => e.toString();
}
