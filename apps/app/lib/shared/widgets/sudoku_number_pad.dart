import 'package:flutter/material.dart';

/// Number pad widget for Sudoku input.
class SudokuNumberPad extends StatelessWidget {
  const SudokuNumberPad({
    super.key,
    required this.onDigitPressed,
    this.onClearPressed,
    this.onNotePressed,
    this.isNoteMode = false,
    this.enabledDigits = const {1, 2, 3, 4, 5, 6, 7, 8, 9},
  });

  final ValueChanged<int> onDigitPressed;
  final VoidCallback? onClearPressed;
  final VoidCallback? onNotePressed;
  final bool isNoteMode;
  final Set<int> enabledDigits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Blend with canvas area: no box/background around the pad.
  return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Note mode toggle
          if (onNotePressed != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Note Mode',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: isNoteMode,
                    onChanged: (_) => onNotePressed?.call(),
                    activeColor: colorScheme.primary,
                  ),
                ],
              ),
            ),
          
          // Number row (single row, borderless, no scroll, fits width)
          Row(
            children: [
              for (int digit = 1; digit <= 9; digit++)
                Expanded(
                  child: Center(
                    child: _NumberButton(
                      digit: digit,
                      onPressed: enabledDigits.contains(digit)
                          ? () => onDigitPressed(digit)
                          : null,
                      isNoteMode: isNoteMode,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Clear button
          if (onClearPressed != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClearPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(
                    color: colorScheme.outline.withOpacity(0.3),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Clear',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      );
  }
}

/// Individual number button for the number pad.
class _NumberButton extends StatelessWidget {
  const _NumberButton({
    required this.digit,
    required this.onPressed,
    required this.isNoteMode,
  });

  final int digit;
  final VoidCallback? onPressed;
  final bool isNoteMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        backgroundColor: Colors.transparent,
        foregroundColor: onPressed != null ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.3),
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(
        digit.toString(),
        style: theme.textTheme.titleLarge?.copyWith(
          color: onPressed != null ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.3),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
