import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/haptics.dart';

/// Sistem klavyesi yerine büyük numerik tuş takımı:
///
/// ```
/// 1 2 3 ⌫
/// 4 5 6 −
/// 7 8 9 ↑
/// 0     ↓
/// ```
class NumberKeypad extends StatelessWidget {
  const NumberKeypad({
    required this.onDigit,
    this.onMinus,
    required this.onBackspace,
    required this.onClear,
    this.onPrevious,
    this.onNext,
    super.key,
  });

  final ValueChanged<int> onDigit;

  /// Eksi girilemeyen alanlarda `null` (tuş pasif).
  final VoidCallback? onMinus;
  final VoidCallback onBackspace;

  /// Silme tuşuna uzun basınca alanı temizler.
  final VoidCallback onClear;

  /// İlk alandayken `null` (tuş pasif).
  final VoidCallback? onPrevious;

  /// Son alandayken `null` (tuş pasif).
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget digit(int d) => _Key.text('$d', onTap: () => onDigit(d));

    Widget row(List<Widget> keys) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            keys[i],
          ],
        ],
      ),
    );

    return Semantics(
      container: true,
      label: l10n.keypadLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row([
            digit(1),
            digit(2),
            digit(3),
            _Key.icon(
              Icons.backspace_outlined,
              label: l10n.keypadBackspace,
              onTap: onBackspace,
              onLongPress: onClear,
            ),
          ]),
          row([
            digit(4),
            digit(5),
            digit(6),
            _Key.text('−', label: l10n.keypadMinus, onTap: onMinus),
          ]),
          row([
            digit(7),
            digit(8),
            digit(9),
            _Key.icon(
              Icons.keyboard_arrow_up,
              label: l10n.keypadPrevious,
              onTap: onPrevious,
            ),
          ]),
          row([
            _Key.text('0', flex: 3, onTap: () => onDigit(0)),
            _Key.icon(
              Icons.keyboard_arrow_down,
              label: l10n.keypadNext,
              onTap: onNext,
            ),
          ]),
        ],
      ),
    );
  }
}

class _Key extends ConsumerWidget {
  const _Key.text(
    String this.text, {
    required this.onTap,
    this.label,
    this.flex = 1,
  }) : icon = null,
       onLongPress = null;

  const _Key.icon(
    IconData this.icon, {
    required String this.label,
    required this.onTap,
    this.onLongPress,
  }) : text = null,
       flex = 1;

  final String? text;
  final IconData? icon;
  final String? label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final int flex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    final tap = onTap == null
        ? null
        : () {
            ref.lightHaptic();
            onTap!();
          };
    final color = enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: AppOpacity.disabled);
    final keyStyle = theme.extension<ScoreTextTheme>()!.key.copyWith(
      color: color,
    );

    Widget child = SizedBox(
      height: AppSizes.keypadKeyHeight,
      child: Center(
        child: icon != null
            ? Icon(icon, color: color)
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text!,
                  style: keyStyle.copyWith(
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ),
      ),
    );
    child = Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: tap, onLongPress: onLongPress, child: child),
    );
    if (icon != null) child = Tooltip(message: label, child: child);

    return Expanded(
      flex: flex,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label ?? text,
        excludeSemantics: true,
        onTap: tap,
        child: child,
      ),
    );
  }
}
