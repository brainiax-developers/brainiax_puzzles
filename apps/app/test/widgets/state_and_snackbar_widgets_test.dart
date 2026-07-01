import 'package:app/shared/services/snack_bar_service.dart';
import 'package:app/shared/theme/app_theme.dart';
import 'package:app/shared/widgets/empty_state.dart';
import 'package:app/shared/widgets/error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('error state renders retry action when provided', (
    WidgetTester tester,
  ) async {
    var retried = false;

    await tester.pumpWidget(
      _app(
        AppErrorState(
          title: 'Could not load',
          message: 'Try again later',
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.text('Could not load'), findsOneWidget);
    expect(find.text('Try again later'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
    expect(retried, isTrue);
  });

  testWidgets('empty state renders optional action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AppEmptyState(
          icon: Icons.search,
          title: 'No puzzles',
          message: 'Try a different filter',
          action: TextButton(onPressed: () {}, child: const Text('Reset')),
        ),
      ),
    );

    expect(find.text('No puzzles'), findsOneWidget);
    expect(find.text('Try a different filter'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);
  });

  testWidgets('snackbar service shows info success and error messages', (
    WidgetTester tester,
  ) async {
    final service = SnackBarService();

    service.showInfo('not mounted');

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: service.scaffoldMessengerKey,
        theme: AppTheme.light(),
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    service.showInfo('Info message');
    await tester.pump();
    expect(find.text('Info message'), findsOneWidget);
    expect(find.byIcon(Icons.info_rounded), findsOneWidget);

    service.showSuccess('Success message');
    await tester.pump();
    expect(find.text('Success message'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    service.showError('Error message');
    await tester.pump();
    expect(find.text('Error message'), findsOneWidget);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  );
}
