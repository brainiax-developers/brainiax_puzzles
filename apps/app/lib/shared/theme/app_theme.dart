import 'package:flutter/material.dart';

enum Contrast { normal, high }

class AppTheme {
  static ThemeData light([Contrast c = Contrast.normal]) =>
      ThemeData(brightness: Brightness.light, colorSchemeSeed: Colors.indigo,
        useMaterial3: true, visualDensity: VisualDensity.standard,
        textTheme: c == Contrast.high ? Typography.whiteMountainView : null);

  static ThemeData dark([Contrast c = Contrast.normal]) =>
      ThemeData(brightness: Brightness.dark, colorSchemeSeed: Colors.indigo,
        useMaterial3: true, visualDensity: VisualDensity.standard,
        textTheme: c == Contrast.high ? Typography.whiteMountainView : null);
}
