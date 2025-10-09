import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// import your main.dart to access BrainiaxApp
import 'package:app/main.dart'; // adjust if your app package name differs

void main() {
  testWidgets('app builds and shows title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BrainiaxApp()),
    );

    // sanity check: title text appears
    expect(find.text('Brainiax Puzzles'), findsOneWidget);

    // frame settle
    await tester.pumpAndSettle();
  });
}

