import 'dart:math' as math;

import '../models/game.dart';
import '../models/game_config.dart';
import '../models/game_status.dart';
import '../models/json_read.dart';
import '../models/round.dart';
import '../models/rule_set.dart';
import 'game_rules.dart';

enum BatakMode {
  /// Düz Batak: herkes aldığı el kadar puan alır.
  plain,

  /// İhaleli Batak.
  bidding,
}

/// Oyun belli sayıda elle mi, hedef puanla mı biter.
enum BatakLength { rounds, target }

enum BatakSuit { clubs, diamonds, hearts, spades }

class BatakRuleSet extends RuleSet {
  const BatakRuleSet({
    this.mode = BatakMode.bidding,
    this.length = BatakLength.rounds,
    this.rounds = 11,
    this.target,
    this.minBid = 5,
    this.zeroTricksPoints = 0,
  });

  factory BatakRuleSet.fromJson(Map<String, Object?> json) {
    const d = BatakRuleSet();
    return BatakRuleSet(
      mode: readEnum(json, 'mode', BatakMode.values, d.mode),
      length: readEnum(json, 'length', BatakLength.values, d.length),
      rounds: readInt(json, 'rounds', d.rounds),
      target: readIntOrNull(json, 'target', d.target),
      minBid: readInt(json, 'minBid', d.minBid),
      zeroTricksPoints: readInt(json, 'zeroTricksPoints', d.zeroTricksPoints),
    );
  }

  /// 3 kişilik dağıtımdaki el sayısı; ihale bundan büyük olamaz.
  static const int maxTricksPerDeal = 17;

  final BatakMode mode;
  final BatakLength length;

  /// [BatakLength.rounds] için oyun süresi.
  final int rounds;

  /// [BatakLength.target] için hedef puan; o modda zorunlu.
  final int? target;

  final int minBid;

  /// Hiç el alamayanın yazdığı puan ("batma" kuralı); ihaleyi alana
  /// uygulanmaz.
  final int zeroTricksPoints;

  @override
  GameTemplate get template => GameTemplate.batak;

  @override
  Map<String, Object?> toJson() => {
    'v': RuleSet.jsonVersion,
    'template': template.name,
    'mode': mode.name,
    'length': length.name,
    'rounds': rounds,
    'target': target,
    'minBid': minBid,
    'zeroTricksPoints': zeroTricksPoints,
  };

  @override
  List<RuleError> validate() => [
    if (rounds < 1) const RuleError('rounds'),
    if (length == BatakLength.target && (target == null || target! <= 0))
      const RuleError('target'),
    if (minBid < 1 || minBid > maxTricksPerDeal) const RuleError('minBid'),
  ];
}

class BatakRoundInput extends RoundInput {
  const BatakRoundInput({
    this.bidderSeat,
    this.bid,
    this.trump,
    required this.tricks,
  });

  factory BatakRoundInput.fromJson(Map<String, Object?> json) {
    requireType(json, 'batak');
    return BatakRoundInput(
      bidderSeat: requireIntOrNull(json, 'bidderSeat'),
      bid: requireIntOrNull(json, 'bid'),
      trump: requireEnumOrNull(json, 'trump', BatakSuit.values),
      tricks: requireIntList(json, 'tricks'),
    );
  }

  /// İhaleyi alan koltuk (sadece ihaleli oyunda).
  final int? bidderSeat;
  final int? bid;

  /// Koz; bilgi amaçlı, puanı etkilemez.
  final BatakSuit? trump;

  /// Her sütunun aldığı el sayısı (eşlide takım başına).
  final List<int> tricks;

  @override
  GameTemplate get template => GameTemplate.batak;

  @override
  String get type => 'batak';

  @override
  Map<String, Object?> toJson() => {
    'v': RuleSet.jsonVersion,
    'type': type,
    'bidderSeat': bidderSeat,
    'bid': bid,
    'trump': trump?.name,
    'tricks': tricks,
  };
}

class BatakGameRules extends GameRules {
  const BatakGameRules();

  @override
  GameTemplate get template => GameTemplate.batak;

