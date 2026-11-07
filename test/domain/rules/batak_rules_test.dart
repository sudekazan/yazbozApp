import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/domain/models/game.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/models/round.dart';
import 'package:yazboz/domain/rules/batak_rules.dart';

const engine = BatakGameRules();
const four = GameConfig(template: GameTemplate.batak, seatCount: 4);
const three = GameConfig(template: GameTemplate.batak, seatCount: 3);
const pairs = GameConfig(
  template: GameTemplate.batak,
  seatCount: 4,
  playMode: PlayMode.pairs,
);
const bidding = BatakRuleSet();
const plain = BatakRuleSet(mode: BatakMode.plain);

List<int> score(
  BatakRoundInput input, {
  BatakRuleSet rules = bidding,
  GameConfig config = four,
}) => engine.calculateRound(input, rules, config).points;

List<RoundError> errorsOf(
  BatakRoundInput input, {
  BatakRuleSet rules = bidding,
  GameConfig config = four,
}) => engine.validate(input, rules, config);

Game gameOf(
  List<List<int>> tricks, {
  BatakRuleSet rules = plain,
  GameConfig config = four,
}) => Game(
  config: config,
  rules: rules,
  rounds: [
    for (final t in tricks)
      Round(
        input: BatakRoundInput(tricks: t),
        result: engine.calculateRound(
          BatakRoundInput(tricks: t),
          rules,
          config,
        ),
      ),
  ],
);

