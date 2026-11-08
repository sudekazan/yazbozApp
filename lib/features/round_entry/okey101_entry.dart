import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/round.dart';
import '../../domain/rules/okey101_rules.dart';
import '../../domain/validation.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/score_format.dart';
import 'entry_widgets.dart';
import 'number_entry.dart';
import 'number_fields.dart';
import 'okey_entry.dart' show Finisher, FinisherSeat, NoFinisher;
import 'round_form.dart';

/// 101: bitiren ve bitiş biçimi, her oyuncunun kalan taşları ya da
/// açamadığı, elden ayrı cezalar.
class Okey101Entry extends RoundForm {
  const Okey101Entry({required super.game, super.editing, super.key});

  @override
  RoundFormState<Okey101Entry> createState() => _Okey101EntryState();
}

class _Okey101EntryState extends RoundFormState<Okey101Entry> {
  late final _rules = game.rules as Okey101RuleSet;
  late final Okey101RoundInput? _old = editingInput<Okey101RoundInput>();

  late Finisher? _finisher = switch (_old) {
    null => null,
    Okey101RoundInput(finisherSeat: final seat?) => FinisherSeat(seat),
    _ => const NoFinisher(),
  };
  late bool _withOkey = _old?.withOkey ?? false;
  late bool _fromHand = _old?.fromHand ?? false;
  late bool _fromPairs = _old?.fromPairs ?? false;
  late final List<Okey101PlayerState> _states = [
    for (var seat = 0; seat < game.config.seatCount; seat++)
      _old != null && seat < _old.players.length
          ? _old.players[seat].state
          : Okey101PlayerState.opened,
  ];
  late final NumberFields _fields = NumberFields([
    for (var seat = 0; seat < game.config.seatCount; seat++)
      _old != null &&
              seat < _old.players.length &&
              _writes(seat) &&
              _old.players[seat].state != Okey101PlayerState.notOpened
          ? NumberEntry.fromValue(_old.players[seat].remaining)
          : const NumberEntry(),
  ])..focus = _firstWritable() ?? 0;
  late final List<Okey101Penalty> _penalties = [...?_old?.penalties];

  int? get _finisherSeat => switch (_finisher) {
    FinisherSeat(:final seat) => seat,
    _ => null,
  };

  /// Bu oyuncu kalan taş ya da açamadı yazar mı (bitiren ve eşi yazmaz).
  bool _writes(int seat) {
    final finisher = _finisherSeat;
    if (finisher == null) return true;
    return seat != finisher && game.config.partnerOf(finisher) != seat;
  }

  /// Kalan taş alanı yazılabilir mi.
  bool _hasField(int seat) =>
      _writes(seat) && _states[seat] != Okey101PlayerState.notOpened;

  int? _firstWritable() {
    for (var seat = 0; seat < game.config.seatCount; seat++) {
      if (_hasField(seat)) return seat;
    }
    return null;
  }

  /// Odak yazılamayan alanda kaldıysa ilk yazılabilir alana geçer.
  void _fixFocus() {
    if (!_hasField(_fields.focus)) {
      _fields.focusOn(context, _firstWritable() ?? 0);
    }
  }

  void _setFinisher(Finisher finisher) => change(() {
    _finisher = finisher;
    if (finisher is NoFinisher) {
      _withOkey = _fromHand = _fromPairs = false;
    }
    _fixFocus();
  });

  void _toggleState(int seat, Okey101PlayerState state) => change(() {
    _states[seat] = _states[seat] == state ? Okey101PlayerState.opened : state;
    _fixFocus();
  });

  @override
  List<String> formErrors(AppLocalizations l10n) => [
    if (_finisher == null) l10n.errorFinisherOrNobody,
  ];

  @override
  RoundInput buildInput() => Okey101RoundInput(
    finisherSeat: _finisherSeat,
    withOkey: _withOkey,
    fromHand: _fromHand,
    fromPairs: _fromPairs,
    players: [
      for (var seat = 0; seat < _states.length; seat++)
        Okey101Player(
          state: _states[seat],
          remaining: _hasField(seat) ? _fields.entries[seat].value : 0,
        ),
    ],
    penalties: [..._penalties],
  );

  @override
  bool get showsPreview => false;

  @override
  Widget? buildKeypad(BuildContext context) => _fields.keypad(
    context,
    change: change,
    allowNegative: false,
    enabled: _hasField,
  );

  int _penaltyAmount(Okey101Penalty penalty) => switch (penalty.kind) {
    Okey101PenaltyKind.tileToMeld => _rules.penaltyTileToMeld,
    Okey101PenaltyKind.discardOkey => _rules.penaltyDiscardOkey,
    Okey101PenaltyKind.wrongOpen => _rules.penaltyWrongOpen,
    Okey101PenaltyKind.custom => penalty.amount ?? 0,
  };

