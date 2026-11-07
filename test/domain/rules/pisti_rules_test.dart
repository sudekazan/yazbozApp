import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/domain/models/game.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/models/round.dart';
import 'package:yazboz/domain/rules/pisti_rules.dart';

const engine = PistiGameRules();
const solo = GameConfig(template: GameTemplate.pisti, seatCount: 2);
const pairs = GameConfig(
  template: GameTemplate.pisti,
  seatCount: 4,
  playMode: PlayMode.pairs,
);
const rules = PistiRuleSet();

/// Kartların hepsi 0. oyuncuda değil; sadece sayaçlar, sahipler ayrı.
PistiCountInput counts({
  PistiCounts a = const PistiCounts(),
  PistiCounts b = const PistiCounts(),
  int? majority,
  int? clubTwo = 0,
  int? diamondTen = 0,
}) => PistiCountInput(
  counts: [a, b],
  majorityUnit: majority,
  clubTwoUnit: clubTwo,
  diamondTenUnit: diamondTen,
);

List<int> score(RoundInput input, {GameConfig config = solo}) =>
    engine.calculateRound(input, rules, config).points;

Game gameOf(List<List<int>> rounds, {PistiRuleSet ruleSet = rules}) => Game(
  config: solo,
  rules: ruleSet,
  rounds: [
    for (final points in rounds)
      Round(
        input: PistiDirectInput(points),
        result: engine.calculateRound(PistiDirectInput(points), ruleSet, solo),
      ),
  ],
);

