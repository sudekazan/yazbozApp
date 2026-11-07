import 'dart:math' as math;

import '../models/game.dart';
import '../models/game_config.dart';
import '../models/game_status.dart';
import '../models/json_read.dart';
import '../models/round.dart';
import '../models/rule_set.dart';
import '../validation.dart';
import 'game_rules.dart';

/// 101'de bitirmeyen bir oyuncunun el sonundaki durumu.
enum Okey101PlayerState {
  /// Açtı ama bitiremedi: kalan taş toplamını yazar.
  opened,

  /// Çiftten açtı ama bitiremedi: kalanı ayrıca katlanır.
  openedPairs,

  /// Hiç açamadı.
  notOpened,
}

enum Okey101PenaltyKind {
  /// İşler taş atma.
  tileToMeld,

  /// Okey atma (açılmış perde varken).
  discardOkey,

  /// Yanlış açma.
  wrongOpen,

  /// Tutarı elle girilen ceza.
  custom,
}

class Okey101Player {
  const Okey101Player({required this.state, this.remaining = 0});

  factory Okey101Player.fromJson(Map<String, Object?> json) => Okey101Player(
    state: requireEnum(json, 'state', Okey101PlayerState.values),
    remaining: requireInt(json, 'remaining'),
  );

  final Okey101PlayerState state;

  /// Elinde kalan taşların toplamı (kullanıcı girer).
  final int remaining;

  Map<String, Object?> toJson() => {
    'state': state.name,
    'remaining': remaining,
  };
}

class Okey101Penalty {
  const Okey101Penalty({required this.seat, required this.kind, this.amount});

  factory Okey101Penalty.fromJson(Map<String, Object?> json) => Okey101Penalty(
    seat: requireInt(json, 'seat'),
    kind: requireEnum(json, 'kind', Okey101PenaltyKind.values),
    amount: requireIntOrNull(json, 'amount'),
  );

  final int seat;
  final Okey101PenaltyKind kind;

  /// Sadece [Okey101PenaltyKind.custom] için; diğerleri kurallardan gelir.
  final int? amount;

  Map<String, Object?> toJson() => {
    'seat': seat,
    'kind': kind.name,
    'amount': amount,
  };
}

/// 101 Okey: düşük puan iyidir, belli sayıda el sonunda en düşük toplam
/// kazanır.
class Okey101RuleSet extends RuleSet {
  const Okey101RuleSet({
    this.rounds = 9,
    this.finishPoints = 101,
    this.notOpenedPoints = 202,
    this.okeyMultiplier = 2,
    this.handFinishMultiplier = 2,
    this.pairsFinishMultiplier = 2,
    this.pairsRemainingMultiplier = 2,
    this.penaltyTileToMeld = 101,
    this.penaltyDiscardOkey = 101,
    this.penaltyWrongOpen = 101,
  });

  factory Okey101RuleSet.fromJson(Map<String, Object?> json) {
    const d = Okey101RuleSet();
    int read(String key, int fallback) => readInt(json, key, fallback);
    return Okey101RuleSet(
      rounds: read('rounds', d.rounds),
      finishPoints: read('finishPoints', d.finishPoints),
      notOpenedPoints: read('notOpenedPoints', d.notOpenedPoints),
      okeyMultiplier: read('okeyMultiplier', d.okeyMultiplier),
      handFinishMultiplier: read(
        'handFinishMultiplier',
        d.handFinishMultiplier,
      ),
      pairsFinishMultiplier: read(
        'pairsFinishMultiplier',
        d.pairsFinishMultiplier,
      ),
      pairsRemainingMultiplier: read(
        'pairsRemainingMultiplier',
        d.pairsRemainingMultiplier,
      ),
      penaltyTileToMeld: read('penaltyTileToMeld', d.penaltyTileToMeld),
      penaltyDiscardOkey: read('penaltyDiscardOkey', d.penaltyDiscardOkey),
      penaltyWrongOpen: read('penaltyWrongOpen', d.penaltyWrongOpen),
    );
  }

  /// Oyun süresi (el).
  final int rounds;

  /// Eli bitirenin düştüğü puan (−101).
  final int finishPoints;

  /// Hiç açamayanın yazdığı puan (+202).
  final int notOpenedPoints;

  /// Okeyle bitiş çarpanı.
  final int okeyMultiplier;

  /// Elden (hiç açmadan tek seferde) bitiş çarpanı.
  final int handFinishMultiplier;

  /// Çiftten açıp bitiş çarpanı.
  final int pairsFinishMultiplier;

  /// Çiftten açıp bitiremeyenin kalanına uygulanan çarpan; 1 ise kapalı.
  final int pairsRemainingMultiplier;

