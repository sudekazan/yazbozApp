import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import 'number_entry.dart';
import 'number_keypad.dart';

/// Tuş takımıyla doldurulan sayı alanlarının ortak durumu: değerler, odak
/// ve odaktaki satırın görünür tutulması.
class NumberFields {
  NumberFields(List<NumberEntry> initial)
    : entries = [...initial],
      keys = List.generate(initial.length, (_) => GlobalKey());

  final List<NumberEntry> entries;
  final List<GlobalKey> keys;
  int focus = 0;

  /// Odağı [index] alanına taşır ve satırı görünür yapar.
  void focusOn(BuildContext context, int index) {
    final down = index > focus;
    focus = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = keys[index].currentContext;
      if (row == null || !context.mounted) return;
      Scrollable.ensureVisible(
        row,
        duration: AppDurations.resolve(context, AppDurations.medium),
        alignmentPolicy: down
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  /// Tuş takımı; [enabled] yazılabilen alanları söyler, oklar onları atlar.
  /// [change] durum değişikliğini sarar (setState).
  Widget keypad(
    BuildContext context, {
    required void Function(VoidCallback) change,
    bool allowNegative = true,
    bool Function(int index)? enabled,
  }) {
    bool canWrite(int i) => enabled?.call(i) ?? true;
    int? step(int direction) {
      for (
        var i = focus + direction;
        i >= 0 && i < entries.length;
        i += direction
      ) {
        if (canWrite(i)) return i;
      }
      return null;
    }

    void edit(NumberEntry Function(NumberEntry) fn) {
      if (!canWrite(focus)) return;
      change(() => entries[focus] = fn(entries[focus]));
    }

    final previous = step(-1);
    final next = step(1);
    return NumberKeypad(
      onDigit: (d) => edit((e) => e.addDigit(d)),
      onMinus: allowNegative ? () => edit((e) => e.toggleSign()) : null,
      onBackspace: () => edit((e) => e.backspace()),
      onClear: () => edit((_) => const NumberEntry()),
      onPrevious: previous == null
          ? null
          : () => change(() => focusOn(context, previous)),
      onNext: next == null ? null : () => change(() => focusOn(context, next)),
    );
  }
}

/// Tuş takımıyla yazılan alanın görünümü (sistem klavyesi açılmaz).
class NumberFieldBox extends StatelessWidget {
  const NumberFieldBox({
    required this.entry,
    required this.focused,
    this.enabled = true,
    this.disabledText = '–',
    super.key,
  });

  final NumberEntry entry;
  final bool focused;
  final bool enabled;

  /// Alan kullanılmıyorsa görünen metin.
  final String disabledText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final score = theme.extension<ScoreTextTheme>()!;
    final empty = entry.isEmpty && !entry.negative;
    return Container(
      width: AppSizes.entryFieldWidth,
      constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      alignment: AlignmentDirectional.centerEnd,
      decoration: BoxDecoration(
        color: enabled ? scheme.surfaceContainerLow : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: focused && enabled
            ? Border.all(color: scheme.primary, width: AppSizes.focusOutline)
            : Border.all(
                color: enabled ? scheme.outline : scheme.outlineVariant,
              ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          !enabled
              ? disabledText
              : empty
              ? '0'
              : entry.display,
          maxLines: 1,
          style: score.entry.copyWith(
            color: !enabled || empty ? scheme.onSurfaceVariant : null,
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      ),
    );
  }
}