void main() {
  group('Düz Batak', () {
    test('herkes aldığı el kadar puan alır', () {
      expect(score(const BatakRoundInput(tricks: [3, 4, 2, 4]), rules: plain), [
        3,
        4,
        2,
        4,
      ]);
    });

    test('hiç el alamayan için kural puanı yazılır', () {
      const rules = BatakRuleSet(mode: BatakMode.plain, zeroTricksPoints: -5);
      expect(score(const BatakRoundInput(tricks: [0, 6, 3, 4]), rules: rules), [
        -5,
        6,
        3,
        4,
      ]);
    });
  });

  group('İhaleli Batak', () {
    test('ihaleyi tutturan aldığı el kadar alır', () {
      expect(
        score(
          const BatakRoundInput(bidderSeat: 2, bid: 8, tricks: [1, 2, 9, 1]),
        ),
        [1, 2, 9, 1],
      );
    });

    test('ihaleyi tam tutturan ihale kadar alır', () {
      expect(
        score(
          const BatakRoundInput(bidderSeat: 0, bid: 6, tricks: [6, 3, 2, 2]),
        ),
        [6, 3, 2, 2],
      );
    });

    test('ihaleyi tutturamayan (battı) ihale kadar eksi yazar', () {
      expect(
        score(
          const BatakRoundInput(bidderSeat: 2, bid: 8, tricks: [2, 3, 7, 1]),
        ),
        [2, 3, -8, 1],
      );
    });

    test('ihaleyi alan hiç el alamazsa yine ihale kadar eksi yazar', () {
      const rules = BatakRuleSet(zeroTricksPoints: -3);
      expect(
        score(
          const BatakRoundInput(bidderSeat: 1, bid: 5, tricks: [5, 0, 4, 4]),
          rules: rules,
        ),
        [5, -5, 4, 4],
      );
    });

    test('diğerlerinden hiç el alamayana varsayılan olarak 0 yazılır', () {
      expect(
        score(
          const BatakRoundInput(bidderSeat: 2, bid: 8, tricks: [2, 3, 8, 0]),
        ),
        [2, 3, 8, 0],
      );
    });

    test('hiç el alamayan kuralı ayarlanabilir', () {
      const rules = BatakRuleSet(zeroTricksPoints: -4);
      expect(
        score(
          const BatakRoundInput(bidderSeat: 2, bid: 8, tricks: [2, 3, 8, 0]),
          rules: rules,
        ),
        [2, 3, 8, -4],
      );
    });

    test('koz bilgi amaçlı saklanır, puanı etkilemez', () {
      expect(
        score(
          const BatakRoundInput(
            bidderSeat: 0,
            bid: 5,
            trump: BatakSuit.hearts,
            tricks: [5, 3, 3, 2],
          ),
        ),
        [5, 3, 3, 2],
      );
    });

    test('eşlide ihaleyi alanın takımının toplam eli sayılır', () {
      expect(
        score(
          const BatakRoundInput(bidderSeat: 1, bid: 7, tricks: [6, 7]),
          config: pairs,
        ),
        [6, 7],
      );
      expect(
        score(
          const BatakRoundInput(bidderSeat: 3, bid: 8, tricks: [6, 7]),
          config: pairs,
        ),
        [6, -8],
      );
      expect(engine.units(pairs).map((u) => u.seats), [
        [0, 2],
        [1, 3],
      ]);
    });
  });

  group('Batak doğrulama', () {
    test('4 kişide toplam el 13 olmalı, hata kaç olduğunu söyler', () {
      final error = errorsOf(
        const BatakRoundInput(tricks: [2, 3, 7, 0]),
        rules: plain,
      ).single;
      expect(
        (error.code, error.expected, error.actual),
        (RoundErrorCode.tricksTotalMismatch, 13, 12),
      );
    });

    test('3 kişide toplam el 17 olmalı', () {
      expect(
        errorsOf(
          const BatakRoundInput(tricks: [5, 6, 6]),
          rules: plain,
          config: three,
        ),
        isEmpty,
      );
      final error = errorsOf(
        const BatakRoundInput(tricks: [4, 4, 5]),
        rules: plain,
        config: three,
      ).single;
      expect((error.expected, error.actual), (17, 13));
    });

    test('negatif ya da dağıtımı aşan el sayısı reddedilir', () {
      final errors = errorsOf(
        const BatakRoundInput(tricks: [-1, 14, 0, 0]),
        rules: plain,
      );
      expect(errors.map((e) => (e.code, e.unit)), [
        (RoundErrorCode.tricksOutOfRange, 0),
        (RoundErrorCode.tricksOutOfRange, 1),
      ]);
    });

    test('ihaleli oyunda ihaleyi alan seçilmeli', () {
      expect(
        errorsOf(const BatakRoundInput(bid: 6, tricks: [6, 3, 2, 2]))
            .single
            .code,
        RoundErrorCode.bidderRequired,
      );
    });

    test('ihale en az ihale ile dağıtımdaki el sayısı arasında olmalı', () {
      for (final bid in [4, 14, null]) {
        final errors = errorsOf(
          BatakRoundInput(bidderSeat: 0, bid: bid, tricks: const [6, 3, 2, 2]),
        );
        expect(
          errors.single.code,
          RoundErrorCode.bidOutOfRange,
          reason: '$bid',
        );
      }
      expect(
        errorsOf(
          const BatakRoundInput(bidderSeat: 0, bid: 17, tricks: [17, 0, 0]),
          config: three,
        ),
        isEmpty,
      );
    });

    test('sütun sayısı uyuşmalı', () {
      expect(
        errorsOf(const BatakRoundInput(tricks: [13]), rules: plain).single.code,
        RoundErrorCode.wrongUnitCount,
      );
    });

    test('3-4 kişi bireysel ya da 4 kişi eşli desteklenir', () {
      expect(engine.supports(three), isTrue);
      expect(engine.supports(four), isTrue);
      expect(engine.supports(pairs), isTrue);
      expect(
        engine.supports(
          const GameConfig(template: GameTemplate.batak, seatCount: 2),
        ),
        isFalse,
      );
    });
  });

  group('Batak oyun durumu', () {
    test('11 el bitince oyun biter, en yüksek toplam kazanır', () {
      final status = engine.evaluate(
        gameOf([
          for (var i = 0; i < 11; i++) const [5, 3, 3, 2],
        ]),
      );
      expect(status.isFinished, isTrue);
      expect(status.winners, [0]);
      expect(status.roundsLeft, 0);
    });

    test('el sayısı dolmadan oyun sürer', () {
      final status = engine.evaluate(
        gameOf(const [
          [5, 3, 3, 2],
        ]),
      );
      expect(status.isFinished, isFalse);
      expect(status.roundsLeft, 10);
    });

    test('hedef puanla oynanınca hedefe ulaşan kazanır', () {
      const rules = BatakRuleSet(
        mode: BatakMode.plain,
        length: BatakLength.target,
        target: 20,
      );
      final status = engine.evaluate(
        gameOf(const [
          [10, 1, 1, 1],
          [10, 1, 1, 1],
        ], rules: rules),
      );
      expect(status.isFinished, isTrue);
      expect(status.winners, [0]);
      expect(status.target, 20);
    });

    test('hedefi geçen birinciler eşitse oyun sürer', () {
      const rules = BatakRuleSet(
        mode: BatakMode.plain,
        length: BatakLength.target,
        target: 6,
      );
      final status = engine.evaluate(
        gameOf(const [
          [6, 6, 1, 0],
        ], rules: rules),
      );
      expect(status.isFinished, isFalse);
    });
  });

  group('Batak kurallar ve JSON', () {
    test('hedef puanla oynanırken hedef girilmeli', () {
      expect(
        const BatakRuleSet(length: BatakLength.target).validate(),
        isNotEmpty,
      );
      expect(bidding.validate(), isEmpty);
    });

    test('en az ihale ve el sayısı geçerli olmalı', () {
      expect(const BatakRuleSet(minBid: 0).validate(), isNotEmpty);
      expect(const BatakRuleSet(rounds: 0).validate(), isNotEmpty);
    });

    test('kurallar ve el girdisi JSON üzerinden aynen geri okunur', () {
      const custom = BatakRuleSet(
        length: BatakLength.target,
        target: 61,
        zeroTricksPoints: -2,
      );
      expect(engine.ruleSetFromJson(custom.toJson()).toJson(), custom.toJson());
      const input = BatakRoundInput(
        bidderSeat: 1,
        bid: 7,
        trump: BatakSuit.spades,
        tricks: [3, 7, 2, 1],
      );
      expect(
        engine.roundInputFromJson(input.toJson()).toJson(),
        input.toJson(),
      );
    });

    test('bozuk el JSON okunurken FormatException fırlatır', () {
      expect(
        () => engine.roundInputFromJson(const {
          'type': 'batak',
          'bidderSeat': null,
          'bid': null,
          'trump': 'yıldız',
          'tricks': [13],
        }),
        throwsFormatException,
      );
    });
  });
}
