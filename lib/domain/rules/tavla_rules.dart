import '../models/game.dart';
import '../models/game_config.dart';
import '../models/game_status.dart';
import '../models/json_read.dart';
import '../models/round.dart';
import '../models/rule_set.dart';
import 'game_rules.dart';

enum TavlaWin { normal, mars }

/// Tavla: her oyunun kazananı sayı alır, hedefe ilk ulaşan kazanır.
class TavlaRuleSet extends RuleSet {
  const TavlaRuleSet({
    this.target = 5,
    this.normalPoints = 1,
    this.marsPoints = 2,
    this.doublingCube = false,
  });

  factory TavlaRuleSet.fromJson(Map<String, Object?> json) {
    const d = TavlaRuleSet();
    return TavlaRuleSet(
      target: readInt(json, 'target', d.target),
      normalPoints: readInt(json, 'normalPoints', d.normalPoints),
      marsPoints: readInt(json, 'marsPoints', d.marsPoints),
      doublingCube: readBool(json, 'doublingCube', d.doublingCube),
    );
  }

  /// Katlama küpünün alabileceği değerler (küp kapalıyken sadece 1).
  static const List<int> cubeValues = [1, 2, 4, 8, 16, 32, 64];

  final int target;
  final int normalPoints;
  final int marsPoints;
  final bool doublingCube;

  @override
  GameTemplate get template => GameTemplate.tavla;

  @override
  Map<String, Object?> toJson() => {
    'v': RuleSet.jsonVersion,
    'template': template.name,
    'target': target,
    'normalPoints': normalPoints,
    'marsPoints': marsPoints,
    'doublingCube': doublingCube,
  };

  @override
  List<RuleError> validate() => [
    if (target <= 0) const RuleError('target'),
    if (normalPoints <= 0) const RuleError('normalPoints'),
    if (marsPoints <= 0) const RuleError('marsPoints'),
  ];
}

class TavlaRoundInput extends RoundInput {
  const TavlaRoundInput({
    required this.winnerSeat,
    this.win = TavlaWin.normal,
    this.cube = 1,
  });

  factory TavlaRoundInput.fromJson(Map<String, Object?> json) {
    requireType(json, 'tavla');
    return TavlaRoundInput(
      winnerSeat: requireInt(json, 'winnerSeat'),
      win: requireEnum(json, 'win', TavlaWin.values),
      cube: requireInt(json, 'cube'),
    );
  }

  final int winnerSeat;
  final TavlaWin win;

  /// Katlama küpü değeri; küp kullanılmıyorsa 1.
  final int cube;

  @override
  GameTemplate get template => GameTemplate.tavla;

  @override
  String get type => 'tavla';

  @override
  Map<String, Object?> toJson() => {
    'v': RuleSet.jsonVersion,
    'type': type,
    'winnerSeat': winnerSeat,
    'win': win.name,
    'cube': cube,
  };
}

class TavlaGameRules extends GameRules {
  const TavlaGameRules();

  @override
  GameTemplate get template => GameTemplate.tavla;

  @override
  bool supports(GameConfig config) =>
      config.isValid && config.seatCount == 2 && !config.isPairs;

  @override
  TavlaRuleSet defaultRules(GameConfig config) => const TavlaRuleSet();

  @override
  TavlaRuleSet ruleSetFromJson(Map<String, Object?> json) =>
      TavlaRuleSet.fromJson(json);

  @override
  TavlaRoundInput roundInputFromJson(Map<String, Object?> json) =>
      TavlaRoundInput.fromJson(json);

  @override
  List<ScoringUnit> units(GameConfig config) => config.seatUnits();

  @override
  List<RoundError> validate(
    RoundInput input,
    RuleSet rules,
    GameConfig config,
  ) {
    final round = expectType<TavlaRoundInput>(input);
    final values = expectType<TavlaRuleSet>(rules);
    final cubeOk = values.doublingCube
        ? TavlaRuleSet.cubeValues.contains(round.cube)
        : round.cube == 1;
    return [
      if (round.winnerSeat < 0 || round.winnerSeat >= config.seatCount)
        RoundError(RoundErrorCode.seatOutOfRange, seat: round.winnerSeat),
      if (!cubeOk) RoundError(RoundErrorCode.cubeInvalid, actual: round.cube),
    ];
  }

  @override
  RoundResult scoreValidRound(
    RoundInput input,
    RuleSet rules,
    GameConfig config,
  ) {
    final round = expectType<TavlaRoundInput>(input);
    final values = expectType<TavlaRuleSet>(rules);
    final base = switch (round.win) {
      TavlaWin.normal => values.normalPoints,
      TavlaWin.mars => values.marsPoints,
    };
    return RoundResult(
      List.unmodifiable([
        for (var seat = 0; seat < config.seatCount; seat++)
          seat == round.winnerSeat ? base * round.cube : 0,
      ]),
      multiplier: round.cube,
    );
  }

  @override
  GameStatus evaluate(Game game) {
    final rules = expectType<TavlaRuleSet>(game.rules);
    final totals = unitTotals(game, game.config.seatCount);
    return GameStatus(
      // Her elde sadece kazanan sayı aldığı için hedefte eşitlik olmaz.
      isFinished: totals.any((total) => total >= rules.target),
      standings: rankStandings(
        contenders: contenders(game.config),
        unitTotals: totals,
        higherIsBetter: true,
      ),
      target: rules.target,
    );
  }
}
