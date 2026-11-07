import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/domain/models/game.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/models/round.dart';
import 'package:yazboz/domain/rules/okey_rules.dart';

const engine = OkeyGameRules();
const solo = GameConfig(template: GameTemplate.okey, seatCount: 4);
const pairs = GameConfig(
  template: GameTemplate.okey,
  seatCount: 4,
  playMode: PlayMode.pairs,
);
const rules = OkeyRuleSet();

List<int> score(OkeyRoundInput input, {GameConfig config = solo}) =>
    engine.calculateRound(input, rules, config).points;

Game gameOf(List<OkeyRoundInput> inputs, {GameConfig config = solo}) => Game(
  config: config,
  rules: rules,
  rounds: [
    for (final input in inputs)
      Round(input: input, result: engine.calculateRound(input, rules, config)),
  ],
);

void main() {
  group('Okey bireysel el hesabı', () {
    test('normal bitişte bitiren hariç herkes 2 kaybeder', () {
      expect(score(const OkeyRoundInput(finisherSeat: 1)), [-2, 0, -2, -2]);
    });

    test('okey atarak bitişte diğerleri 4 kaybeder', () {
      expect(
        score(const OkeyRoundInput(finisherSeat: 0, finish: OkeyFinish.okey)),
        [0, -4, -4, -4],
      );
    });

    test('çifte bitişte diğerleri 4 kaybeder', () {
      expect(
        score(const OkeyRoundInput(finisherSeat: 3, finish: OkeyFinish.pairs)),
        [-4, -4, -4, 0],
      );
    });

    test('okey atarak çifte bitişte diğerleri 8 kaybeder', () {
      expect(
        score(
          const OkeyRoundInput(finisherSeat: 2, finish: OkeyFinish.okeyPairs),
        ),
        [-8, -8, 0, -8],
      );
    });

    test('gösterge gösteren hariç herkes 1 kaybeder', () {
      expect(score(const OkeyRoundInput(indicatorSeats: [2])), [-1, -1, 0, -1]);
    });

    test('bitiş ve gösterge aynı elde toplanır', () {
      expect(
        score(const OkeyRoundInput(finisherSeat: 1, indicatorSeats: [2])),
        [-3, -1, -2, -3],
      );
    });

    test('iki oyuncu gösterge gösterebilir', () {
      expect(score(const OkeyRoundInput(indicatorSeats: [0, 2])), [
        -1,
        -2,
        -1,
        -2,
      ]);
    });

    test('kimse bitiremediyse sadece gösterge işler', () {
      expect(score(const OkeyRoundInput()), [0, 0, 0, 0]);
    });

    test('kurallardaki değerler kullanılır', () {
      const custom = OkeyRuleSet(normalFinish: 3, indicator: 2);
      final points = engine
          .calculateRound(
            const OkeyRoundInput(finisherSeat: 0, indicatorSeats: [1]),
            custom,
            solo,
          )
          .points;
      expect(points, [-2, -3, -5, -5]);
    });
  });

  group('Okey eşli el hesabı', () {
    test('takım başına tek puan: bitirenin rakip takımı bir kez düşer', () {
      expect(score(const OkeyRoundInput(finisherSeat: 1), config: pairs), [
        -2,
        0,
      ]);
    });

    test('göstergeyi gösterenin rakip takımı düşer', () {
      expect(score(const OkeyRoundInput(indicatorSeats: [0]), config: pairs), [
        0,
        -1,
      ]);
    });

    test('sütunlar takımlardır', () {
      expect(engine.units(pairs).map((u) => u.seats), [
        [0, 2],
        [1, 3],
      ]);
    });
  });

  group('Okey doğrulama', () {
    test('bitiren seçilmeden bitiş türü seçilemez', () {
      final errors = engine.validate(
        const OkeyRoundInput(finish: OkeyFinish.okey),
        rules,
        solo,
      );
      expect(errors.single.code, RoundErrorCode.finishWithoutFinisher);
    });

    test('masada olmayan koltuk reddedilir', () {
      final errors = engine.validate(
        const OkeyRoundInput(finisherSeat: 4, indicatorSeats: [-1]),
        rules,
        solo,
      );
      expect(errors.map((e) => (e.code, e.seat)), [
        (RoundErrorCode.seatOutOfRange, 4),
        (RoundErrorCode.seatOutOfRange, -1),
      ]);
    });

    test('4 kişi bireysel ve eşli desteklenir, 3 kişi desteklenmez', () {
      expect(engine.supports(solo), isTrue);
      expect(engine.supports(pairs), isTrue);
      expect(
        engine.supports(
          const GameConfig(template: GameTemplate.okey, seatCount: 3),
        ),
        isFalse,
      );
    });
  });

  group('Okey oyun durumu', () {
    test('herkes 20 ile başlar, en yüksek puan lider olur', () {
      final status = engine.evaluate(
        gameOf(const [OkeyRoundInput(finisherSeat: 1)]),
      );
      expect(status.standings.first.total, 20);
      expect(status.leaders, [1]);
      expect(status.isFinished, isFalse);
    });

    test('birinin puanı 0 ya da altına inince oyun biter', () {
      final rounds = [
        for (var i = 0; i < 4; i++)
          const OkeyRoundInput(finisherSeat: 0, finish: OkeyFinish.okeyPairs),
      ];
      // 3 elde diğerleri 20 - 24 = -4 olur; 3. elde oyun biter.
      final status = engine.evaluate(gameOf(rounds.take(3).toList()));
      expect(status.isFinished, isTrue);
      expect(status.winners, [0]);
      expect(status.standings.last.total, -4);
    });

    test('tam 0 da oyunu bitirir', () {
      final rounds = [
        for (var i = 0; i < 10; i++) const OkeyRoundInput(finisherSeat: 0),
      ];
      final status = engine.evaluate(gameOf(rounds));
      expect(status.standings.last.total, 0);
      expect(status.isFinished, isTrue);
    });

    test('bittiğinde en yüksekler eşitse birlikte kazanır', () {
      final status = engine.evaluate(
        gameOf([
          for (var i = 0; i < 10; i++)
            const OkeyRoundInput(indicatorSeats: [0, 1]),
        ]),
      );
      expect(status.isFinished, isTrue);
      expect(status.winners, [0, 1]);
    });

    test('eşli oyunda takım puanı 20 ile başlar', () {
      final status = engine.evaluate(
        gameOf(const [OkeyRoundInput(finisherSeat: 0)], config: pairs),
      );
      expect(status.standings.map((s) => (s.contender, s.total)), [
        (0, 20),
        (1, 18),
      ]);
    });
  });

  group('Okey kurallar ve JSON', () {
    test('sıfır başlangıç puanı geçersizdir', () {
      expect(const OkeyRuleSet(startingPoints: 0).validate(), isNotEmpty);
      expect(rules.validate(), isEmpty);
    });

    test('kurallar ve el girdisi JSON üzerinden aynen geri okunur', () {
      const custom = OkeyRuleSet(startingPoints: 15, okeyPairsFinish: 10);
      expect(engine.ruleSetFromJson(custom.toJson()).toJson(), custom.toJson());
      const input = OkeyRoundInput(
        finisherSeat: 2,
        finish: OkeyFinish.pairs,
        indicatorSeats: [1, 3],
      );
      expect(
        engine.roundInputFromJson(input.toJson()).toJson(),
        input.toJson(),
      );
    });

    test('bozuk el JSON okunurken FormatException fırlatır', () {
      expect(
        () => engine.roundInputFromJson(const {
          'type': 'okey',
          'finisherSeat': 'iki',
          'finish': 'normal',
          'indicatorSeats': <int>[],
        }),
        throwsFormatException,
      );
    });
  });
}
