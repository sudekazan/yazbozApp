import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/domain/models/game.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/models/round.dart';
import 'package:yazboz/domain/rules/okey101_rules.dart';

const engine = Okey101GameRules();
const solo = GameConfig(template: GameTemplate.okey101, seatCount: 4);
const pairs = GameConfig(
  template: GameTemplate.okey101,
  seatCount: 4,
  playMode: PlayMode.pairs,
);
const rules = Okey101RuleSet();

const opened = Okey101PlayerState.opened;
const openedPairs = Okey101PlayerState.openedPairs;
const notOpened = Okey101PlayerState.notOpened;

Okey101Player p(Okey101PlayerState state, [int remaining = 0]) =>
    Okey101Player(state: state, remaining: remaining);

/// Ayşe 38 kalan, Mehmet bitirdi, Zeynep 24 kalan, Burak açamadı.
final table = [p(opened, 38), p(opened), p(opened, 24), p(notOpened)];

RoundResult calc(
  Okey101RoundInput input, {
  Okey101RuleSet ruleSet = rules,
  GameConfig config = solo,
}) => engine.calculateRound(input, ruleSet, config);

Okey101RoundInput finishedBy(
  int seat, {
  bool okey = false,
  bool hand = false,
  bool pairsFinish = false,
  List<Okey101Player>? players,
  List<Okey101Penalty> penalties = const [],
}) => Okey101RoundInput(
  finisherSeat: seat,
  withOkey: okey,
  fromHand: hand,
  fromPairs: pairsFinish,
  players: players ?? table,
  penalties: penalties,
);

Game gameOf(List<Okey101RoundInput> inputs, {GameConfig config = solo}) => Game(
  config: config,
  rules: rules,
  rounds: [
    for (final input in inputs)
      Round(
        input: input,
        result: calc(input, config: config),
      ),
  ],
);

