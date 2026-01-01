import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Utilities for painting puzzle grids and handling interactions.
class PainterUtils {
  /// Calculate grid metrics for a given size and grid dimensions.
  static GridMetrics calculateGridMetrics({
    required Size availableSize,
    required int rows,
    required int columns,
    double padding = 16.0,
    double cellSpacing = 1.0,
  }) {
    final effectiveSize = Size(
      availableSize.width - (padding * 2),
      availableSize.height - (padding * 2),
    );
    
    // Calculate cell size to fit the available space
    final cellWidth = (effectiveSize.width - (cellSpacing * (columns - 1))) / columns;
    final cellHeight = (effectiveSize.height - (cellSpacing * (rows - 1))) / rows;
    final cellSize = math.min(cellWidth, cellHeight);
    
    // Calculate total grid size
    final gridWidth = (cellSize * columns) + (cellSpacing * (columns - 1));
    final gridHeight = (cellSize * rows) + (cellSpacing * (rows - 1));
    
    // Center the grid
    final offsetX = padding + (effectiveSize.width - gridWidth) / 2;
    final offsetY = padding + (effectiveSize.height - gridHeight) / 2;
    
    return GridMetrics(
      cellSize: Size(cellSize, cellSize),
      gridSize: Size(gridWidth, gridHeight),
      gridOffset: Offset(offsetX, offsetY),
      padding: padding,
      cellSpacing: cellSpacing,
      rows: rows,
      columns: columns,
    );
  }

  /// Perform hit testing to convert screen coordinates to grid coordinates.
  static Offset? hitTestGrid({
    required Offset position,
    required GridMetrics metrics,
  }) {
    // Check if position is within grid bounds
    if (!metrics.gridRect.contains(position)) {
      return null;
    }
    
    // Convert to grid-relative coordinates
    final relativePosition = position - metrics.gridOffset;
    
    // Calculate grid coordinates
    final cellWithSpacing = metrics.cellSize.width + metrics.cellSpacing;
    final col = (relativePosition.dx / cellWithSpacing).floor();
    final row = (relativePosition.dy / cellWithSpacing).floor();
    
    // Check bounds
    if (row >= 0 && row < metrics.rows && col >= 0 && col < metrics.columns) {
      return Offset(col.toDouble(), row.toDouble());
    }
    
    return null;
  }

  /// Get the screen rectangle for a grid cell.
  static Rect getCellRect({
    required Offset gridPosition,
    required GridMetrics metrics,
  }) {
    final cellWithSpacing = metrics.cellSize.width + metrics.cellSpacing;
    final x = metrics.gridOffset.dx + (gridPosition.dx * cellWithSpacing);
    final y = metrics.gridOffset.dy + (gridPosition.dy * cellWithSpacing);
    
    return Rect.fromLTWH(x, y, metrics.cellSize.width, metrics.cellSize.height);
  }

  /// Paint a grid background with optional major/minor lines.
  static void paintGrid({
    required Canvas canvas,
    required GridMetrics metrics,
    required Paint linePaint,
    Paint? majorLinePaint,
    int? majorLineInterval,
  }) {
    final cellWithSpacing = metrics.cellSize.width + metrics.cellSpacing;
    
    // Paint vertical lines
    for (int col = 0; col <= metrics.columns; col++) {
      final x = metrics.gridOffset.dx + (col * cellWithSpacing);
      final paint = _shouldUseMajorPaint(col, majorLineInterval, majorLinePaint, linePaint);
      
      canvas.drawLine(
        Offset(x, metrics.gridOffset.dy),
        Offset(x, metrics.gridOffset.dy + metrics.gridSize.height),
        paint,
      );
    }
    
    // Paint horizontal lines
    for (int row = 0; row <= metrics.rows; row++) {
      final y = metrics.gridOffset.dy + (row * cellWithSpacing);
      final paint = _shouldUseMajorPaint(row, majorLineInterval, majorLinePaint, linePaint);
      
      canvas.drawLine(
        Offset(metrics.gridOffset.dx, y),
        Offset(metrics.gridOffset.dx + metrics.gridSize.width, y),
        paint,
      );
    }
  }

