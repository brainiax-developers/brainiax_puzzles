import 'dart:async';
import 'package:flutter/material.dart';

/// Performance optimizations for puzzle rendering.
class PerformanceOptimizations {
  /// Cache for paint objects to avoid recreation.
  static final Map<String, Paint> _paintCache = {};
  
  /// Cache for text painters to avoid recreation.
  static final Map<String, TextPainter> _textPainterCache = {};
  
  /// Cache for grid metrics to avoid recalculation.
  static final Map<String, dynamic> _metricsCache = {};

  /// Get or create a cached paint object.
  static Paint getCachedPaint({
    required String key,
    required Color color,
    double strokeWidth = 1.0,
    PaintingStyle style = PaintingStyle.stroke,
  }) {
    final cacheKey = '${key}_${color.value}_${strokeWidth}_${style.index}';
    
    if (_paintCache.containsKey(cacheKey)) {
      return _paintCache[cacheKey]!;
    }
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = style;
    
    _paintCache[cacheKey] = paint;
    return paint;
  }

  /// Get or create a cached text painter.
  static TextPainter getCachedTextPainter({
    required String key,
    required String text,
    required TextStyle style,
    TextAlign textAlign = TextAlign.center,
  }) {
    final cacheKey = '${key}_${text}_${style.hashCode}_${textAlign.index}';
    
    if (_textPainterCache.containsKey(cacheKey)) {
      return _textPainterCache[cacheKey]!;
    }
    
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    );
    
    _textPainterCache[cacheKey] = textPainter;
    return textPainter;
  }

  /// Clear all caches to free memory.
  static void clearCaches() {
    _paintCache.clear();
    _textPainterCache.clear();
    _metricsCache.clear();
  }

  /// Clear specific cache by key pattern.
  static void clearCacheByPattern(String pattern) {
    _paintCache.removeWhere((key, value) => key.contains(pattern));
    _textPainterCache.removeWhere((key, value) => key.contains(pattern));
    _metricsCache.removeWhere((key, value) => key.contains(pattern));
  }
}

/// Mixin for performance-optimized rendering.
mixin PerformanceOptimizedRendering {
  /// Debounce timer for expensive operations.
  Timer? _debounceTimer;
  
  /// Last frame time for performance monitoring.
  DateTime? _lastFrameTime;
  
  /// Frame time accumulator for average calculation.
  final List<Duration> _frameTimes = [];
  
  /// Maximum number of frame times to keep.
  static const int _maxFrameTimeHistory = 60;

  /// Debounce an operation to avoid excessive calls.
  void debounce(Duration delay, VoidCallback callback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, callback);
  }

  /// Record frame time for performance monitoring.
  void recordFrameTime() {
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final frameTime = now.difference(_lastFrameTime!);
      _frameTimes.add(frameTime);
      
      // Keep only recent frame times
      if (_frameTimes.length > _maxFrameTimeHistory) {
        _frameTimes.removeAt(0);
      }
    }
    _lastFrameTime = now;
  }

  /// Get average frame time.
  Duration get averageFrameTime {
    if (_frameTimes.isEmpty) return Duration.zero;
    
    final total = _frameTimes.fold<Duration>(
      Duration.zero,
      (sum, time) => sum + time,
    );
    
    return Duration(
      microseconds: total.inMicroseconds ~/ _frameTimes.length,
    );
  }

  /// Check if performance is within acceptable limits.
  bool get isPerformanceAcceptable {
    const targetFrameTime = Duration(milliseconds: 16); // 60 FPS
    return averageFrameTime <= targetFrameTime;
  }

  /// Dispose of performance monitoring resources.
  void disposePerformanceMonitoring() {
    _debounceTimer?.cancel();
    _frameTimes.clear();
  }
}

/// Custom painter with performance optimizations.
abstract class OptimizedCustomPainter extends CustomPainter {
  const OptimizedCustomPainter({super.repaint});

  /// Paint with performance monitoring.
  @override
  void paint(Canvas canvas, Size size) {
    final stopwatch = Stopwatch()..start();
    
    try {
      paintOptimized(canvas, size);
    } finally {
      stopwatch.stop();
      
      // Log performance if frame takes too long
      if (stopwatch.elapsedMilliseconds > 16) {
        debugPrint('Slow paint: ${stopwatch.elapsedMilliseconds}ms');
      }
    }
  }

  /// Optimized paint method to be implemented by subclasses.
  void paintOptimized(Canvas canvas, Size size);

  /// Check if repaint is needed based on changed properties.
  bool shouldRepaintOptimized(OptimizedCustomPainter oldDelegate) {
    return shouldRepaint(oldDelegate);
  }
}

/// Efficient grid painter with caching.
class EfficientGridPainter extends OptimizedCustomPainter {
  const EfficientGridPainter({
    required this.rows,
    required this.columns,
    required this.cellSize,
    required this.gridOffset,
    required this.linePaint,
    this.majorLinePaint,
    this.majorLineInterval,
    super.repaint,
  });