  final int penaltyTileToMeld;
  final int penaltyDiscardOkey;
  final int penaltyWrongOpen;

  @override
  GameTemplate get template => GameTemplate.okey101;

  @override
  Map<String, Object?> toJson() => {
    'v': RuleSet.jsonVersion,
    'template': template.name,
    'rounds': rounds,
    'finishPoints': finishPoints,
    'notOpenedPoints': notOpenedPoints,
    'okeyMultiplier': okeyMultiplier,
    'handFinishMultiplier': handFinishMultiplier,
    'pairsFinishMultiplier': pairsFinishMultiplier,
    'pairsRemainingMultiplier': pairsRemainingMultiplier,
    'penaltyTileToMeld': penaltyTileToMeld,
    'penaltyDiscardOkey': penaltyDiscardOkey,
    'penaltyWrongOpen': penaltyWrongOpen,
  };

  @override
  List<RuleError> validate() => [
    if (rounds < 1) const RuleError('rounds'),
    if (finishPoints < 0) const RuleError('finishPoints'),
    if (notOpenedPoints < 0) const RuleError('notOpenedPoints'),
    if (okeyMultiplier < 1) const RuleError('okeyMultiplier'),
    if (handFinishMultiplier < 1) const RuleError('handFinishMultiplier'),
    if (pairsFinishMultiplier < 1) const RuleError('pairsFinishMultiplier'),
    if (pairsRemainingMultiplier < 1)
      const RuleError('pairsRemainingMultiplier'),
    if (penaltyTileToMeld < 0) const RuleError('penaltyTileToMeld'),
    if (penaltyDiscardOkey < 0) const RuleError('penaltyDiscardOkey'),
    if (penaltyWrongOpen < 0) const RuleError('penaltyWrongOpen'),
  ];
}

class Okey101RoundInput extends RoundInput {
  const Okey101RoundInput({
    this.finisherSeat,
    this.withOkey = false,
    this.fromHand = false,
    this.fromPairs = false,
    required this.players,
    this.penalties = const [],
  });

  factory Okey101RoundInput.fromJson(Map<String, Object?> json) {
    requireType(json, 'okey101');
    return Okey101RoundInput(
      finisherSeat: requireIntOrNull(json, 'finisherSeat'),
      withOkey: requireBool(json, 'withOkey'),
      fromHand: requireBool(json, 'fromHand'),
      fromPairs: requireBool(json, 'fromPairs'),
      players: List.unmodifiable(
        requireObjectList(json, 'players').map(Okey101Player.fromJson),
      ),
      penalties: List.unmodifiable(
        requireObjectList(json, 'penalties').map(Okey101Penalty.fromJson),
      ),
    );
  }

  /// Eli bitiren koltuk; `null` ise kimse bitiremedi.
  final int? finisherSeat;
  final bool withOkey;
  final bool fromHand;
  final bool fromPairs;

  /// Koltuk sırasıyla her oyuncunun durumu. Bitirenin (ve eşlide eşinin)
  /// satırı hesaba katılmaz.
  final List<Okey101Player> players;
  final List<Okey101Penalty> penalties;

  @override
  GameTemplate get template => GameTemplate.okey101;

  @override
  String get type => 'okey101';

  @override
  Map<String, Object?> toJson() => {
    'v': RuleSet.jsonVersion,
    'type': type,
    'finisherSeat': finisherSeat,
    'withOkey': withOkey,
    'fromHand': fromHand,
    'fromPairs': fromPairs,
    'players': [for (final p in players) p.toJson()],
    'penalties': [for (final p in penalties) p.toJson()],
  };
}

class Okey101GameRules extends GameRules {
  const Okey101GameRules();

  @override
  GameTemplate get template => GameTemplate.okey101;

  @override
  bool supports(GameConfig config) => config.isValid && config.seatCount == 4;

  @override
  Okey101RuleSet defaultRules(GameConfig config) => const Okey101RuleSet();

  @override
  Okey101RuleSet ruleSetFromJson(Map<String, Object?> json) =>
      Okey101RuleSet.fromJson(json);

  @override
  Okey101RoundInput roundInputFromJson(Map<String, Object?> json) =>
      Okey101RoundInput.fromJson(json);

  /// Eşli oyunda da her oyuncu kendi sütununda; takım toplamı ayrıca
  /// gösterilir.
  @override
  List<ScoringUnit> units(GameConfig config) => config.seatUnits();

  @override
  List<List<int>> contenders(GameConfig config) => config.isPairs
      ? [for (final team in config.teamUnits()) team.seats]
      : super.contenders(config);

