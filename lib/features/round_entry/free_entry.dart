import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/round.dart';
import '../../domain/rules/free_rules.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/score_format.dart';
import 'number_entry.dart';
import 'number_fields.dart';
import 'round_form.dart';

/// Serbest: her oyuncuya sayı girilir; boş alan 0 sayılır.
class FreeEntry extends RoundForm {
  const FreeEntry({required super.game, super.editing, super.key});

  @override
  RoundFormState<FreeEntry> createState() => _FreeEntryState();
}

class _FreeEntryState extends RoundFormState<FreeEntry> {
  late final NumberFields _fields = NumberFields([
    for (var seat = 0; seat < game.config.seatCount; seat++)
      switch (editingInput<FreeRoundInput>()) {
        final input? when seat < input.points.length => NumberEntry.fromValue(
          input.points[seat],
        ),
        _ => const NumberEntry(),
      },
  ]);

  /// Bu el olmadan her sütunun toplamı; önizleme bunun üstüne eklenir.
  late final List<int> _baseTotals = () {
    final totals = [...game.status.unitTotals];
    final old = widget.editing?.round.result.points;
    if (old != null) {
      for (var i = 0; i < totals.length && i < old.length; i++) {
        totals[i] -= old[i];
      }
    }
    return totals;
  }();

  @override
  bool get showsPreview => false;

  @override
  RoundInput buildInput() =>
      FreeRoundInput([for (final e in _fields.entries) e.value]);

  @override
  Widget? buildKeypad(BuildContext context) =>
      _fields.keypad(context, change: change);

  @override
  Widget buildBody(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var seat = 0; seat < _fields.entries.length; seat++)
        _EntryRow(
          key: _fields.keys[seat],
          name: seatNames[seat],
          entry: _fields.entries[seat],
          newTotal: _baseTotals[seat] + _fields.entries[seat].value,
          focused: seat == _fields.focus,
          onTap: () => change(() => _fields.focusOn(context, seat)),
        ),
    ],
  );
}

/// Oyuncu satırı: isim, yeni toplam önizlemesi ve puan alanı.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.name,
    required this.entry,
    required this.newTotal,
    required this.focused,
    required this.onTap,
    super.key,
  });

  final String name;
  final NumberEntry entry;
  final int newTotal;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = formatPoints(newTotal);

    return Semantics(
      button: true,
      selected: focused,
      label: l10n.pointsFieldSemantics(
        name,
        entry.isEmpty ? '0' : entry.display,
        total,
      ),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        l10n.newTotalPreview(total),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: AppTypography.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                NumberFieldBox(entry: entry, focused: focused),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
