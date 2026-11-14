import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';

/// Eksi/artı düğmeli sayı seçici. Düğmeler 48x48; sınırda pasifleşir.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    required this.value,
    required this.onChanged,
    required this.decreaseLabel,
    required this.increaseLabel,
    this.min = 0,
    this.max = 99,
    super.key,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String decreaseLabel;
  final String increaseLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: decreaseLabel,
            icon: const Icon(Icons.remove),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: AppSpacing.xl),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
          ),
          IconButton(
            tooltip: increaseLabel,
            icon: const Icon(Icons.add),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// Bir kontrolün üstündeki kısa etiket.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
