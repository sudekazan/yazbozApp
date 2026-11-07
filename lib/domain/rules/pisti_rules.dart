import '../models/game.dart';
import '../models/game_config.dart';
import '../models/game_status.dart';
import '../models/json_read.dart';
import '../models/round.dart';
import '../models/rule_set.dart';
import 'game_rules.dart';

/// Pişti: el sonunda sayaçlardan puan hesaplanır, hedefe ulaşan kazanır.
class PistiRuleSet extends RuleSet {
  const PistiRuleSet({
    this.target = 151,
    this.pisti = 10,
    this.jackPisti = 20,
    this.majority = 3,
    this.clubTwo = 2,
    this.diamondTen = 3,
    this.ace = 1,
    this.jack = 1,
  });

  factory PistiRuleSet.fromJson(Map<String, Object?> json) {
    const d = PistiRuleSet();
    int read(String key, int fallback) => readInt(json, key, fallback);
    return PistiRuleSet(
      target: read('target', d.target),
      pisti: read('pisti', d.pisti),
      jackPisti: read('jackPisti', d.jackPisti),
      majority: read('majority', d.majority),
      clubTwo: read('clubTwo', d.clubTwo),
      diamondTen: read('diamondTen', d.diamondTen),
      ace: read('ace', d.ace),
      jack: read('jack', d.jack),
    );
  }

  final int target;

  /// Her pişti.
  final int pisti;

  /// Vale (joker) ile pişti.
  final int jackPisti;

  /// En çok kart alan.
  final int majority;
  final int clubTwo;
  final int diamondTen;

  /// Her as.
  final int ace;

  /// Her vale.
  final int jack;

  @override
  GameTemplate get template => GameTemplate.pisti;

  @override
  Map<String, Object?> toJson() => {
    'v': RuleSet.jsonVersion,
    'template': template.name,
    'target': target,
    'pisti': pisti,
    'jackPisti': jackPisti,
    'majority': majority,
    'clubTwo': clubTwo,
    'diamondTen': diamondTen,
    'ace': ace,
    'jack': jack,
  };

  @override
  List<RuleError> validate() => [
    if (target <= 0) const RuleError('target'),
    for (final (field, value) in [
      ('pisti', pisti),
      ('jackPisti', jackPisti),
      ('majority', majority),
      ('clubTwo', clubTwo),
      ('diamondTen', diamondTen),
      ('ace', ace),
      ('jack', jack),
    ])
      if (value < 0) RuleError(field),
  ];
}

/// Bir oyuncunun (ya da takımın) bir eldeki sayaçları.
class PistiCounts {
  const PistiCounts({
    this.pisti = 0,
    this.jackPisti = 0,
    this.aces = 0,
    this.jacks = 0,
  });

  factory PistiCounts.fromJson(Map<String, Object?> json) => PistiCounts(
    pisti: requireInt(json, 'pisti'),
    jackPisti: requireInt(json, 'jackPisti'),
    aces: requireInt(json, 'aces'),
    jacks: requireInt(json, 'jacks'),
  );

  /// Destede 4 as ve 4 vale var.
  static const int cardsPerRank = 4;

  /// Bir elde en fazla pişti sayısı (52 kartlık deste için cömert sınır).
  static const int maxPisti = 52;

  final int pisti;
  final int jackPisti;
  final int aces;
  final int jacks;

  Map<String, Object?> toJson() => {
    'pisti': pisti,
    'jackPisti': jackPisti,
    'aces': aces,
    'jacks': jacks,
  };

  bool get isInRange =>
      pisti >= 0 &&
      pisti <= maxPisti &&
      jackPisti >= 0 &&
      jackPisti <= maxPisti &&
      aces >= 0 &&
      aces <= cardsPerRank &&
      jacks >= 0 &&
      jacks <= cardsPerRank;
}

/// Sayaçla giriş: her sütunun sayaçları ve tek sahipli kartlar.
class PistiCountInput extends RoundInput {
  const PistiCountInput({
    required this.counts,
    this.majorityUnit,
    this.clubTwoUnit,
    this.diamondTenUnit,
  });

  factory PistiCountInput.fromJson(Map<String, Object?> json) {
    requireType(json, 'pisti.counts');
    return PistiCountInput(
      counts: List.unmodifiable(
        requireObjectList(json, 'counts').map(PistiCounts.fromJson),
      ),
      majorityUnit: requireIntOrNull(json, 'majorityUnit'),
      clubTwoUnit: requireIntOrNull(json, 'clubTwoUnit'),
      diamondTenUnit: requireIntOrNull(json, 'diamondTenUnit'),
    );
  }

  final List<PistiCounts> counts;

  /// En çok kartı alan sütun; `null` ise kartlar eşit, kimse almaz.
  final int? majorityUnit;
  final int? clubTwoUnit;
  final int? diamondTenUnit;

  @override
  GameTemplate get template => GameTemplate.pisti;

  @override
  String get type => 'pisti.counts';

  @override
  Map<String, Object?> toJson() => {
    'v': RuleSet.jsonVersion,
    'type': type,
    'counts': [for (final c in counts) c.toJson()],
    'majorityUnit': majorityUnit,
    'clubTwoUnit': clubTwoUnit,
    'diamondTenUnit': diamondTenUnit,
  };
}

