import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/round.dart';
import '../../domain/rules/batak_rules.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/number_stepper.dart';
import '../common/score_format.dart';
import 'entry_widgets.dart';
import 'round_form.dart';

/// Batak: ihaleliyse ihaleyi alan, ihale ve koz; her oyuncunun (eşlide
/// takımın) aldığı el. Son sütun kalanla dolar, değiştirilebilir.
class BatakEntry extends RoundForm {
  const BatakEntry({required super.game, super.editing, super.key});

  @override
  RoundFormState<BatakEntry> createState() => _BatakEntryState();
}

class _BatakEntryState extends RoundFormState<BatakEntry> {
  late final _rules = game.rules as BatakRuleSet;
  late final bool _bidding = _rules.mode == BatakMode.bidding;
  late final int _perDeal = BatakGameRules.tricksPerDeal(game.config);
  late final int _units = game.engine.units(game.config).length;
  late final BatakRoundInput? _old = editingInput<BatakRoundInput>();

  late int? _bidder = _old?.bidderSeat;
  late int _bid = _old?.bid ?? _rules.minBid;
  late BatakSuit? _trump = _old?.trump;
  late final List<int> _tricks = _old != null && _old.tricks.length == _units
      ? [..._old.tricks]
      : [
          for (var unit = 0; unit < _units; unit++)
            unit == _units - 1 ? _perDeal : 0,
        ];

  /// Son sütun elle değiştirildiyse artık kendiliğinden dolmaz.
  late bool _lastTouched = _old != null;

  void _setTricks(int unit, int value) => change(() {
    _tricks[unit] = value;
    final last = _units - 1;
    if (unit == last) {
      _lastTouched = true;
      return;
    }
    if (_lastTouched) return;
    var others = 0;
    for (var u = 0; u < last; u++) {
      others += _tricks[u];
    }
    _tricks[last] = (_perDeal - others).clamp(0, _perDeal);
  });

  @override
  RoundInput buildInput() => BatakRoundInput(
    bidderSeat: _bidding ? _bidder : null,
    bid: _bidding ? _bid : null,
    trump: _bidding ? _trump : null,
    tricks: [..._tricks],
  );

  @override
  bool get showsPreview => false;

  String _suitLabel(AppLocalizations l10n, BatakSuit suit) => switch (suit) {
    BatakSuit.clubs => l10n.suitClubs,
    BatakSuit.diamonds => l10n.suitDiamonds,
    BatakSuit.hearts => l10n.suitHearts,
    BatakSuit.spades => l10n.suitSpades,
  };

  @override
  Widget buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final points = previewPoints;
    final bidderUnit = _bidder == null
        ? null
        : game.engine
              .units(game.config)
              .indexWhere((u) => u.contains(_bidder!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_bidding) ...[
          EntrySection(
            label: l10n.bidderLabel,
            child: ChoiceGrid(
              columns: 2,
              children: [
                for (var seat = 0; seat < seatNames.length; seat++)
                  ChoiceTile(
                    label: seatNames[seat],
                    selected: _bidder == seat,
                    onTap: () => change(() => _bidder = seat),
                  ),
              ],
            ),
          ),
          EntrySection(
            label: l10n.bidLabel,
            hint: l10n.bidRange(_rules.minBid, _perDeal),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: NumberStepper(
                value: _bid,
                min: _rules.minBid,
                max: _perDeal,
                decreaseLabel: l10n.decreaseBid,
                increaseLabel: l10n.increaseBid,
                onChanged: (v) => change(() => _bid = v),
              ),
            ),
          ),
          EntrySection(
            label: l10n.trumpLabel,
            hint: l10n.optionalHint,
            child: ChoiceGrid(
              columns: 4,
              children: [
                for (final suit in BatakSuit.values)
                  ChoiceTile(
                    label: _suitLabel(l10n, suit),
                    selected: _trump == suit,
                    onTap: () =>
                        change(() => _trump = _trump == suit ? null : suit),
                  ),
              ],
            ),
          ),
        ],
        EntrySection(
          label: l10n.tricksLabel,
          hint: l10n.tricksTotalHint(_perDeal),
          child: Column(
            children: [
              for (var unit = 0; unit < _units; unit++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                unitNames[unit],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                              if (_bidding && unit == bidderUnit)
                                Text(
                                  _tricks[unit] >= _bid
                                      ? l10n.bidMade(_bid)
                                      : l10n.bidFailed(_bid),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: NumberStepper(
                            value: _tricks[unit],
                            max: _perDeal,
                            decreaseLabel: l10n.decreaseTricks(unitNames[unit]),
                            increaseLabel: l10n.increaseTricks(unitNames[unit]),
                            onChanged: (v) => _setTricks(unit, v),
                          ),
                        ),
                        SizedBox(
                          width: AppSizes.entryPointsWidth,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerEnd,
                            child: Text(
                              points == null ? '–' : formatPoints(points[unit]),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontFeatures: AppTypography.tabularFigures,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