void main() {
  group('101 el hesabı', () {
    test('bitiren -101, açan kalanını, açamayan +202 yazar', () {
      expect(calc(finishedBy(1)).points, [38, -101, 24, 202]);
    });

    test('okeyle bitişte tüm puanlar iki katı', () {
      final result = calc(finishedBy(1, okey: true));
      expect(result.points, [76, -202, 48, 404]);
      expect(result.multiplier, 2);
    });

    test('elden bitişte tüm puanlar iki katı', () {
      expect(calc(finishedBy(1, hand: true)).points, [76, -202, 48, 404]);
    });

    test('çiftten bitişte tüm puanlar iki katı', () {
      expect(calc(finishedBy(1, pairsFinish: true)).points, [
        76,
        -202,
        48,
        404,
      ]);
    });

    test('çiftten bitiş çarpanı kurallardan kapatılabilir', () {
      const custom = Okey101RuleSet(pairsFinishMultiplier: 1);
      expect(calc(finishedBy(1, pairsFinish: true), ruleSet: custom).points, [
        38,
        -101,
        24,
        202,
      ]);
    });

    test('çiftten açıp okeyle bitişte çarpanlar çarpılır (x4)', () {
      final result = calc(finishedBy(1, okey: true, pairsFinish: true));
      expect(result.points, [152, -404, 96, 808]);
      expect(result.multiplier, 4);
    });

    test('elden okeyle bitişte çarpanlar çarpılır (x4)', () {
      expect(calc(finishedBy(1, okey: true, hand: true)).points, [
        152,
        -404,
        96,
        808,
      ]);
    });

    test('çiftten açıp bitiremeyenin kalanı iki katı yazılır', () {
      final players = [
        p(openedPairs, 20),
        p(opened),
        p(opened, 24),
        p(notOpened),
      ];
      expect(calc(finishedBy(1, players: players)).points, [40, -101, 24, 202]);
    });

    test('çift açanın x2si el çarpanıyla da çarpılır', () {
      final players = [
        p(openedPairs, 20),
        p(opened),
        p(opened, 24),
        p(notOpened),
      ];
      expect(calc(finishedBy(1, okey: true, players: players)).points, [
        80,
        -202,
        48,
        404,
      ]);
    });

    test('çift açanın x2si kurallardan kapatılabilir', () {
      const custom = Okey101RuleSet(pairsRemainingMultiplier: 1);
      final players = [
        p(openedPairs, 20),
        p(opened),
        p(opened, 24),
        p(notOpened),
      ];
      expect(calc(finishedBy(1, players: players), ruleSet: custom).points, [
        20,
        -101,
        24,
        202,
      ]);
    });

    test('ceza +101 eklenir ve el çarpanından etkilenmez', () {
      final input = finishedBy(
        1,
        okey: true,
        penalties: const [
          Okey101Penalty(seat: 2, kind: Okey101PenaltyKind.tileToMeld),
        ],
      );
      expect(calc(input).points, [76, -202, 149, 404]);
    });

    test('okey atma ve yanlış açma cezaları kendi tutarlarıyla eklenir', () {
      const custom = Okey101RuleSet(
        penaltyDiscardOkey: 150,
        penaltyWrongOpen: 75,
      );
      final input = finishedBy(
        1,
        penalties: const [
          Okey101Penalty(seat: 0, kind: Okey101PenaltyKind.discardOkey),
          Okey101Penalty(seat: 0, kind: Okey101PenaltyKind.wrongOpen),
        ],
      );
      expect(calc(input, ruleSet: custom).points, [263, -101, 24, 202]);
    });

    test('serbest tutarlı ceza girilen tutarla eklenir', () {
      final input = finishedBy(
        1,
        penalties: const [
          Okey101Penalty(seat: 3, kind: Okey101PenaltyKind.custom, amount: 50),
        ],
      );
      expect(calc(input).points, [38, -101, 24, 252]);
    });

    test('kimse bitiremediyse çarpansız, herkes kalanını ya da +202 yazar', () {
      final players = [
        p(opened, 12),
        p(opened, 30),
        p(openedPairs, 5),
        p(notOpened),
      ];
      final result = calc(Okey101RoundInput(players: players));
      expect(result.points, [12, 30, 10, 202]);
      expect(result.multiplier, 1);
    });

    test('eşli oyunda bitirenin eşi 0 yazar', () {
      // Mehmet (1) bitirdi; eşi Burak (3) açamamış olsa da 0 yazar.
      expect(calc(finishedBy(1), config: pairs).points, [38, -101, 24, 0]);
    });

    test('eşli oyunda bitirenin eşinin cezası yine yazılır', () {
      final input = finishedBy(
        1,
        penalties: const [
          Okey101Penalty(seat: 3, kind: Okey101PenaltyKind.wrongOpen),
        ],
      );
      expect(calc(input, config: pairs).points, [38, -101, 24, 101]);
    });
  });

  group('101 doğrulama', () {
    List<RoundErrorCode> codes(Okey101RoundInput input) =>
        engine.validate(input, rules, solo).map((e) => e.code).toList();

    test('bitiren yokken bitiş biçimi seçilemez', () {
      expect(codes(Okey101RoundInput(withOkey: true, players: table)), [
        RoundErrorCode.finishWithoutFinisher,
      ]);
    });

    test('kalan taş negatif olamaz', () {
      final players = [p(opened, -1), p(opened), p(opened, 24), p(notOpened)];
      final errors = engine.validate(
        finishedBy(1, players: players),
        rules,
        solo,
      );
      expect(
        (errors.single.code, errors.single.seat),
        (RoundErrorCode.remainingOutOfRange, 0),
      );
    });

    test('serbest ceza tutarı pozitif olmalı', () {
      final input = finishedBy(
        1,
        penalties: const [
          Okey101Penalty(seat: 0, kind: Okey101PenaltyKind.custom, amount: 0),
        ],
      );
      expect(codes(input), [RoundErrorCode.penaltyAmountOutOfRange]);
    });

    test('oyuncu sayısı ve koltuklar denetlenir', () {
      expect(codes(Okey101RoundInput(players: table.take(3).toList())), [
        RoundErrorCode.wrongUnitCount,
      ]);
      expect(codes(finishedBy(7)), [RoundErrorCode.seatOutOfRange]);
    });

    test('çarpanla ±99.999 sınırını aşan puan reddedilir', () {
      final players = [p(opened, 30000), p(opened), p(opened), p(opened)];
      expect(codes(finishedBy(1, okey: true, hand: true, players: players)), [
        RoundErrorCode.pointsOutOfRange,
      ]);
    });
  });

  group('101 oyun durumu', () {
    test('9 el bitince oyun biter, en düşük toplam kazanır', () {
      final status = engine.evaluate(
        gameOf([for (var i = 0; i < 9; i++) finishedBy(i % 4)]),
      );
      expect(status.isFinished, isTrue);
      expect(status.roundsLeft, 0);
      expect(status.winners, hasLength(1));
      final winner = status.standings.first;
      expect(status.standings.every((s) => s.total >= winner.total), isTrue);
    });

    test('9 elden önce oyun sürer ve kalan el sayısı bilinir', () {
      final status = engine.evaluate(gameOf([finishedBy(1), finishedBy(2)]));
      expect(status.isFinished, isFalse);
      expect(status.roundsLeft, 7);
      expect(status.leaders, [1]);
    });

    test('el sayısı kurallardan değiştirilebilir', () {
      const custom = Okey101RuleSet(rounds: 2);
      final game = Game(
        config: solo,
        rules: custom,
        rounds: [
          for (final input in [finishedBy(1), finishedBy(2)])
            Round(
              input: input,
              result: calc(input, ruleSet: custom),
            ),
        ],
      );
      expect(engine.evaluate(game).isFinished, isTrue);
    });

    test('eşli oyunda eş puanları toplanır, düşük takım toplamı kazanır', () {
      final status = engine.evaluate(gameOf([finishedBy(1)], config: pairs));
      // Takım A: 38 + 24 = 62, Takım B: -101 + 0 = -101.
      expect(status.standings.map((s) => (s.contender, s.total)), [
        (1, -101),
        (0, 62),
      ]);
      expect(engine.units(pairs), hasLength(4));
    });

    test('sonunda en düşükler eşitse birlikte kazanır', () {
      const custom = Okey101RuleSet(rounds: 1);
      final players = [
        p(opened, 10),
        p(opened, 10),
        p(opened, 30),
        p(opened, 40),
      ];
      final input = Okey101RoundInput(players: players);
      final game = Game(
        config: solo,
        rules: custom,
        rounds: [
          Round(
            input: input,
            result: calc(input, ruleSet: custom),
          ),
        ],
      );
      expect(engine.evaluate(game).winners, [0, 1]);
    });
  });

  group('101 kurallar ve JSON', () {
    test('çarpan 1 altına, el sayısı 1 altına inemez', () {
      expect(const Okey101RuleSet(okeyMultiplier: 0).validate(), isNotEmpty);
      expect(const Okey101RuleSet(rounds: 0).validate(), isNotEmpty);
      expect(rules.validate(), isEmpty);
    });

    test('kurallar ve el girdisi JSON üzerinden aynen geri okunur', () {
      const custom = Okey101RuleSet(rounds: 11, penaltyTileToMeld: 120);
      expect(engine.ruleSetFromJson(custom.toJson()).toJson(), custom.toJson());
      final input = finishedBy(
        2,
        okey: true,
        pairsFinish: true,
        penalties: const [
          Okey101Penalty(seat: 0, kind: Okey101PenaltyKind.custom, amount: 33),
        ],
      );
      expect(
        engine.roundInputFromJson(input.toJson()).toJson(),
        input.toJson(),
      );
    });

    test('bozuk el JSON okunurken FormatException fırlatır', () {
      final json = finishedBy(1).toJson()
        ..['players'] = [
          {'state': 'uçtu', 'remaining': 3},
        ];
      expect(() => engine.roundInputFromJson(json), throwsFormatException);
    });
  });
}
