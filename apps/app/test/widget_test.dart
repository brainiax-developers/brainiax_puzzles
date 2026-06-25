import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// import your main.dart to access BrainiaxApp
import 'package:app/main.dart'; // adjust if your app package name differs

void main() {
  testWidgets('app builds the shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BrainiaxApp()));

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Home'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
