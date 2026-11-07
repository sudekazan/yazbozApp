import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/domain/models/game.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/models/round.dart';
import 'package:yazboz/domain/rules/free_rules.dart';

const engine = FreeGameRules();
const config3 = GameConfig(template: GameTemplate.free, seatCount: 3);

Game gameOf(FreeRuleSet rules, List<List<int>> rounds) => Game(
  config: config3,
  rules: rules,
  rounds: [
    for (final points in rounds)
      Round(
        input: FreeRoundInput(points),
        result: engine.calculateRound(FreeRoundInput(points), rules, config3),
      ),
  ],
);

void main() {
  const highest = FreeRuleSet();

  group('Serbest el hesabı', () {
    test('girilen puanlar aynen yazılır, negatif de olabilir', () {
      final result = engine.calculateRound(
        const FreeRoundInput([12, -7, 0]),
        highest,
        config3,
      );
      expect(result.points, [12, -7, 0]);
    });

    test('oyuncu sayısıyla uyuşmayan girdi reddedilir', () {
      final errors = engine.validate(
        const FreeRoundInput([1, 2]),
        highest,
        config3,
      );
      expect(errors.single.code, RoundErrorCode.wrongUnitCount);
    });

    test('±99.999 dışındaki puan hangi oyuncuda olduğunu söyler', () {
      final errors = engine.validate(
        const FreeRoundInput([1, 100000, 2]),
        highest,
        config3,
      );
      expect(
        (errors.single.code, errors.single.unit),
        (RoundErrorCode.pointsOutOfRange, 1),
      );
    });

    test('geçersiz girdi hesaplanmaz, hata fırlatılır', () {
      expect(
        () =>
            engine.calculateRound(const FreeRoundInput([1]), highest, config3),
        throwsA(isA<InvalidRoundException>()),
      );
    });
  });

  group('Serbest oyun durumu', () {
    test('hedef yoksa oyun kendiliğinden bitmez, en yüksek lider olur', () {
      final status = engine.evaluate(
        gameOf(highest, [
          [500, 10, 20],
          [600, 0, 0],
        ]),
      );
      expect(status.isFinished, isFalse);
      expect(status.leaders, [0]);
    });

    test('en düşük kazanır seçiliyse en düşük toplam lider olur', () {
      const rules = FreeRuleSet(winDirection: WinDirection.lowest);
      final status = engine.evaluate(
        gameOf(rules, [
          [5, -3, 8],
        ]),
      );
      expect(status.leaders, [1]);
    });

    test('hedefe ulaşan olunca oyun biter ve en yüksek kazanır', () {
      const rules = FreeRuleSet(target: 100);
      final status = engine.evaluate(
        gameOf(rules, [
          [60, 40, 10],
          [45, 30, 0],
        ]),
      );
      expect(status.isFinished, isTrue);
      expect(status.winners, [0]);
      expect(status.target, 100);
    });

    test('hedefi geçen iki oyuncu eşitse oyun sürer', () {
      const rules = FreeRuleSet(target: 100);
      final status = engine.evaluate(
        gameOf(rules, [
          [100, 100, 10],
        ]),
      );
      expect(status.isFinished, isFalse);
      expect(status.leaders, [0, 1]);
    });

    test('en düşük kazanır ve hedef varsa hedefe ulaşan oyunu bitirir', () {
      const rules = FreeRuleSet(winDirection: WinDirection.lowest, target: 100);
      final status = engine.evaluate(
        gameOf(rules, [
          [40, 101, 20],
        ]),
      );
      expect(status.isFinished, isTrue);
      expect(status.winners, [2]);
    });

    test('en düşük kazanırda eşit en düşükler birlikte kazanır', () {
      const rules = FreeRuleSet(winDirection: WinDirection.lowest, target: 50);
      final status = engine.evaluate(
        gameOf(rules, [
          [10, 10, 60],
        ]),
      );
      expect(status.winners, [0, 1]);
    });
  });

  group('Serbest kurallar', () {
    test('2-8 bireysel oyuncu desteklenir, eşli desteklenmez', () {
      expect(engine.supports(config3), isTrue);
      expect(
        engine.supports(
          const GameConfig(template: GameTemplate.free, seatCount: 8),
        ),
        isTrue,
      );
      expect(
        engine.supports(
          const GameConfig(
            template: GameTemplate.free,
            seatCount: 4,
            playMode: PlayMode.pairs,
          ),
        ),
        isFalse,
      );
    });

    test('her oyuncu bir sütundur', () {
      expect(engine.units(config3).map((u) => u.seats), [
        [0],
        [1],
        [2],
      ]);
    });

    test('sıfır ya da negatif hedef geçersizdir', () {
      expect(const FreeRuleSet(target: 0).validate(), isNotEmpty);
      expect(const FreeRuleSet(target: 150).validate(), isEmpty);
      expect(const FreeRuleSet().validate(), isEmpty);
    });

    test('kurallar ve el girdisi JSON üzerinden aynen geri okunur', () {
      const rules = FreeRuleSet(winDirection: WinDirection.lowest, target: 77);
      expect(engine.ruleSetFromJson(rules.toJson()).toJson(), rules.toJson());
      const input = FreeRoundInput([3, -4, 5]);
      expect(
        engine.roundInputFromJson(input.toJson()).toJson(),
        input.toJson(),
      );
    });

    test('eksik alanlı kural JSON varsayılanlarla okunur', () {
      final rules = engine.ruleSetFromJson(const {'template': 'free'});
      expect(rules.toJson(), const FreeRuleSet().toJson());
    });

    test('bozuk el JSON okunurken FormatException fırlatır', () {
      expect(
        () => engine.roundInputFromJson(const {
          'type': 'free',
          'points': ['a'],
        }),
        throwsFormatException,
      );
    });
  });
}
