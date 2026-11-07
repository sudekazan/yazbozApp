import '../models/game.dart';
import '../models/game_config.dart';
import '../models/game_status.dart';
import '../models/json_read.dart';
import '../models/round.dart';
import '../models/rule_set.dart';
import 'game_rules.dart';

/// Serbest: en yüksek mi en düşük toplam mı kazanır.
///
/// Hedef verilirse biri hedefe ulaşınca oyun biter; "ulaşan kazanır"
/// en yüksek kazanır, "ulaşan kaybeder" en düşük kazanır demektir.
enum WinDirection { highest, lowest }

class FreeRuleSet extends RuleSet {
  const FreeRuleSet({this.winDirection = WinDirection.highest, this.target});

  factory FreeRuleSet.fromJson(Map<String, Object?> json) {
    const defaults = FreeRuleSet();
    return FreeRuleSet(
      winDirection: readEnum(
        json,
        'winDirection',
        WinDirection.values,
        defaults.winDirection,
      ),
      target: readIntOrNull(json, 'target', defaults.target),
    );
  }

  final WinDirection winDirection;

  /// Hedef puan; `null` ise oyun "Oyunu Bitir" ile biter.
  final int? target;

  @override
  GameTemplate get template => GameTemplate.free;

  @override
  Map<String, Object?> toJson() => {
    'v': RuleSet.jsonVersion,
    'template': template.name,
    'winDirection': winDirection.name,
    'target': target,
  };

  @override
  List<RuleError> validate() => [
    if (target != null && target! <= 0) const RuleError('target'),
  ];
}

class FreeRoundInput extends RoundInput {
  const FreeRoundInput(this.points);

  factory FreeRoundInput.fromJson(Map<String, Object?> json) {
    requireType(json, 'free');
    return FreeRoundInput(requireIntList(json, 'points'));
  }

  /// Her oyuncunun bu eldeki puanı (negatif olabilir).
  final List<int> points;

  @override
  GameTemplate get template => GameTemplate.free;

  @override
  String get type => 'free';

  @override
  Map<String, Object?> toJson() => {
    'v': RuleSet.jsonVersion,
    'type': type,
    'points': points,
  };
}

class FreeGameRules extends GameRules {
  const FreeGameRules();

  @override
  GameTemplate get template => GameTemplate.free;

  @override
  bool supports(GameConfig config) =>
      config.isValid && config.playMode == PlayMode.individual;

  @override
  FreeRuleSet defaultRules(GameConfig config) => const FreeRuleSet();

  @override
  FreeRuleSet ruleSetFromJson(Map<String, Object?> json) =>
      FreeRuleSet.fromJson(json);

  @override
  FreeRoundInput roundInputFromJson(Map<String, Object?> json) =>
      FreeRoundInput.fromJson(json);

  @override
  List<ScoringUnit> units(GameConfig config) => config.seatUnits();

  @override
  List<RoundError> validate(
    RoundInput input,
    RuleSet rules,
    GameConfig config,
  ) => validatePointList(
    expectType<FreeRoundInput>(input).points,
    config.seatCount,
  );

  @override
  RoundResult scoreValidRound(
    RoundInput input,
    RuleSet rules,
    GameConfig config,
  ) => RoundResult(List.unmodifiable(expectType<FreeRoundInput>(input).points));

  @override
  GameStatus evaluate(Game game) {
    final rules = expectType<FreeRuleSet>(game.rules);
    final highestWins = rules.winDirection == WinDirection.highest;
    final totals = unitTotals(game, game.config.seatCount);
    final standings = rankStandings(
      contenders: contenders(game.config),
      unitTotals: totals,
      higherIsBetter: highestWins,
    );

    final target = rules.target;
    var finished = false;
    if (target != null && totals.any((total) => total >= target)) {
      // En yüksek kazanırda birinciler eşitse oyun sürer; en düşük
      // kazanırda hedefe ulaşan oyunu bitirir, eşit en düşükler birlikte
      // kazanır.
      finished = !highestWins || hasSingleLeader(standings);
    }
    return GameStatus(
      isFinished: finished,
      standings: standings,
      target: target,
    );
  }
}