  /// Bir dağıtımda çıkan el: 3 kişide 17 (bir kart çıkarılır), 4 kişide 13.
  static int tricksPerDeal(GameConfig config) =>
      config.seatCount == 3 ? 17 : 13;

  @override
  bool supports(GameConfig config) =>
      config.isValid &&
      ((config.seatCount == 3 && !config.isPairs) || config.seatCount == 4);

  @override
  BatakRuleSet defaultRules(GameConfig config) => const BatakRuleSet();

  @override
  BatakRuleSet ruleSetFromJson(Map<String, Object?> json) =>
      BatakRuleSet.fromJson(json);

  @override
  BatakRoundInput roundInputFromJson(Map<String, Object?> json) =>
      BatakRoundInput.fromJson(json);

  @override
  List<ScoringUnit> units(GameConfig config) =>
      config.isPairs ? config.teamUnits() : config.seatUnits();

  @override
  List<RoundError> validate(
    RoundInput input,
    RuleSet rules,
    GameConfig config,
  ) {
    final round = expectType<BatakRoundInput>(input);
    final values = expectType<BatakRuleSet>(rules);
    final unitCount = units(config).length;
    final perDeal = tricksPerDeal(config);
    if (round.tricks.length != unitCount) {
      return [
        RoundError(
          RoundErrorCode.wrongUnitCount,
          expected: unitCount,
          actual: round.tricks.length,
        ),
      ];
    }
    final total = round.tricks.fold(0, (sum, t) => sum + t);
    final bidder = round.bidderSeat;
    final bid = round.bid;
    return [
      for (var unit = 0; unit < unitCount; unit++)
        if (round.tricks[unit] < 0 || round.tricks[unit] > perDeal)
          RoundError(RoundErrorCode.tricksOutOfRange, unit: unit),
      if (total != perDeal)
        RoundError(
          RoundErrorCode.tricksTotalMismatch,
          expected: perDeal,
          actual: total,
        ),
      if (values.mode == BatakMode.bidding) ...[
        if (bidder == null)
          const RoundError(RoundErrorCode.bidderRequired)
        else if (bidder < 0 || bidder >= config.seatCount)
          RoundError(RoundErrorCode.seatOutOfRange, seat: bidder),
        if (bid == null || bid < values.minBid || bid > perDeal)
          RoundError(
            RoundErrorCode.bidOutOfRange,
            expected: values.minBid,
            actual: bid,
          ),
      ],
    ];
  }

  @override
  RoundResult scoreValidRound(
    RoundInput input,
    RuleSet rules,
    GameConfig config,
  ) {
    final round = expectType<BatakRoundInput>(input);
    final values = expectType<BatakRuleSet>(rules);
    final units = this.units(config);
    final bidding = values.mode == BatakMode.bidding;

    return RoundResult(
      List.unmodifiable([
        for (var unit = 0; unit < units.length; unit++)
          if (bidding && units[unit].contains(round.bidderSeat!))
            // İhaleyi alan: tutturursa aldığı el kadar +, batarsa ihale kadar −.
            round.tricks[unit] >= round.bid! ? round.tricks[unit] : -round.bid!
          else if (round.tricks[unit] == 0)
            values.zeroTricksPoints
          else
            round.tricks[unit],
      ]),
    );
  }

  @override
  GameStatus evaluate(Game game) {
    final rules = expectType<BatakRuleSet>(game.rules);
    final totals = unitTotals(game, units(game.config).length);
    final standings = rankStandings(
      contenders: contenders(game.config),
      unitTotals: totals,
      higherIsBetter: true,
    );
    final played = game.rounds.length;
    return switch (rules.length) {
      BatakLength.rounds => GameStatus(
        isFinished: played >= rules.rounds,
        standings: standings,
        roundsLeft: math.max(0, rules.rounds - played),
      ),
      BatakLength.target => GameStatus(
        // Hedefi geçen birinciler eşitse oyun sürer.
        isFinished:
            rules.target != null &&
            totals.any((total) => total >= rules.target!) &&
            hasSingleLeader(standings),
        standings: standings,
        target: rules.target,
      ),
    };
  }
}
