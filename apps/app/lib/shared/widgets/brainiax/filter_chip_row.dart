import 'package:flutter/material.dart';

class FilterChipOption<T> {
  const FilterChipOption({
    required this.value,
    required this.label,
    this.enabled = true,
  });

  final T value;
  final String label;
  final bool enabled;
}

class FilterChipRow<T> extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.options,
    required this.selectedValue,
    this.onSelected,
  });

  final List<FilterChipOption<T>> options;
  final T selectedValue;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          children: [
            for (int index = 0; index < options.length; index++) ...[
              ChoiceChip(
                label: Text(options[index].label),
                selected: options[index].value == selectedValue,
                onSelected: options[index].enabled && onSelected != null
                    ? (_) => onSelected?.call(options[index].value)
                    : null,
              ),
              if (index != options.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}