  @override
  List<RoundError> validate(
    RoundInput input,
    RuleSet rules,
    GameConfig config,
  ) {
    final round = expectType<Okey101RoundInput>(input);
    final values = expectType<Okey101RuleSet>(rules);
    if (round.players.length != config.seatCount) {
      return [
        RoundError(
          RoundErrorCode.wrongUnitCount,
          expected: config.seatCount,
          actual: round.players.length,
        ),
      ];
    }
    bool outside(int seat) => seat < 0 || seat >= config.seatCount;
    final finisher = round.finisherSeat;
    final hasFlags = round.withOkey || round.fromHand || round.fromPairs;

    final errors = <RoundError>[
      if (finisher != null && outside(finisher))
        RoundError(RoundErrorCode.seatOutOfRange, seat: finisher),
      if (finisher == null && hasFlags)
        const RoundError(RoundErrorCode.finishWithoutFinisher),
      for (var seat = 0; seat < config.seatCount; seat++)
        if (_writesRemaining(round, config, seat) &&
            (round.players[seat].remaining < 0 ||
                round.players[seat].remaining > Limits.maxAbsPoints))
          RoundError(RoundErrorCode.remainingOutOfRange, seat: seat),
      for (final penalty in round.penalties) ...[
        if (outside(penalty.seat))
          RoundError(RoundErrorCode.seatOutOfRange, seat: penalty.seat),
        if (penalty.kind == Okey101PenaltyKind.custom &&
            !_isValidPenaltyAmount(penalty.amount))
          RoundError(
            RoundErrorCode.penaltyAmountOutOfRange,
            seat: penalty.seat,
          ),
      ],
    ];
    if (errors.isNotEmpty) return errors;

    final points = _score(round, values, config).points;
    return [
      for (var unit = 0; unit < points.length; unit++)
        if (!isPointsInRange(points[unit]))
          RoundError(RoundErrorCode.pointsOutOfRange, unit: unit),
    ];
  }

  @override
  RoundResult scoreValidRound(
    RoundInput input,
    RuleSet rules,
    GameConfig config,
  ) => _score(
    expectType<Okey101RoundInput>(input),
    expectType<Okey101RuleSet>(rules),
    config,
  );

  RoundResult _score(
    Okey101RoundInput round,
    Okey101RuleSet rules,
    GameConfig config,
  ) {
    final finisher = round.finisherSeat;
    var multiplier = 1;
    if (finisher != null) {
      if (round.withOkey) multiplier *= rules.okeyMultiplier;
      if (round.fromHand) multiplier *= rules.handFinishMultiplier;
      if (round.fromPairs) multiplier *= rules.pairsFinishMultiplier;
    }

    final points = List<int>.generate(config.seatCount, (seat) {
      if (seat == finisher) return -rules.finishPoints * multiplier;
      if (!_writesRemaining(round, config, seat)) {
        // Eşli oyunda bitirenin eşi 0 yazar.
        return 0;
      }
      final player = round.players[seat];
      return switch (player.state) {
        Okey101PlayerState.notOpened => rules.notOpenedPoints * multiplier,
        Okey101PlayerState.opened => player.remaining * multiplier,
        Okey101PlayerState.openedPairs =>
          player.remaining * multiplier * rules.pairsRemainingMultiplier,
      };
    });

    // Cezalar çarpandan etkilenmez.
    for (final penalty in round.penalties) {
      points[penalty.seat] += switch (penalty.kind) {
        Okey101PenaltyKind.tileToMeld => rules.penaltyTileToMeld,
        Okey101PenaltyKind.discardOkey => rules.penaltyDiscardOkey,
        Okey101PenaltyKind.wrongOpen => rules.penaltyWrongOpen,
        Okey101PenaltyKind.custom => penalty.amount ?? 0,
      };
    }
    return RoundResult(List.unmodifiable(points), multiplier: multiplier);
  }

  /// Bu koltuk kalan taşını ya da açamama puanını yazar mı? Bitiren ve
  /// eşlide bitirenin eşi yazmaz.
  bool _writesRemaining(Okey101RoundInput round, GameConfig config, int seat) {
    final finisher = round.finisherSeat;
    if (seat == finisher) return false;
    if (finisher != null && config.partnerOf(finisher) == seat) return false;
    return true;
  }

  bool _isValidPenaltyAmount(int? amount) =>
      amount != null && amount > 0 && amount <= Limits.maxAbsPoints;

  @override
  GameStatus evaluate(Game game) {
    final rules = expectType<Okey101RuleSet>(game.rules);
    final totals = unitTotals(game, game.config.seatCount);
    final played = game.rounds.length;
    return GameStatus(
      isFinished: played >= rules.rounds,
      standings: rankStandings(
        contenders: contenders(game.config),
        unitTotals: totals,
        higherIsBetter: false,
      ),
      roundsLeft: math.max(0, rules.rounds - played),
    );
  }
}