  /// Paint a cell background with optional border.
  static void paintCellBackground({
    required Canvas canvas,
    required Rect cellRect,
    required Paint backgroundPaint,
    Paint? borderPaint,
    double borderRadius = 0.0,
  }) {
    if (borderRadius > 0) {
      final rrect = RRect.fromRectAndRadius(cellRect, Radius.circular(borderRadius));
      canvas.drawRRect(rrect, backgroundPaint);
      if (borderPaint != null) {
        canvas.drawRRect(rrect, borderPaint);
      }
    } else {
      canvas.drawRect(cellRect, backgroundPaint);
      if (borderPaint != null) {
        canvas.drawRect(cellRect, borderPaint);
      }
    }
  }

  /// Paint text centered in a cell.
  static void paintCellText({
    required Canvas canvas,
    required Rect cellRect,
    required String text,
    required TextStyle textStyle,
    TextAlign textAlign = TextAlign.center,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    final textOffset = Offset(
      cellRect.left + (cellRect.width - textPainter.width) / 2,
      cellRect.top + (cellRect.height - textPainter.height) / 2,
    );
    
    textPainter.paint(canvas, textOffset);
  }

  /// Paint a selection highlight with animation.
  static void paintSelectionHighlight({
    required Canvas canvas,
    required Rect cellRect,
    required Paint highlightPaint,
    required double animationValue,
    double borderRadius = 4.0,
  }) {
    final animatedPaint = Paint()
      ..color = highlightPaint.color.withOpacity(highlightPaint.color.opacity * animationValue)
      ..style = highlightPaint.style
      ..strokeWidth = highlightPaint.strokeWidth;
    
    if (borderRadius > 0) {
      final rrect = RRect.fromRectAndRadius(cellRect, Radius.circular(borderRadius));
      canvas.drawRRect(rrect, animatedPaint);
    } else {
      canvas.drawRect(cellRect, animatedPaint);
    }
  }

  /// Paint an error highlight with animation.
  static void paintErrorHighlight({
    required Canvas canvas,
    required Rect cellRect,
    required Paint errorPaint,
    required double animationValue,
    double borderRadius = 4.0,
  }) {
    final animatedPaint = Paint()
      ..color = errorPaint.color.withOpacity(errorPaint.color.opacity * animationValue)
      ..style = errorPaint.style
      ..strokeWidth = errorPaint.strokeWidth;
    
    if (borderRadius > 0) {
      final rrect = RRect.fromRectAndRadius(cellRect, Radius.circular(borderRadius));
      canvas.drawRRect(rrect, animatedPaint);
    } else {
      canvas.drawRect(cellRect, animatedPaint);
    }
  }

  /// Paint a focus indicator.
  static void paintFocusIndicator({
    required Canvas canvas,
    required Rect cellRect,
    required Paint focusPaint,
    double borderRadius = 4.0,
  }) {
    if (borderRadius > 0) {
      final rrect = RRect.fromRectAndRadius(cellRect, Radius.circular(borderRadius));
      canvas.drawRRect(rrect, focusPaint);
    } else {
      canvas.drawRect(cellRect, focusPaint);
    }
  }

  /// Check if a position should use major line paint.
  static Paint _shouldUseMajorPaint(
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

  /// Create a paint object for grid lines.
  static Paint createLinePaint({
    required Color color,
    double strokeWidth = 1.0,
    PaintingStyle style = PaintingStyle.stroke,
  }) {
    return Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = style;
  }

  /// Create a paint object for cell backgrounds.
  static Paint createBackgroundPaint({
    required Color color,
    PaintingStyle style = PaintingStyle.fill,
  }) {
    return Paint()
      ..color = color
      ..style = style;
  }

  /// Create a paint object for selection highlights.
  static Paint createSelectionPaint({
    required Color color,
    double strokeWidth = 2.0,
    PaintingStyle style = PaintingStyle.stroke,
  }) {
    return Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = style;
  }

  /// Create a paint object for error highlights.
  static Paint createErrorPaint({
    required Color color,
    double strokeWidth = 2.0,
    PaintingStyle style = PaintingStyle.stroke,
  }) {
    return Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = style;
  }
}

/// Metrics for grid layout and positioning.
class GridMetrics {
  const GridMetrics({
    required this.cellSize,
    required this.gridSize,
    required this.gridOffset,
    required this.padding,
    required this.cellSpacing,
    required this.rows,
    required this.columns,
  });

  /// Size of individual cells.
  final Size cellSize;
  
  /// Total size of the grid.
  final Size gridSize;
  
  /// Offset of the grid from the top-left corner.
  final Offset gridOffset;
  
  /// Padding around the grid.
  final double padding;
  
  /// Spacing between cells.
  final double cellSpacing;
  
  /// Number of rows in the grid.
  final int rows;
  
  /// Number of columns in the grid.
  final int columns;

  /// Get the rectangle containing the entire grid.
  Rect get gridRect => Rect.fromLTWH(
    gridOffset.dx,
    gridOffset.dy,
    gridSize.width,
    gridSize.height,
  );

  /// Get the total size including padding.
  Size get totalSize => Size(
    gridSize.width + (padding * 2),
    gridSize.height + (padding * 2),
  );
}

/// Custom painter for puzzle grids.
class PuzzleGridPainter extends CustomPainter {
  const PuzzleGridPainter({
    required this.metrics,
    required this.linePaint,
    this.majorLinePaint,
    this.majorLineInterval,
  });

  final GridMetrics metrics;
  final Paint linePaint;
  final Paint? majorLinePaint;
  final int? majorLineInterval;

  @override
  void paint(Canvas canvas, Size size) {
    PainterUtils.paintGrid(
      canvas: canvas,
      metrics: metrics,
      linePaint: linePaint,
      majorLinePaint: majorLinePaint,
      majorLineInterval: majorLineInterval,
    );
  }

  @override
  bool shouldRepaint(PuzzleGridPainter oldDelegate) {
    return metrics != oldDelegate.metrics ||
           linePaint != oldDelegate.linePaint ||
           majorLinePaint != oldDelegate.majorLinePaint ||
           majorLineInterval != oldDelegate.majorLineInterval;
  }
}

/// Custom painter for cell backgrounds.
class CellBackgroundPainter extends CustomPainter {
  const CellBackgroundPainter({
    required this.cellRect,
    required this.backgroundPaint,
    this.borderPaint,
    this.borderRadius = 0.0,
  });

  final Rect cellRect;
  final Paint backgroundPaint;
  final Paint? borderPaint;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    PainterUtils.paintCellBackground(
      canvas: canvas,
      cellRect: cellRect,
      backgroundPaint: backgroundPaint,
      borderPaint: borderPaint,
      borderRadius: borderRadius,
    );
  }

  @override
  bool shouldRepaint(CellBackgroundPainter oldDelegate) {
    return cellRect != oldDelegate.cellRect ||
           backgroundPaint != oldDelegate.backgroundPaint ||
           borderPaint != oldDelegate.borderPaint ||
           borderRadius != oldDelegate.borderRadius;
  }
}

/// Custom painter for cell text.
class CellTextPainter extends CustomPainter {
  const CellTextPainter({
    required this.cellRect,
    required this.text,
    required this.textStyle,
    this.textAlign = TextAlign.center,
  });

  final Rect cellRect;
  final String text;
  final TextStyle textStyle;
  final TextAlign textAlign;

  @override
  void paint(Canvas canvas, Size size) {
    PainterUtils.paintCellText(
      canvas: canvas,
      cellRect: cellRect,
      text: text,
      textStyle: textStyle,
      textAlign: textAlign,
    );
  }

  @override
  bool shouldRepaint(CellTextPainter oldDelegate) {
    return cellRect != oldDelegate.cellRect ||
           text != oldDelegate.text ||
           textStyle != oldDelegate.textStyle ||
           textAlign != oldDelegate.textAlign;
  }
}
