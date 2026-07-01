import 'dart:ui' as ui;

import 'package:app/shared/widgets/performance_optimizations.dart';
import 'package:app/shared/widgets/shimmer_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'paint and text painter caches reuse matching keys and clear by pattern',
    () {
      final paint = PerformanceOptimizations.getCachedPaint(
        key: 'unit_line',
        color: Colors.red,
        strokeWidth: 2,
      );
      final samePaint = PerformanceOptimizations.getCachedPaint(
        key: 'unit_line',
        color: Colors.red,
        strokeWidth: 2,
      );
      final differentPaint = PerformanceOptimizations.getCachedPaint(
        key: 'unit_line_other',
        color: Colors.red,
        strokeWidth: 2,
      );

      expect(samePaint, same(paint));
      expect(differentPaint, isNot(same(paint)));

      final textStyle = const TextStyle(fontSize: 12);
      final textPainter = PerformanceOptimizations.getCachedTextPainter(
        key: 'unit_text',
        text: 'A',
        style: textStyle,
      );
      final sameTextPainter = PerformanceOptimizations.getCachedTextPainter(
        key: 'unit_text',
        text: 'A',
        style: textStyle,
      );
      expect(sameTextPainter, same(textPainter));

      PerformanceOptimizations.clearCacheByPattern('unit_line');
      expect(
        PerformanceOptimizations.getCachedPaint(
          key: 'unit_line',
          color: Colors.red,
          strokeWidth: 2,
        ),
        isNot(same(paint)),
      );

      PerformanceOptimizations.clearCaches();
      expect(
        PerformanceOptimizations.getCachedTextPainter(
          key: 'unit_text',
          text: 'A',
          style: textStyle,
        ),
        isNot(same(textPainter)),
      );
    },
  );

  testWidgets('performance monitor renders child and optional overlay', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PerformanceMonitor(enabled: false, child: Text('plain child')),
      ),
    );
    expect(find.text('plain child'), findsOneWidget);
    expect(find.textContaining('FPS:'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: PerformanceMonitor(enabled: true, child: Text('monitored child')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 17));

    expect(find.text('monitored child'), findsOneWidget);
    expect(find.textContaining('FPS:'), findsOneWidget);
  });

  testWidgets('shimmer widgets render in light, dark, and custom colors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: const ShimmerWidget(child: SizedBox(width: 20, height: 20)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ShaderMask), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const ShimmerWidget(child: SizedBox(width: 20, height: 20)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ShaderMask), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: ShimmerWidget(
          baseColor: Colors.black,
          highlightColor: Colors.white,
          duration: Duration(milliseconds: 300),
          child: SizedBox(width: 20, height: 20),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('puzzle card shimmer lays out all placeholder regions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PuzzleCardShimmer())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Card), findsOneWidget);
    expect(find.byType(ShimmerWidget), findsNWidgets(8));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'performance mixin debounces, records frame times, and disposes',
    () async {
      final probe = _RenderingProbe();
      var calls = 0;

      probe.debounce(const Duration(milliseconds: 20), () => calls++);
      probe.debounce(const Duration(milliseconds: 20), () => calls += 10);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(calls, 0);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls, 10);

      expect(probe.averageFrameTime, Duration.zero);
      expect(probe.isPerformanceAcceptable, isTrue);
      probe.recordFrameTime();
      for (var i = 0; i < 65; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 17));
        probe.recordFrameTime();
      }
      expect(probe.averageFrameTime, isNot(Duration.zero));
      expect(probe.isPerformanceAcceptable, isFalse);

      probe.debounce(const Duration(milliseconds: 20), () => calls++);
      probe.disposePerformanceMonitoring();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(calls, 10);
      expect(probe.averageFrameTime, Duration.zero);
    },
  );

  test('optimized painters draw and report repaint differences', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final linePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke;

    final grid = EfficientGridPainter(
      rows: 2,
      columns: 2,
      cellSize: const Size.square(20),
      gridOffset: Offset.zero,
      linePaint: linePaint,
      majorLinePaint: majorPaint,
      majorLineInterval: 2,
    );
    grid.paint(canvas, const Size(80, 80));
    expect(grid.shouldRepaint(grid), isFalse);
    expect(
      grid.shouldRepaint(
        EfficientGridPainter(
          rows: 3,
          columns: 2,
          cellSize: const Size.square(20),
          gridOffset: Offset.zero,
          linePaint: linePaint,
        ),
      ),
      isTrue,
    );
    expect(grid.shouldRepaintOptimized(grid), isFalse);

    final defaultGrid = EfficientGridPainter(
      rows: 1,
      columns: 1,
      cellSize: const Size.square(10),
      gridOffset: Offset.zero,
      linePaint: linePaint,
    );
    defaultGrid.paint(canvas, const Size(40, 40));

    final roundedCell = EfficientCellPainter(
      cellRect: const Rect.fromLTWH(0, 0, 20, 20),
      backgroundPaint: fillPaint,
      borderPaint: borderPaint,
      borderRadius: 3,
    );
    roundedCell.paint(canvas, const Size(40, 40));
    expect(roundedCell.shouldRepaint(roundedCell), isFalse);
    expect(
      roundedCell.shouldRepaint(
        EfficientCellPainter(
          cellRect: const Rect.fromLTWH(1, 0, 20, 20),
          backgroundPaint: fillPaint,
        ),
      ),
      isTrue,
    );

    final squareCell = EfficientCellPainter(
      cellRect: const Rect.fromLTWH(0, 0, 20, 20),
      backgroundPaint: fillPaint,
      borderPaint: borderPaint,
    );
    squareCell.paint(canvas, const Size(40, 40));

    const text = EfficientTextPainter(
      cellRect: Rect.fromLTWH(0, 0, 40, 40),
      text: '8',
      textStyle: TextStyle(fontSize: 14, color: Colors.black),
    );
    text.paint(canvas, const Size(40, 40));
    expect(text.shouldRepaint(text), isFalse);
    expect(
      text.shouldRepaint(
        const EfficientTextPainter(
          cellRect: Rect.fromLTWH(0, 0, 40, 40),
          text: '9',
          textStyle: TextStyle(fontSize: 14, color: Colors.black),
        ),
      ),
      isTrue,
    );

    final picture = recorder.endRecording();
    expect(picture.approximateBytesUsed, greaterThan(0));
    picture.dispose();
  });
}

class _RenderingProbe with PerformanceOptimizedRendering {}