/// Doğrudan puan girişi (sayaçla uğraşmak istemeyenler için).
class PistiDirectInput extends RoundInput {
  const PistiDirectInput(this.points);

  factory PistiDirectInput.fromJson(Map<String, Object?> json) {
    requireType(json, 'pisti.direct');
    return PistiDirectInput(requireIntList(json, 'points'));
  }

  final List<int> points;

  @override
  GameTemplate get template => GameTemplate.pisti;

  @override
  String get type => 'pisti.direct';

  @override
  Map<String, Object?> toJson() => {
    'v': RuleSet.jsonVersion,
    'type': type,
    'points': points,
  };
}

class PistiGameRules extends GameRules {
  const PistiGameRules();

  @override
  GameTemplate get template => GameTemplate.pisti;

  @override
  bool supports(GameConfig config) =>
      config.isValid &&
      ((config.seatCount == 2 && !config.isPairs) ||
          (config.seatCount == 4 && config.isPairs));

  @override
  PistiRuleSet defaultRules(GameConfig config) => const PistiRuleSet();

  @override
  PistiRuleSet ruleSetFromJson(Map<String, Object?> json) =>
      PistiRuleSet.fromJson(json);

  @override
  RoundInput roundInputFromJson(Map<String, Object?> json) =>
      switch (json['type']) {
        'pisti.counts' => PistiCountInput.fromJson(json),
        'pisti.direct' => PistiDirectInput.fromJson(json),
        final other => throw FormatException('Bilinmeyen Pişti girdisi', other),
      };

  @override
  List<ScoringUnit> units(GameConfig config) =>
      config.isPairs ? config.teamUnits() : config.seatUnits();

  @override
  List<RoundError> validate(
    RoundInput input,
    RuleSet rules,
    GameConfig config,
  ) {
    final unitCount = units(config).length;
    return switch (input) {
      PistiDirectInput(:final points) => validatePointList(points, unitCount),
      PistiCountInput() => _validateCounts(input, unitCount),
      _ => throw ArgumentError.value(input, 'input', 'Pişti girdisi değil'),
    };
  }

  List<RoundError> _validateCounts(PistiCountInput input, int unitCount) {
    if (input.counts.length != unitCount) {
      return [
        RoundError(
          RoundErrorCode.wrongUnitCount,
          expected: unitCount,
          actual: input.counts.length,
        ),
      ];
    }
    bool outside(int? unit) => unit != null && (unit < 0 || unit >= unitCount);
    final aces = input.counts.fold(0, (sum, c) => sum + c.aces);
    final jacks = input.counts.fold(0, (sum, c) => sum + c.jacks);
    return [
      for (var unit = 0; unit < unitCount; unit++)
        if (!input.counts[unit].isInRange)
          RoundError(RoundErrorCode.countOutOfRange, unit: unit),
      if (aces > PistiCounts.cardsPerRank)
        RoundError(
          RoundErrorCode.acesOverLimit,
          expected: PistiCounts.cardsPerRank,
          actual: aces,
        ),
      if (jacks > PistiCounts.cardsPerRank)
        RoundError(
          RoundErrorCode.jacksOverLimit,
          expected: PistiCounts.cardsPerRank,
          actual: jacks,
        ),
      for (final unit in [
        input.majorityUnit,
        input.clubTwoUnit,
        input.diamondTenUnit,
      ])
        if (outside(unit))
          RoundError(RoundErrorCode.unitOutOfRange, unit: unit),
      if (input.clubTwoUnit == null)
        const RoundError(RoundErrorCode.clubTwoOwnerRequired),
      if (input.diamondTenUnit == null)
        const RoundError(RoundErrorCode.diamondTenOwnerRequired),
    ];
  }

  @override
  RoundResult scoreValidRound(
    RoundInput input,
    RuleSet rules,
    GameConfig config,
  ) {
    final values = expectType<PistiRuleSet>(rules);
    return switch (input) {
      PistiDirectInput(:final points) => RoundResult(List.unmodifiable(points)),
      PistiCountInput() => RoundResult(
        List.unmodifiable([
          for (var unit = 0; unit < input.counts.length; unit++)
            _unitPoints(input, unit, values),
        ]),
      ),
      _ => throw ArgumentError.value(input, 'input', 'Pişti girdisi değil'),
    };
  }

  int _unitPoints(PistiCountInput input, int unit, PistiRuleSet rules) {
    final c = input.counts[unit];
    return c.pisti * rules.pisti +
        c.jackPisti * rules.jackPisti +
        c.aces * rules.ace +
        c.jacks * rules.jack +
        (input.majorityUnit == unit ? rules.majority : 0) +
        (input.clubTwoUnit == unit ? rules.clubTwo : 0) +
        (input.diamondTenUnit == unit ? rules.diamondTen : 0);
  }

  @override
  GameStatus evaluate(Game game) {
    final rules = expectType<PistiRuleSet>(game.rules);
    final totals = unitTotals(game, units(game.config).length);
    final standings = rankStandings(
      contenders: contenders(game.config),
      unitTotals: totals,
      higherIsBetter: true,
    );
    return GameStatus(
      // Hedefi geçen birinciler eşitse oyun sürer.
      isFinished:
          totals.any((total) => total >= rules.target) &&
          hasSingleLeader(standings),
      standings: standings,
      target: rules.target,
    );
  }
}