void main() {
  group('Pişti sayaç hesabı', () {
    test('her pişti 10 puan', () {
      final points = score(
        counts(a: const PistiCounts(pisti: 2), clubTwo: 1, diamondTen: 1),
      );
      expect(points, [20, 5]);
    });

    test('vale piştisi 20 puan', () {
      final points = score(counts(b: const PistiCounts(jackPisti: 1)));
      expect(points, [5, 20]);
    });

    test('kart çoğunluğu +3, eşitse kimse almaz', () {
      expect(score(counts(majority: 1)), [5, 3]);
      expect(score(counts()), [5, 0]);
    });

    test('sinek 2 +2, karo 10 +3', () {
      expect(score(counts(diamondTen: 1)), [2, 3]);
    });

    test('her as ve her vale 1 puan', () {
      final points = score(
        counts(
          a: const PistiCounts(aces: 3, jacks: 1),
          b: const PistiCounts(aces: 1, jacks: 3),
          clubTwo: 1,
          diamondTen: 1,
        ),
      );
      expect(points, [4, 9]);
    });

    test('tam bir el: tasarımdaki örnek (21 - 25)', () {
      final points = score(
        counts(
          a: const PistiCounts(pisti: 1, aces: 3, jacks: 2),
          b: const PistiCounts(jackPisti: 1, aces: 1, jacks: 2),
          majority: 0,
          clubTwo: 1,
        ),
      );
      expect(points, [21, 25]);
    });

    test('kurallardaki değerler kullanılır', () {
      const custom = PistiRuleSet(pisti: 5, majority: 2);
      final points = engine
          .calculateRound(
            counts(
              a: const PistiCounts(pisti: 2),
              majority: 0,
              clubTwo: 1,
              diamondTen: 1,
            ),
            custom,
            solo,
          )
          .points;
      expect(points, [12, 5]);
    });

    test('eşli oyunda sütunlar takımlardır', () {
      expect(engine.units(pairs).map((u) => u.seats), [
        [0, 2],
        [1, 3],
      ]);
      expect(score(counts(clubTwo: 1, diamondTen: 1), config: pairs), [0, 5]);
    });
  });

  group('Pişti doğrudan puan', () {
    test('girilen puanlar aynen yazılır', () {
      expect(score(const PistiDirectInput([30, 12])), [30, 12]);
    });

    test('±99.999 dışı reddedilir', () {
      final errors = engine.validate(
        const PistiDirectInput([0, 100000]),
        rules,
        solo,
      );
      expect(errors.single.code, RoundErrorCode.pointsOutOfRange);
    });
  });

  group('Pişti doğrulama', () {
    List<RoundErrorCode> codes(PistiCountInput input) =>
        engine.validate(input, rules, solo).map((e) => e.code).toList();

    test('as toplamı 4ü geçemez', () {
      expect(
        codes(
          counts(a: const PistiCounts(aces: 3), b: const PistiCounts(aces: 2)),
        ),
        [RoundErrorCode.acesOverLimit],
      );
    });

    test('vale toplamı 4ü geçemez', () {
      expect(
        codes(
          counts(
            a: const PistiCounts(jacks: 4),
            b: const PistiCounts(jacks: 1),
          ),
        ),
        [RoundErrorCode.jacksOverLimit],
      );
    });

    test('sayaçlar negatif olamaz', () {
      final errors = engine.validate(
        counts(b: const PistiCounts(pisti: -1)),
        rules,
        solo,
      );
      expect(
        (errors.single.code, errors.single.unit),
        (RoundErrorCode.countOutOfRange, 1),
      );
    });

    test('sinek 2 ve karo 10u alan seçilmeli', () {
      expect(codes(counts(clubTwo: null, diamondTen: null)), [
        RoundErrorCode.clubTwoOwnerRequired,
        RoundErrorCode.diamondTenOwnerRequired,
      ]);
    });

    test('olmayan sütun seçilemez', () {
      expect(codes(counts(majority: 2)), [RoundErrorCode.unitOutOfRange]);
    });

    test('sütun sayısı uyuşmalı', () {
      expect(
        codes(
          const PistiCountInput(
            counts: [PistiCounts()],
            clubTwoUnit: 0,
            diamondTenUnit: 0,
          ),
        ),
        [RoundErrorCode.wrongUnitCount],
      );
    });

    test('2 kişi bireysel ya da 4 kişi eşli desteklenir', () {
      expect(engine.supports(solo), isTrue);
      expect(engine.supports(pairs), isTrue);
      expect(
        engine.supports(
          const GameConfig(template: GameTemplate.pisti, seatCount: 4),
        ),
        isFalse,
      );
    });
  });

  group('Pişti oyun durumu', () {
    test('hedefe (151) ulaşan kazanır', () {
      final status = engine.evaluate(
        gameOf([
          [100, 40],
          [55, 20],
        ]),
      );
      expect(status.isFinished, isTrue);
      expect(status.winners, [0]);
      expect(status.target, 151);
    });

    test('ikisi de hedefi geçerse yüksek olan kazanır', () {
      final status = engine.evaluate(
        gameOf([
          [140, 145],
          [20, 30],
        ]),
      );
      expect(status.winners, [1]);
    });

    test('hedefi geçen iki toplam eşitse oyun sürer', () {
      final status = engine.evaluate(
        gameOf([
          [160, 160],
        ]),
      );
      expect(status.isFinished, isFalse);
    });

    test('hedef kurallardan değiştirilebilir', () {
      final status = engine.evaluate(
        gameOf([
          [101, 3],
        ], ruleSet: const PistiRuleSet(target: 101)),
      );
      expect(status.isFinished, isTrue);
    });
  });

  group('Pişti kurallar ve JSON', () {
    test('hedef pozitif olmalı', () {
      expect(const PistiRuleSet(target: 0).validate(), isNotEmpty);
      expect(rules.validate(), isEmpty);
    });

    test('kurallar ve iki girdi türü JSON üzerinden aynen geri okunur', () {
      const custom = PistiRuleSet(target: 201, jackPisti: 25);
      expect(engine.ruleSetFromJson(custom.toJson()).toJson(), custom.toJson());
      final RoundInput countInput = counts(
        a: const PistiCounts(pisti: 1, aces: 2),
        majority: 1,
        diamondTen: 1,
      );
      const RoundInput directInput = PistiDirectInput([12, 7]);
      for (final input in [countInput, directInput]) {
        final back = engine.roundInputFromJson(input.toJson());
        expect(back.runtimeType, input.runtimeType);
        expect(back.toJson(), input.toJson());
      }
    });

    test('bilinmeyen girdi türü FormatException fırlatır', () {
      expect(
        () => engine.roundInputFromJson(const {'type': 'pisti.bilinmeyen'}),
        throwsFormatException,
      );
    });
  });
}
