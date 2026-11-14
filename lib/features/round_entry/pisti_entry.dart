import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../domain/models/round.dart';
import '../../domain/rules/pisti_rules.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/number_stepper.dart';
import 'entry_widgets.dart';
import 'number_entry.dart';
import 'number_fields.dart';
import 'round_form.dart';

enum _Counter { pisti, jackPisti, aces, jacks }

/// Kart çoğunluğu seçimi: bir sütun ya da "Eşit".
sealed class _Majority {
  const _Majority();
}

class _MajorityUnit extends _Majority {
  const _MajorityUnit(this.unit);
  final int unit;

  @override
  bool operator ==(Object other) =>
      other is _MajorityUnit && other.unit == unit;

  @override
  int get hashCode => unit.hashCode;
}

class _MajorityTie extends _Majority {
  const _MajorityTie();

  @override
  bool operator ==(Object other) => other is _MajorityTie;

  @override
  int get hashCode => 0;
}

/// Pişti: sayaçla (pişti, as, vale ve tek sahipli kartlar) ya da doğrudan
/// puan.
class PistiEntry extends RoundForm {
  const PistiEntry({required super.game, super.editing, super.key});

  @override
  RoundFormState<PistiEntry> createState() => _PistiEntryState();
}

class _PistiEntryState extends RoundFormState<PistiEntry> {
  late final _rules = game.rules as PistiRuleSet;
  late final int _units = game.engine.units(game.config).length;
  late final PistiCountInput? _oldCounts = editingInput<PistiCountInput>();
  late final PistiDirectInput? _oldDirect = editingInput<PistiDirectInput>();

  late bool _direct = _oldDirect != null;

  late final List<Map<_Counter, int>> _counts = [
    for (var unit = 0; unit < _units; unit++)
      switch (_oldCounts) {
        final old? when unit < old.counts.length => {
          _Counter.pisti: old.counts[unit].pisti,
          _Counter.jackPisti: old.counts[unit].jackPisti,
          _Counter.aces: old.counts[unit].aces,
          _Counter.jacks: old.counts[unit].jacks,
        },
        _ => {for (final c in _Counter.values) c: 0},
      },
  ];

  /// Elle değiştirilen as/vale sayaçları; değiştirilmeyen taraf 4'ten
  /// kalanla dolar.
  late final Set<(_Counter, int)> _touched = _oldCounts == null
      ? {}
      : {
          for (var unit = 0; unit < _units; unit++) ...[
            (_Counter.aces, unit),
            (_Counter.jacks, unit),
          ],
        };

  late _Majority? _majority = switch (_oldCounts) {
    null => null,
    PistiCountInput(majorityUnit: final unit?) => _MajorityUnit(unit),
    _ => const _MajorityTie(),
  };
  late int? _clubTwo = _oldCounts?.clubTwoUnit;
  late int? _diamondTen = _oldCounts?.diamondTenUnit;

  late final NumberFields _fields = NumberFields([
    for (var unit = 0; unit < _units; unit++)
      switch (_oldDirect) {
        final old? when unit < old.points.length => NumberEntry.fromValue(
          old.points[unit],
        ),
        _ => const NumberEntry(),
      },
  ]);

  int _max(_Counter counter) => switch (counter) {
    _Counter.pisti || _Counter.jackPisti => PistiCounts.maxPisti,
    _Counter.aces || _Counter.jacks => PistiCounts.cardsPerRank,
  };

  void _setCount(_Counter counter, int unit, int value) => change(() {
    _counts[unit][counter] = value;
    final shared = counter == _Counter.aces || counter == _Counter.jacks;
    if (!shared) return;
    _touched.add((counter, unit));
    if (_units != 2) return;
    final other = 1 - unit;
    if (!_touched.contains((counter, other))) {
      final rest = PistiCounts.cardsPerRank - value;
      _counts[other][counter] = rest < 0 ? 0 : rest;
    }
  });

  @override
  List<String> formErrors(AppLocalizations l10n) => [
    if (!_direct && _majority == null) l10n.errorMajorityRequired,
  ];

  @override
  RoundInput buildInput() {
    if (_direct) {
      return PistiDirectInput([for (final e in _fields.entries) e.value]);
    }
    final majority = _majority;
    return PistiCountInput(
      counts: [
        for (final c in _counts)
          PistiCounts(
            pisti: c[_Counter.pisti]!,
            jackPisti: c[_Counter.jackPisti]!,
            aces: c[_Counter.aces]!,
            jacks: c[_Counter.jacks]!,
          ),
      ],
      majorityUnit: majority is _MajorityUnit ? majority.unit : null,
      clubTwoUnit: _clubTwo,
      diamondTenUnit: _diamondTen,
    );
  }

