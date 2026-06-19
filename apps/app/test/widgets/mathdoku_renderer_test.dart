import 'package:app/shared/widgets/mathdoku_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cell layout keeps cage label separate from note grid', () {
    final layout = MathdokuCellLayout.forCell(
      const Rect.fromLTWH(0, 0, 40, 40),
    );

    expect(layout.cageLabelRect.top, lessThan(layout.noteGridRect.top));
    expect(layout.cageLabelRect.overlaps(layout.noteGridRect), isFalse);
  });

  test('cell layout remains usable for compact cells', () {
    final layout = MathdokuCellLayout.forCell(
      const Rect.fromLTWH(0, 0, 24, 24),
    );

    expect(layout.cageLabelRect.width, greaterThan(0));
    expect(layout.cageLabelRect.height, greaterThan(0));
    expect(layout.noteGridRect.width, greaterThan(0));
    expect(layout.noteGridRect.height, greaterThan(0));
  });
}
