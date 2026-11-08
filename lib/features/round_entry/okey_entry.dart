import 'package:flutter/material.dart';

import '../../domain/models/round.dart';
import '../../domain/rules/okey_rules.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/score_format.dart';
import 'entry_widgets.dart';
import 'round_form.dart';

/// Kimin bitirdiği: bir koltuk ya da "Kimse bitiremedi".
sealed class Finisher {
  const Finisher();
}

class FinisherSeat extends Finisher {
  const FinisherSeat(this.seat);
  final int seat;

  @override
  bool operator ==(Object other) => other is FinisherSeat && other.seat == seat;

  @override
  int get hashCode => seat.hashCode;
}

class NoFinisher extends Finisher {
  const NoFinisher();

  @override
  bool operator ==(Object other) => other is NoFinisher;

  @override
  int get hashCode => 0;
}

/// Okey: bitiren, bitiş türü (varsayılan Normal) ve göstergeyi gösterenler.
class OkeyEntry extends RoundForm {
  const OkeyEntry({required super.game, super.editing, super.key});

  @override
  RoundFormState<OkeyEntry> createState() => _OkeyEntryState();
}

class _OkeyEntryState extends RoundFormState<OkeyEntry> {
  late final _rules = game.rules as OkeyRuleSet;
  late Finisher? _finisher = switch (editingInput<OkeyRoundInput>()) {
    null => null,
    OkeyRoundInput(finisherSeat: final seat?) => FinisherSeat(seat),
    _ => const NoFinisher(),
  };
  late OkeyFinish _finish =
      editingInput<OkeyRoundInput>()?.finish ?? OkeyFinish.normal;
  late final Set<int> _indicator = {
    ...?editingInput<OkeyRoundInput>()?.indicatorSeats,
  };

  @override
  List<String> formErrors(AppLocalizations l10n) => [
    if (_finisher == null) l10n.errorFinisherOrNobody,
  ];

  @override
  RoundInput buildInput() {
    final finisher = _finisher;
    return OkeyRoundInput(
      finisherSeat: finisher is FinisherSeat ? finisher.seat : null,
      finish: finisher is FinisherSeat ? _finish : OkeyFinish.normal,
      indicatorSeats: [..._indicator]..sort(),
    );
  }

  String _finishLabel(AppLocalizations l10n, OkeyFinish finish) =>
      switch (finish) {
        OkeyFinish.normal => l10n.okeyFinishNormal,
        OkeyFinish.okey => l10n.okeyFinishOkey,
        OkeyFinish.pairs => l10n.okeyFinishPairs,
        OkeyFinish.okeyPairs => l10n.okeyFinishOkeyPairs,
      };

  @override
  Widget buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                  onTap: () => change(() => _finisher = FinisherSeat(seat)),
                ),
              ChoiceTile(
                label: l10n.nobodyFinished,
                selected: _finisher == const NoFinisher(),
                onTap: () => change(() => _finisher = const NoFinisher()),
              ),
            ],
          ),
        ),
        if (_finisher is! NoFinisher)
          EntrySection(
            label: l10n.howFinishedLabel,
            child: ChoiceGrid(
              columns: 2,
              children: [
                for (final finish in OkeyFinish.values)
                  ChoiceTile(
                    label: _finishLabel(l10n, finish),
                    value: formatPoints(-_rules.lossFor(finish)),
                    selected: _finish == finish,
                    onTap: () => change(() => _finish = finish),
                  ),
              ],
            ),
          ),
        EntrySection(
          label: l10n.indicatorShownLabel,
          hint: l10n.indicatorShownHint(formatPoints(-_rules.indicator)),
          child: ChoiceGrid(
            columns: 2,
            children: [
              for (var seat = 0; seat < seatNames.length; seat++)
                ChoiceTile(
                  label: seatNames[seat],
                  exclusive: false,
                  selected: _indicator.contains(seat),
                  onTap: () => change(() {
                    if (!_indicator.remove(seat)) _indicator.add(seat);
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