  Future<void> _addPenalty() async {
    final penalty = await showDialog<Okey101Penalty>(
      context: context,
      builder: (context) => _PenaltyDialog(names: seatNames, rules: _rules),
    );
    if (penalty != null) change(() => _penalties.add(penalty));
  }

  @override
  Widget buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final points = previewPoints;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EntrySection(
          label: l10n.whoFinishedLabel,
          child: ChoiceGrid(
            columns: 2,
            children: [
              for (var seat = 0; seat < seatNames.length; seat++)
                ChoiceTile(
                  label: seatNames[seat],
                  selected: _finisher == FinisherSeat(seat),
                  onTap: () => _setFinisher(FinisherSeat(seat)),
                ),
              ChoiceTile(
                label: l10n.nobodyFinished,
                selected: _finisher == const NoFinisher(),
                onTap: () => _setFinisher(const NoFinisher()),
              ),
            ],
          ),
        ),
        if (_finisher is FinisherSeat)
          EntrySection(
            label: l10n.howFinishedLabel,
            hint: l10n.multipliersHint,
            child: ChoiceGrid(
              columns: 3,
              children: [
                ChoiceTile(
                  label: l10n.okey101WithOkey(_rules.okeyMultiplier),
                  exclusive: false,
                  selected: _withOkey,
                  onTap: () => change(() => _withOkey = !_withOkey),
                ),
                ChoiceTile(
                  label: l10n.okey101FromHand(_rules.handFinishMultiplier),
                  exclusive: false,
                  selected: _fromHand,
                  onTap: () => change(() => _fromHand = !_fromHand),
                ),
                ChoiceTile(
                  label: l10n.okey101FromPairs(_rules.pairsFinishMultiplier),
                  exclusive: false,
                  selected: _fromPairs,
                  onTap: () => change(() => _fromPairs = !_fromPairs),
                ),
              ],
            ),
          ),
        EntrySection(
          label: l10n.remainingTilesLabel,
          child: Column(
            children: [
              for (var seat = 0; seat < seatNames.length; seat++)
                _PlayerRow(
                  key: _fields.keys[seat],
                  name: seatNames[seat],
                  status: !_writes(seat)
                      ? (seat == _finisherSeat
                            ? l10n.playerFinished
                            : l10n.partnerFinished)
                      : null,
                  state: _states[seat],
                  entry: _fields.entries[seat],
                  focused: _fields.focus == seat,
                  hasField: _hasField(seat),
                  points: points?[seat],
                  onFocus: () => change(() => _fields.focusOn(context, seat)),
                  onToggle: (state) => _toggleState(seat, state),
                ),
            ],
          ),
        ),
        EntrySection(
          label: l10n.penaltiesLabel,
          hint: l10n.penaltiesHint,
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < _penalties.length; i++)
                InputChip(
                  label: Text(
                    l10n.penaltyChip(
                      seatNames[_penalties[i].seat],
                      _penaltyKindLabel(l10n, _penalties[i].kind),
                      formatPoints(_penaltyAmount(_penalties[i])),
                    ),
                  ),
                  deleteButtonTooltipMessage: l10n.removePenalty,
                  onDeleted: () => change(() => _penalties.removeAt(i)),
                ),
              TextButton.icon(
                onPressed: _addPenalty,
                icon: const Icon(Icons.add),
                label: Text(l10n.addPenaltyButton),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _penaltyKindLabel(AppLocalizations l10n, Okey101PenaltyKind kind) =>
    switch (kind) {
      Okey101PenaltyKind.tileToMeld => l10n.penaltyTileToMeld,
      Okey101PenaltyKind.discardOkey => l10n.penaltyDiscardOkey,
      Okey101PenaltyKind.wrongOpen => l10n.penaltyWrongOpen,
      Okey101PenaltyKind.custom => l10n.penaltyCustom,
    };

/// Oyuncu satırı: isim, Çift/Açamadı seçimi, kalan taş alanı, el puanı.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.name,
    required this.status,
    required this.state,
    required this.entry,
    required this.focused,
    required this.hasField,
    required this.points,
    required this.onFocus,
    required this.onToggle,
    super.key,
  });

  final String name;

  /// "Bitirdi" ya da "Eşi bitirdi"; oyuncu yazıyorsa `null`.
  final String? status;
  final Okey101PlayerState state;
  final NumberEntry entry;
  final bool focused;
  final bool hasField;
  final int? points;
  final VoidCallback onFocus;
  final ValueChanged<Okey101PlayerState> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pointsText = points == null ? '–' : formatPoints(points!);
    return DecoratedBox(
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
                  const SizedBox(height: AppSpacing.xxs),
                  if (status != null)
                    Text(
                      status!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        FilterChip(
                          label: Text(l10n.openedPairsChip),
                          tooltip: l10n.openedPairsTooltip(name),
                          selected: state == Okey101PlayerState.openedPairs,
                          onSelected: (_) =>
                              onToggle(Okey101PlayerState.openedPairs),
                        ),
                        FilterChip(
                          label: Text(l10n.notOpenedChip),
                          tooltip: l10n.notOpenedTooltip(name),
                          selected: state == Okey101PlayerState.notOpened,
                          onSelected: (_) =>
                              onToggle(Okey101PlayerState.notOpened),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Semantics(
              button: hasField,
              selected: focused && hasField,
              label: l10n.remainingFieldSemantics(
                name,
                hasField ? (entry.isEmpty ? '0' : entry.display) : '–',
              ),
              excludeSemantics: true,
              onTap: hasField ? onFocus : null,
              child: GestureDetector(
                onTap: hasField ? onFocus : null,
                child: NumberFieldBox(
                  entry: entry,
                  focused: focused,
                  enabled: hasField,
                ),
              ),
            ),
            SizedBox(
              width: AppSizes.entryPointsWidth,
              child: Semantics(
                label: l10n.roundPointsSemantics(pointsText),
                excludeSemantics: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    pointsText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ceza ekleme: kime, hangi ceza; "Diğer" seçilirse tutar.
class _PenaltyDialog extends StatefulWidget {
  const _PenaltyDialog({required this.names, required this.rules});

  final List<String> names;
  final Okey101RuleSet rules;

  @override
  State<_PenaltyDialog> createState() => _PenaltyDialogState();
}

class _PenaltyDialogState extends State<_PenaltyDialog> {
  int? _seat;
  Okey101PenaltyKind? _kind;
  final _amount = TextEditingController();
  bool _attempted = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? get _customAmount {
    final value = int.tryParse(_amount.text);
    return value != null && value > 0 && value <= Limits.maxAbsPoints
        ? value
        : null;
  }

  void _add() {
    final seat = _seat;
    final kind = _kind;
    final custom = kind == Okey101PenaltyKind.custom;
    if (seat == null || kind == null || (custom && _customAmount == null)) {
      setState(() => _attempted = true);
      return;
    }
    Navigator.of(context).pop(
      Okey101Penalty(
        seat: seat,
        kind: kind,
        amount: custom ? _customAmount : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rules = widget.rules;
    final kinds = {
      Okey101PenaltyKind.tileToMeld: rules.penaltyTileToMeld,
      Okey101PenaltyKind.discardOkey: rules.penaltyDiscardOkey,
      Okey101PenaltyKind.wrongOpen: rules.penaltyWrongOpen,
      Okey101PenaltyKind.custom: null,
    };
    final errors = [
      if (_attempted && _seat == null) l10n.errorPenaltyPlayer,
      if (_attempted && _kind == null) l10n.errorPenaltyKind,
      if (_attempted &&
          _kind == Okey101PenaltyKind.custom &&
          _customAmount == null)
        l10n.errorPenaltyAmount(Limits.maxAbsPoints),
    ];
    return AlertDialog(
      title: Text(l10n.addPenaltyButton),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EntrySection(
            label: l10n.penaltyWhoLabel,
            child: ChoiceGrid(
              columns: 2,
              children: [
                for (var seat = 0; seat < widget.names.length; seat++)
                  ChoiceTile(
                    label: widget.names[seat],
                    selected: _seat == seat,
                    onTap: () => setState(() => _seat = seat),
                  ),
              ],
            ),
          ),
          EntrySection(
            label: l10n.penaltyKindLabel,
            child: ChoiceGrid(
              columns: 1,
              children: [
                for (final MapEntry(key: kind, value: amount) in kinds.entries)
                  ChoiceTile(
                    label: _penaltyKindLabel(l10n, kind),
                    value: amount == null ? null : '+$amount',
                    selected: _kind == kind,
                    onTap: () => setState(() => _kind = kind),
                  ),
              ],
            ),
          ),
          if (_kind == Okey101PenaltyKind.custom)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: TextField(
                key: const ValueKey('penalty-amount'),
                controller: _amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l10n.penaltyAmountLabel),
              ),
            ),
          if (errors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: EntryErrors(errors),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        TextButton(onPressed: _add, child: Text(l10n.addPenaltyButton)),
      ],
    );
  }
}
