import 'dart:ui' as ui;

import 'package:app/shared/widgets/painter_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'grid metrics, hit testing, and cell rect helpers are deterministic',
    () {
      final metrics = PainterUtils.calculateGridMetrics(
        availableSize: const Size(240, 180),
        rows: 3,
        columns: 4,
        padding: 12,
        cellSpacing: 2,
      );

      expect(metrics.rows, 3);
      expect(metrics.columns, 4);
      expect(metrics.gridRect.contains(metrics.gridOffset), isTrue);
      expect(metrics.totalSize.width, metrics.gridSize.width + 24);

      final hit = PainterUtils.hitTestGrid(
        position: metrics.gridOffset + const Offset(5, 5),
        metrics: metrics,
      );
      expect(hit, Offset.zero);

      expect(
        PainterUtils.hitTestGrid(
          position: metrics.gridOffset - const Offset(20, 20),
          metrics: metrics,
        ),
        isNull,
      );

      final rect = PainterUtils.getCellRect(
        gridPosition: const Offset(2, 1),
        metrics: metrics,
      );
      expect(rect.left, greaterThan(metrics.gridOffset.dx));
      expect(rect.top, greaterThan(metrics.gridOffset.dy));
    },
  );

  test('painter utilities draw grid, text, backgrounds, and highlights', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final metrics = PainterUtils.calculateGridMetrics(
      availableSize: const Size(160, 160),
      rows: 2,
      columns: 2,
      padding: 8,
    );
    final rect = PainterUtils.getCellRect(
      gridPosition: Offset.zero,
      metrics: metrics,
    );

    final line = PainterUtils.createLinePaint(
      color: Colors.black,
      strokeWidth: 1.5,
    );
    final major = PainterUtils.createLinePaint(
      color: Colors.blue,
      strokeWidth: 3,
    );
    PainterUtils.paintGrid(
      canvas: canvas,
      metrics: metrics,
      linePaint: line,
      majorLinePaint: major,
      majorLineInterval: 2,
    );

    PainterUtils.paintCellBackground(
      canvas: canvas,
      cellRect: rect,
      backgroundPaint: PainterUtils.createBackgroundPaint(color: Colors.white),
      borderPaint: PainterUtils.createLinePaint(color: Colors.red),
    );
    PainterUtils.paintCellBackground(
      canvas: canvas,
      cellRect: rect.shift(const Offset(4, 4)),
      backgroundPaint: PainterUtils.createBackgroundPaint(color: Colors.green),
      borderPaint: PainterUtils.createLinePaint(color: Colors.orange),
      borderRadius: 3,
    );
    PainterUtils.paintCellText(
      canvas: canvas,
      cellRect: rect,
      text: '7',
      textStyle: const TextStyle(fontSize: 14, color: Colors.black),
    );
    PainterUtils.paintSelectionHighlight(
      canvas: canvas,
      cellRect: rect,
      highlightPaint: PainterUtils.createSelectionPaint(color: Colors.purple),
      animationValue: 0.5,
    );
    PainterUtils.paintSelectionHighlight(
      canvas: canvas,
      cellRect: rect,
      highlightPaint: PainterUtils.createSelectionPaint(color: Colors.purple),
      animationValue: 1,
      borderRadius: 0,
    );
    PainterUtils.paintErrorHighlight(
      canvas: canvas,
      cellRect: rect,
      errorPaint: PainterUtils.createErrorPaint(color: Colors.red),
      animationValue: 0.75,
    );
    PainterUtils.paintErrorHighlight(
      canvas: canvas,
      cellRect: rect,
      errorPaint: PainterUtils.createErrorPaint(color: Colors.red),
      animationValue: 1,
      borderRadius: 0,
    );
    PainterUtils.paintFocusIndicator(
      canvas: canvas,
      cellRect: rect,
      focusPaint: PainterUtils.createLinePaint(color: Colors.teal),
    );
    PainterUtils.paintFocusIndicator(
      canvas: canvas,
      cellRect: rect,
      focusPaint: PainterUtils.createLinePaint(color: Colors.teal),
      borderRadius: 0,
    );

    final picture = recorder.endRecording();
    expect(picture.approximateBytesUsed, greaterThan(0));
    picture.dispose();
  });

  test('custom painter wrappers delegate paint and repaint decisions', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final metrics = PainterUtils.calculateGridMetrics(
      availableSize: const Size(100, 100),
      rows: 2,
      columns: 2,
    );
    final rect = PainterUtils.getCellRect(
      gridPosition: Offset.zero,
      metrics: metrics,
    );
    final linePaint = PainterUtils.createLinePaint(color: Colors.black);
    final bgPaint = PainterUtils.createBackgroundPaint(color: Colors.white);
    final textStyle = const TextStyle(fontSize: 12, color: Colors.black);

    final gridPainter = PuzzleGridPainter(
      metrics: metrics,
      linePaint: linePaint,
      majorLinePaint: PainterUtils.createLinePaint(color: Colors.blue),
      majorLineInterval: 2,
    );
    gridPainter.paint(canvas, const Size(100, 100));
    expect(gridPainter.shouldRepaint(gridPainter), isFalse);
    expect(
      gridPainter.shouldRepaint(
        PuzzleGridPainter(metrics: metrics, linePaint: bgPaint),
      ),
      isTrue,
    );

    final backgroundPainter = CellBackgroundPainter(
      cellRect: rect,
      backgroundPaint: bgPaint,
      borderPaint: linePaint,
      borderRadius: 2,
    );
    backgroundPainter.paint(canvas, const Size(100, 100));
    expect(backgroundPainter.shouldRepaint(backgroundPainter), isFalse);
    expect(
      backgroundPainter.shouldRepaint(
        CellBackgroundPainter(
          cellRect: rect.shift(const Offset(1, 0)),
          backgroundPaint: bgPaint,
        ),
      ),
      isTrue,
    );

    final textPainter = CellTextPainter(
      cellRect: rect,
      text: 'A',
      textStyle: textStyle,
    );
    textPainter.paint(canvas, const Size(100, 100));
    expect(textPainter.shouldRepaint(textPainter), isFalse);
    expect(
      textPainter.shouldRepaint(
        CellTextPainter(cellRect: rect, text: 'B', textStyle: textStyle),
      ),
      isTrue,
    );

    final picture = recorder.endRecording();
    expect(picture.approximateBytesUsed, greaterThan(0));
    picture.dispose();
  });
}
