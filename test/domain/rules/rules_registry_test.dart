import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/domain/models/game.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/models/round.dart';
import 'package:yazboz/domain/rules/batak_rules.dart';
import 'package:yazboz/domain/rules/free_rules.dart';
import 'package:yazboz/domain/rules/game_rules.dart';
import 'package:yazboz/domain/rules/okey101_rules.dart';
import 'package:yazboz/domain/rules/okey_rules.dart';
import 'package:yazboz/domain/rules/pisti_rules.dart';
import 'package:yazboz/domain/rules/rules_registry.dart';
import 'package:yazboz/domain/rules/tavla_rules.dart';
import 'package:yazboz/domain/seating.dart';

/// Her şablon için geçerli bir kurulum ve örnek el.
final samples = <GameTemplate, (GameConfig, RoundInput)>{
  GameTemplate.free: (
    const GameConfig(template: GameTemplate.free, seatCount: 3),
    const FreeRoundInput([1, 2, 3]),
  ),
  GameTemplate.okey: (
    const GameConfig(template: GameTemplate.okey, seatCount: 4),
    const OkeyRoundInput(finisherSeat: 0),
  ),
  GameTemplate.okey101: (
    const GameConfig(template: GameTemplate.okey101, seatCount: 4),
    const Okey101RoundInput(
      finisherSeat: 0,
      players: [
        Okey101Player(state: Okey101PlayerState.opened),
        Okey101Player(state: Okey101PlayerState.opened, remaining: 12),
        Okey101Player(state: Okey101PlayerState.notOpened),
        Okey101Player(state: Okey101PlayerState.openedPairs, remaining: 4),
      ],
    ),
  ),
  GameTemplate.tavla: (
    const GameConfig(template: GameTemplate.tavla, seatCount: 2),
    const TavlaRoundInput(winnerSeat: 1),
  ),
  GameTemplate.pisti: (
    const GameConfig(template: GameTemplate.pisti, seatCount: 2),
    const PistiDirectInput([12, 4]),
  ),
  GameTemplate.batak: (
    const GameConfig(template: GameTemplate.batak, seatCount: 4),
    const BatakRoundInput(bidderSeat: 0, bid: 5, tricks: [5, 4, 2, 2]),
  ),
};

void main() {
  test('her şablonun bir puan motoru ve örneği var', () {
    expect(samples.keys.toSet(), GameTemplate.values.toSet());
    for (final template in GameTemplate.values) {
      expect(rulesFor(template).template, template);
    }
  });

  for (final MapEntry(key: template, value: (config, input))
      in samples.entries) {
    group(template.name, () {
      GameRules engine() => rulesFor(template);

      test('varsayılan kurallar geçerli ve kurulumu destekliyor', () {
        expect(engine().supports(config), isTrue);
        expect(engine().defaultRules(config).validate(), isEmpty);
      });

      test('kural seti şablon adından çözülür', () {
        final rules = engine().defaultRules(config);
        final back = decodeRuleSet(rules.toJson());
        expect(back.template, template);
        expect(back.toJson(), rules.toJson());
      });

      test('el girdisi şablona göre çözülür', () {
        final back = decodeRoundInput(template, input.toJson());
        expect(back.toJson(), input.toJson());
      });

      test('başka şablonun girdisi FormatException fırlatır', () {
        final other = samples.entries
            .firstWhere((e) => e.key != template)
            .value
            .$2;
        expect(
          () => decodeRoundInput(template, other.toJson()),
          throwsFormatException,
        );
      });
    });
  }

  test('bilinmeyen ya da eksik şablon adı FormatException fırlatır', () {
    expect(
      () => decodeRuleSet(const {'template': 'poker'}),
      throwsFormatException,
    );
    expect(() => decodeRuleSet(const {}), throwsFormatException);
  });

  test('oyuncu değiştirmek koltuğun puanlarını değiştirmez', () {
    final (config, _) = samples[GameTemplate.free]!;
    final engine = rulesFor(GameTemplate.free);
    const rules = FreeRuleSet();
    final game = Game(
      config: config,
      rules: rules,
      rounds: [
        for (final points in const [
          [10, 20, 30],
          [5, -5, 0],
        ])
          Round(
            input: FreeRoundInput(points),
            result: engine.calculateRound(
              FreeRoundInput(points),
              rules,
              config,
            ),
          ),
      ],
    );
    final before = engine.evaluate(game).standings.map((s) => s.total).toList();

    final seating = Seating.initial(['Ayşe', 'Mehmet', 'Zeynep'])
        .replace(2, 'Burak', roundsPlayed: game.rounds.length);
    final after = engine.evaluate(game).standings.map((s) => s.total).toList();

    expect(after, before);
    expect(seating.nameAt(2, 3), 'Burak');
    // Koltuk 2'nin toplamı (30) yeni oyuncuyla devam eder.
    expect(
      engine.evaluate(game).standings.firstWhere((s) => s.contender == 2).total,
      30,
    );
  });
}
