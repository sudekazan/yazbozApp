import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/domain/models/game.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/models/round.dart';
import 'package:yazboz/domain/rules/tavla_rules.dart';

const engine = TavlaGameRules();
const config = GameConfig(template: GameTemplate.tavla, seatCount: 2);
const rules = TavlaRuleSet();
const withCube = TavlaRuleSet(doublingCube: true);

List<int> score(TavlaRoundInput input, {TavlaRuleSet ruleSet = rules}) =>
    engine.calculateRound(input, ruleSet, config).points;

Game gameOf(List<TavlaRoundInput> inputs, {TavlaRuleSet ruleSet = rules}) =>
    Game(
      config: config,
      rules: ruleSet,
      rounds: [
        for (final input in inputs)
          Round(
            input: input,
            result: engine.calculateRound(input, ruleSet, config),
          ),
      ],
    );

void main() {
  group('Tavla el hesabı', () {
    test('normal galibiyet 1 sayı', () {
      expect(score(const TavlaRoundInput(winnerSeat: 0)), [1, 0]);
    });

    test('mars 2 sayı', () {
      expect(score(const TavlaRoundInput(winnerSeat: 1, win: TavlaWin.mars)), [
        0,
        2,
      ]);
    });

    test('katlama küpü açıksa sayı küp değeriyle çarpılır', () {
      expect(
        score(
          const TavlaRoundInput(winnerSeat: 0, win: TavlaWin.mars, cube: 4),
          ruleSet: withCube,
        ),
        [8, 0],
      );
    });

    test('küp kapalıyken 1 dışında küp değeri reddedilir', () {
      final errors = engine.validate(
        const TavlaRoundInput(winnerSeat: 0, cube: 2),
        rules,
        config,
      );
      expect(errors.single.code, RoundErrorCode.cubeInvalid);
    });

    test('küp değeri 2nin kuvveti ve en çok 64 olmalı', () {
      for (final cube in [3, 128, 0]) {
        final errors = engine.validate(
          TavlaRoundInput(winnerSeat: 0, cube: cube),
          withCube,
          config,
        );
        expect(errors.single.code, RoundErrorCode.cubeInvalid, reason: '$cube');
      }
      expect(
        engine.validate(
          const TavlaRoundInput(winnerSeat: 0, cube: 64),
          withCube,
          config,
        ),
        isEmpty,
      );
    });

    test('kazanan masadaki iki oyuncudan biri olmalı', () {
      final errors = engine.validate(
        const TavlaRoundInput(winnerSeat: 2),
        rules,
        config,
      );
      expect(errors.single.code, RoundErrorCode.seatOutOfRange);
    });
  });

  group('Tavla oyun durumu', () {
    test('hedefe ilk ulaşan kazanır', () {
      final status = engine.evaluate(
        gameOf(const [
          TavlaRoundInput(winnerSeat: 0, win: TavlaWin.mars),
          TavlaRoundInput(winnerSeat: 1),
          TavlaRoundInput(winnerSeat: 0, win: TavlaWin.mars),
          TavlaRoundInput(winnerSeat: 0),
        ]),
      );
      expect(status.isFinished, isTrue);
      expect(status.winners, [0]);
      expect(status.target, 5);
    });

    test('hedefe ulaşılmadan oyun sürer', () {
      final status = engine.evaluate(
        gameOf(const [TavlaRoundInput(winnerSeat: 1, win: TavlaWin.mars)]),
      );
      expect(status.isFinished, isFalse);
      expect(status.leaders, [1]);
    });

    test('hedef kurallardan değiştirilebilir', () {
      const short = TavlaRuleSet(target: 3);
      final status = engine.evaluate(
        gameOf(const [
          TavlaRoundInput(winnerSeat: 1, win: TavlaWin.mars),
          TavlaRoundInput(winnerSeat: 1),
        ], ruleSet: short),
      );
      expect(status.winners, [1]);
    });
  });

  group('Tavla kurallar ve JSON', () {
    test('sadece 2 kişi bireysel desteklenir', () {
      expect(engine.supports(config), isTrue);
      expect(
        engine.supports(
          const GameConfig(template: GameTemplate.tavla, seatCount: 3),
        ),
        isFalse,
      );
    });

    test('hedef ve sayılar pozitif olmalı', () {
      expect(const TavlaRuleSet(target: 0).validate(), isNotEmpty);
      expect(const TavlaRuleSet(marsPoints: 0).validate(), isNotEmpty);
      expect(rules.validate(), isEmpty);
    });

    test('kurallar ve el girdisi JSON üzerinden aynen geri okunur', () {
      const custom = TavlaRuleSet(target: 11, doublingCube: true);
      expect(engine.ruleSetFromJson(custom.toJson()).toJson(), custom.toJson());
      const input = TavlaRoundInput(winnerSeat: 1, win: TavlaWin.mars, cube: 8);
      expect(
        engine.roundInputFromJson(input.toJson()).toJson(),
        input.toJson(),
      );
    });

    test('bozuk el JSON okunurken FormatException fırlatır', () {
      expect(
        () => engine.roundInputFromJson(const {
          'type': 'tavla',
          'winnerSeat': 0,
          'win': 'gammon',
          'cube': 1,
        }),
        throwsFormatException,
      );
    });
  });
}
