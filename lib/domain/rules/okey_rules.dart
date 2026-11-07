import '../models/game.dart';
import '../models/game_config.dart';
import '../models/game_status.dart';
import '../models/json_read.dart';
import '../models/round.dart';
import '../models/rule_set.dart';
import 'game_rules.dart';

/// Klasik okeyde bitiş türü.
enum OkeyFinish { normal, okey, pairs, okeyPairs }

/// Klasik (puan düşmeli) okey: herkes başlangıç puanıyla başlar, puanı
/// 0'a inen oyunu bitirir, en yüksek puan kalan kazanır.
class OkeyRuleSet extends RuleSet {
  const OkeyRuleSet({
    this.startingPoints = 20,
    this.normalFinish = 2,
    this.okeyFinish = 4,
    this.pairsFinish = 4,
    this.okeyPairsFinish = 8,
    this.indicator = 1,
  });

  factory OkeyRuleSet.fromJson(Map<String, Object?> json) {
    const d = OkeyRuleSet();
    return OkeyRuleSet(
      startingPoints: readInt(json, 'startingPoints', d.startingPoints),
      normalFinish: readInt(json, 'normalFinish', d.normalFinish),
      okeyFinish: readInt(json, 'okeyFinish', d.okeyFinish),
      pairsFinish: readInt(json, 'pairsFinish', d.pairsFinish),
      okeyPairsFinish: readInt(json, 'okeyPairsFinish', d.okeyPairsFinish),
      indicator: readInt(json, 'indicator', d.indicator),
    );
  }

  final int startingPoints;

  /// Bitiş türüne göre bitiren hariç herkesin kaybettiği puan.
  final int normalFinish;
  final int okeyFinish;
  final int pairsFinish;
  final int okeyPairsFinish;

  /// Gösterge gösteren hariç herkesin kaybettiği puan.
  final int indicator;

  int lossFor(OkeyFinish finish) => switch (finish) {
    OkeyFinish.normal => normalFinish,
    OkeyFinish.okey => okeyFinish,
    OkeyFinish.pairs => pairsFinish,
    OkeyFinish.okeyPairs => okeyPairsFinish,
  };

  @override
  GameTemplate get template => GameTemplate.okey;

  @override
  Map<String, Object?> toJson() => {
    'v': RuleSet.jsonVersion,
    'template': template.name,
    'startingPoints': startingPoints,
    'normalFinish': normalFinish,
    'okeyFinish': okeyFinish,
    'pairsFinish': pairsFinish,
    'okeyPairsFinish': okeyPairsFinish,
    'indicator': indicator,
  };

  @override
  List<RuleError> validate() => [
    if (startingPoints <= 0) const RuleError('startingPoints'),
    if (normalFinish < 0) const RuleError('normalFinish'),
    if (okeyFinish < 0) const RuleError('okeyFinish'),
    if (pairsFinish < 0) const RuleError('pairsFinish'),
    if (okeyPairsFinish < 0) const RuleError('okeyPairsFinish'),
    if (indicator < 0) const RuleError('indicator'),
  ];
}

class OkeyRoundInput extends RoundInput {
  const OkeyRoundInput({
    this.finisherSeat,
    this.finish = OkeyFinish.normal,
    this.indicatorSeats = const [],
  });

  factory OkeyRoundInput.fromJson(Map<String, Object?> json) {
    requireType(json, 'okey');
    return OkeyRoundInput(
      finisherSeat: requireIntOrNull(json, 'finisherSeat'),
      finish: requireEnum(json, 'finish', OkeyFinish.values),
      indicatorSeats: requireIntList(json, 'indicatorSeats'),
    );
  }

  /// Eli bitiren koltuk; `null` ise kimse bitiremedi.
  final int? finisherSeat;
  final OkeyFinish finish;

  /// Gösterge gösteren koltuklar.
  final List<int> indicatorSeats;

  @override
  GameTemplate get template => GameTemplate.okey;

  @override
  String get type => 'okey';

  @override
  Map<String, Object?> toJson() => {
    'v': RuleSet.jsonVersion,
    'type': type,
    'finisherSeat': finisherSeat,
    'finish': finish.name,
    'indicatorSeats': indicatorSeats,
  };
}

class OkeyGameRules extends GameRules {
  const OkeyGameRules();

  @override
  GameTemplate get template => GameTemplate.okey;

  @override
  bool supports(GameConfig config) => config.isValid && config.seatCount == 4;

  @override
  OkeyRuleSet defaultRules(GameConfig config) => const OkeyRuleSet();

  @override
  OkeyRuleSet ruleSetFromJson(Map<String, Object?> json) =>
      OkeyRuleSet.fromJson(json);

  @override
  OkeyRoundInput roundInputFromJson(Map<String, Object?> json) =>
      OkeyRoundInput.fromJson(json);

  /// Eşli oyunda takım başına tek puan tutulur.
  @override
  List<ScoringUnit> units(GameConfig config) =>
      config.isPairs ? config.teamUnits() : config.seatUnits();

  @override
  List<RoundError> validate(
    RoundInput input,
    RuleSet rules,
    GameConfig config,
  ) {
    final okey = expectType<OkeyRoundInput>(input);
    bool outside(int seat) => seat < 0 || seat >= config.seatCount;
    final finisher = okey.finisherSeat;
    return [
      if (finisher != null && outside(finisher))
        RoundError(RoundErrorCode.seatOutOfRange, seat: finisher),
      if (finisher == null && okey.finish != OkeyFinish.normal)
        const RoundError(RoundErrorCode.finishWithoutFinisher),
      for (final seat in okey.indicatorSeats)
        if (outside(seat))
          RoundError(RoundErrorCode.seatOutOfRange, seat: seat),
    ];
  }

  @override
  RoundResult scoreValidRound(
    RoundInput input,
    RuleSet rules,
    GameConfig config,
  ) {
    final okey = expectType<OkeyRoundInput>(input);
    final values = expectType<OkeyRuleSet>(rules);
    final units = this.units(config);
    final points = List<int>.filled(units.length, 0);

    // [seat] hariç (eşlide [seat]'in takımı hariç) herkesten [loss] düşer.
    void othersLose(int seat, int loss) {
      for (var u = 0; u < units.length; u++) {
        if (!units[u].contains(seat)) points[u] -= loss;
      }
    }

    final finisher = okey.finisherSeat;
    if (finisher != null) othersLose(finisher, values.lossFor(okey.finish));
    for (final seat in okey.indicatorSeats) {
      othersLose(seat, values.indicator);
    }
    return RoundResult(List.unmodifiable(points));
  }

  @override
  GameStatus evaluate(Game game) {
    final rules = expectType<OkeyRuleSet>(game.rules);
    final units = this.units(game.config);
    final totals = unitTotals(game, units.length, start: rules.startingPoints);
    return GameStatus(
      isFinished: totals.any((total) => total <= 0),
      standings: rankStandings(
        contenders: contenders(game.config),
        unitTotals: totals,
        higherIsBetter: true,
      ),
    );
  }
}
