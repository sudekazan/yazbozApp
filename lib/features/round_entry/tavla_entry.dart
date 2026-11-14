import 'package:flutter/material.dart';

import '../../domain/models/round.dart';
import '../../domain/rules/tavla_rules.dart';
import '../../l10n/generated/app_localizations.dart';
import 'entry_widgets.dart';
import 'round_form.dart';

/// Tavla: kazanan, Normal ya da Mars, katlama küpü açıksa küp değeri.
class TavlaEntry extends RoundForm {
  const TavlaEntry({required super.game, super.editing, super.key});

  @override
  RoundFormState<TavlaEntry> createState() => _TavlaEntryState();
}

class _TavlaEntryState extends RoundFormState<TavlaEntry> {
  late final _rules = game.rules as TavlaRuleSet;
  late int? _winner = editingInput<TavlaRoundInput>()?.winnerSeat;
  late TavlaWin _win = editingInput<TavlaRoundInput>()?.win ?? TavlaWin.normal;
  late int _cube = editingInput<TavlaRoundInput>()?.cube ?? 1;

  @override
  List<String> formErrors(AppLocalizations l10n) => [
    if (_winner == null) l10n.errorWinnerRequired,
  ];

  @override
  RoundInput buildInput() => TavlaRoundInput(
    winnerSeat: _winner ?? 0,
    win: _win,
    cube: _rules.doublingCube ? _cube : 1,
  );

  @override
  Widget buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EntrySection(
          label: l10n.whoWonLabel,
          child: ChoiceGrid(
            columns: 2,
            children: [
              for (var seat = 0; seat < seatNames.length; seat++)
                ChoiceTile(
                  label: seatNames[seat],
                  selected: _winner == seat,
                  onTap: () => change(() => _winner = seat),
                ),
            ],
          ),
        ),
        EntrySection(
          label: l10n.howWonLabel,
          child: ChoiceGrid(
            columns: 2,
            children: [
              ChoiceTile(
                label: l10n.tavlaNormal,
                value: '${_rules.normalPoints}',
                selected: _win == TavlaWin.normal,
                onTap: () => change(() => _win = TavlaWin.normal),
              ),
              ChoiceTile(
                label: l10n.tavlaMars,
                value: '${_rules.marsPoints}',
                selected: _win == TavlaWin.mars,
                onTap: () => change(() => _win = TavlaWin.mars),
              ),
            ],
          ),
        ),
        if (_rules.doublingCube)
          EntrySection(
            label: l10n.ruleDoublingCube,
            child: ChoiceGrid(
              columns: 4,
              children: [
                for (final value in TavlaRuleSet.cubeValues)
                  ChoiceTile(
                    label: l10n.multiplierBadge(value),
                    selected: _cube == value,
                    onTap: () => change(() => _cube = value),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