  @override
  Widget? buildKeypad(BuildContext context) =>
      _direct ? _fields.keypad(context, change: change) : null;

  String _counterLabel(AppLocalizations l10n, _Counter counter) =>
      switch (counter) {
        _Counter.pisti => l10n.rulePisti,
        _Counter.jackPisti => l10n.ruleJackPisti,
        _Counter.aces => l10n.pistiAces,
        _Counter.jacks => l10n.pistiJacks,
      };

  String _counterHint(AppLocalizations l10n, _Counter counter) =>
      switch (counter) {
        _Counter.pisti => l10n.perItem(_rules.pisti),
        _Counter.jackPisti => l10n.perItem(_rules.jackPisti),
        _Counter.aces => l10n.perItemOfFour(_rules.ace),
        _Counter.jacks => l10n.perItemOfFour(_rules.jack),
      };

  @override
  Widget buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l10n.pistiCountMode)),
            ButtonSegment(value: true, label: Text(l10n.pistiDirectMode)),
          ],
          selected: {_direct},
          onSelectionChanged: (s) => change(() => _direct = s.single),
        ),
        if (_direct) ..._directRows(l10n) else ..._countRows(l10n),
      ],
    );
  }

  List<Widget> _directRows(AppLocalizations l10n) => [
    const SizedBox(height: AppSpacing.xs),
    for (var unit = 0; unit < _units; unit++)
      Semantics(
        key: _fields.keys[unit],
        button: true,
        selected: _fields.focus == unit,
        label: l10n.directPointsSemantics(
          unitNames[unit],
          _fields.entries[unit].isEmpty ? '0' : _fields.entries[unit].display,
        ),
        excludeSemantics: true,
        onTap: () => change(() => _fields.focusOn(context, unit)),
        child: InkWell(
          onTap: () => change(() => _fields.focusOn(context, unit)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    unitNames[unit],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                NumberFieldBox(
                  entry: _fields.entries[unit],
                  focused: _fields.focus == unit,
                ),
              ],
            ),
          ),
        ),
      ),
  ];

  List<Widget> _countRows(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return [
      for (final counter in _Counter.values)
        EntrySection(
          label: _counterLabel(l10n, counter),
          hint: _counterHint(l10n, counter),
          child: Row(
            children: [
              for (var unit = 0; unit < _units; unit++) ...[
                if (unit > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        unitNames[unit],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: NumberStepper(
                          value: _counts[unit][counter]!,
                          max: _max(counter),
                          decreaseLabel: l10n.counterDecrease(
                            unitNames[unit],
                            _counterLabel(l10n, counter),
                          ),
                          increaseLabel: l10n.counterIncrease(
                            unitNames[unit],
                            _counterLabel(l10n, counter),
                          ),
                          onChanged: (v) => _setCount(counter, unit, v),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      EntrySection(
        label: l10n.ruleMajority,
        hint: '+${_rules.majority}',
        child: ChoiceGrid(
          columns: 3,
          children: [
            ChoiceTile(
              label: unitNames[0],
              selected: _majority == const _MajorityUnit(0),
              onTap: () => change(() => _majority = const _MajorityUnit(0)),
            ),
            ChoiceTile(
              label: l10n.majorityTie,
              selected: _majority == const _MajorityTie(),
              onTap: () => change(() => _majority = const _MajorityTie()),
            ),
            for (var unit = 1; unit < _units; unit++)
              ChoiceTile(
                label: unitNames[unit],
                selected: _majority == _MajorityUnit(unit),
                onTap: () => change(() => _majority = _MajorityUnit(unit)),
              ),
          ],
        ),
      ),
      _ownerSection(
        l10n.ruleClubTwo,
        _rules.clubTwo,
        _clubTwo,
        (unit) => _clubTwo = unit,
      ),
      _ownerSection(
        l10n.ruleDiamondTen,
        _rules.diamondTen,
        _diamondTen,
        (unit) => _diamondTen = unit,
      ),
    ];
  }

  Widget _ownerSection(
    String label,
    int points,
    int? selected,
    void Function(int unit) select,
  ) => EntrySection(
    label: label,
    hint: '+$points',
    child: ChoiceGrid(
      columns: _units,
      children: [
        for (var unit = 0; unit < _units; unit++)
          ChoiceTile(
            label: unitNames[unit],
            selected: selected == unit,
            onTap: () => change(() => select(unit)),
          ),
      ],
    ),
  );
}