  final int rows;
  final int columns;
  final Size cellSize;
  final Offset gridOffset;
  final Paint linePaint;
  final Paint? majorLinePaint;
  final int? majorLineInterval;

  @override
  void paintOptimized(Canvas canvas, Size size) {
    final cellWithSpacing = cellSize.width + 1.0; // Assuming 1px spacing
    
    // Paint vertical lines
    for (int col = 0; col <= columns; col++) {
      final x = gridOffset.dx + (col * cellWithSpacing);
      final paint = _shouldUseMajorPaint(col, majorLineInterval, majorLinePaint, linePaint);
      
      canvas.drawLine(
        Offset(x, gridOffset.dy),
        Offset(x, gridOffset.dy + (rows * cellWithSpacing)),
        paint,
      );
    }
    
    // Paint horizontal lines
    for (int row = 0; row <= rows; row++) {
      final y = gridOffset.dy + (row * cellWithSpacing);
      final paint = _shouldUseMajorPaint(row, majorLineInterval, majorLinePaint, linePaint);
      
      canvas.drawLine(
        Offset(gridOffset.dx, y),
        Offset(gridOffset.dx + (columns * cellWithSpacing), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(EfficientGridPainter oldDelegate) {
    return rows != oldDelegate.rows ||
           columns != oldDelegate.columns ||
           cellSize != oldDelegate.cellSize ||
           gridOffset != oldDelegate.gridOffset ||
           linePaint != oldDelegate.linePaint ||
           majorLinePaint != oldDelegate.majorLinePaint ||
           majorLineInterval != oldDelegate.majorLineInterval;
  }

  Paint _shouldUseMajorPaint(
    int index,
    int? majorLineInterval,
    Paint? majorLinePaint,
    Paint defaultPaint,
  ) {
    if (majorLineInterval == null || majorLinePaint == null) {
      return defaultPaint;
    }
    return index % majorLineInterval == 0 ? majorLinePaint : defaultPaint;
  }
}

/// Efficient cell painter with caching.
class EfficientCellPainter extends OptimizedCustomPainter {
  const EfficientCellPainter({
    required this.cellRect,
    required this.backgroundPaint,
    this.borderPaint,
    this.borderRadius = 0.0,
    super.repaint,
  });

  final Rect cellRect;
  final Paint backgroundPaint;
  final Paint? borderPaint;
  final double borderRadius;

  @override
  void paintOptimized(Canvas canvas, Size size) {
    if (borderRadius > 0) {
      final rrect = RRect.fromRectAndRadius(cellRect, Radius.circular(borderRadius));
      canvas.drawRRect(rrect, backgroundPaint);
      if (borderPaint != null) {
        canvas.drawRRect(rrect, borderPaint!);
      }
    } else {
      canvas.drawRect(cellRect, backgroundPaint);
      if (borderPaint != null) {
        canvas.drawRect(cellRect, borderPaint!);
      }
    }
  }

  @override
  bool shouldRepaint(EfficientCellPainter oldDelegate) {
    return cellRect != oldDelegate.cellRect ||
           backgroundPaint != oldDelegate.backgroundPaint ||
           borderPaint != oldDelegate.borderPaint ||
           borderRadius != oldDelegate.borderRadius;
  }
}

/// Efficient text painter with caching.
class EfficientTextPainter extends OptimizedCustomPainter {
  const EfficientTextPainter({
    required this.cellRect,
    required this.text,
    required this.textStyle,
    this.textAlign = TextAlign.center,
    super.repaint,
  });

  final Rect cellRect;
  final String text;
  final TextStyle textStyle;
  final TextAlign textAlign;

  @override
  void paintOptimized(Canvas canvas, Size size) {
    final textPainter = PerformanceOptimizations.getCachedTextPainter(
      key: 'cell_text',
      text: text,
      style: textStyle,
      textAlign: textAlign,
    );
    
    textPainter.layout();
    
    final textOffset = Offset(
      cellRect.left + (cellRect.width - textPainter.width) / 2,
      cellRect.top + (cellRect.height - textPainter.height) / 2,
    );
    
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(EfficientTextPainter oldDelegate) {
    return cellRect != oldDelegate.cellRect ||
           text != oldDelegate.text ||
           textStyle != oldDelegate.textStyle ||
           textAlign != oldDelegate.textAlign;
  }
}

/// Performance monitoring widget.
class PerformanceMonitor extends StatefulWidget {
  const PerformanceMonitor({
    super.key,
    required this.child,
    this.enabled = false,
  });

  final Widget child;
  final bool enabled;

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor>
    with PerformanceOptimizedRendering {
  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      recordFrameTime();
      if (mounted) {
        _startMonitoring();
      }
    });
  }

  @override
  void dispose() {
    disposePerformanceMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'FPS: ${(1000 / averageFrameTime.inMilliseconds).toStringAsFixed(1)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
