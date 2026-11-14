import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/rules/rules_registry.dart';
import 'package:yazboz/features/game_setup/setup_logic.dart';

void main() {
  test('şablonların oynanabildiği kişi sayıları', () {
    expect(allowedSeatCounts(GameTemplate.free, PlayMode.individual), [
      2, 3, 4, 5, 6, 7, 8, //
    ]);
    expect(allowedSeatCounts(GameTemplate.okey, PlayMode.individual), [4]);
    expect(allowedSeatCounts(GameTemplate.tavla, PlayMode.individual), [2]);
    expect(allowedSeatCounts(GameTemplate.pisti, PlayMode.individual), [2]);
    expect(allowedSeatCounts(GameTemplate.pisti, PlayMode.pairs), [4]);
    expect(allowedSeatCounts(GameTemplate.batak, PlayMode.individual), [3, 4]);
    expect(allowedSeatCounts(GameTemplate.batak, PlayMode.pairs), [4]);
  });

  test('herhangi bir oynanışla oynanabilen kişi sayıları sıralı gelir', () {
    expect(anySeatCounts(GameTemplate.okey), [4]);
    expect(anySeatCounts(GameTemplate.pisti), [2, 4]);
    expect(anySeatCounts(GameTemplate.batak), [3, 4]);
  });

  test('eşli oynanabilen şablonlar', () {
    expect(GameTemplate.values.where(supportsPairs), [
      GameTemplate.okey,
      GameTemplate.okey101,
      GameTemplate.pisti,
      GameTemplate.batak,
    ]);
  });

  test('varsayılan kişi sayısı 4, olmuyorsa ilk geçerli sayı', () {
    expect(defaultSeatCount(GameTemplate.free, PlayMode.individual), 4);
    expect(defaultSeatCount(GameTemplate.tavla, PlayMode.individual), 2);
    expect(defaultSeatCount(GameTemplate.pisti, PlayMode.individual), 2);
    expect(defaultSeatCount(GameTemplate.batak, PlayMode.individual), 4);
  });

  test('grup kişi sayısına göre oynanış seçilir, uymuyorsa null', () {
    expect(
      fitGroup(GameTemplate.pisti, PlayMode.individual, 4),
      PlayMode.pairs,
    );
    expect(
      fitGroup(GameTemplate.pisti, PlayMode.pairs, 2),
      PlayMode.individual,
    );
    expect(
      fitGroup(GameTemplate.free, PlayMode.individual, 6),
      PlayMode.individual,
    );
    expect(fitGroup(GameTemplate.okey, PlayMode.pairs, 4), PlayMode.pairs);
    expect(fitGroup(GameTemplate.okey, PlayMode.individual, 5), isNull);
  });

  test('Tavla dışında ilk dağıtıcı seçilir', () {
    expect(showsDealer(GameTemplate.tavla), isFalse);
    expect(showsDealer(GameTemplate.okey), isTrue);
  });

  test('her kural alanı varsayılan kural setinde var ve sınırlar içinde', () {
    for (final template in GameTemplate.values) {
      final config = GameConfig(
        template: template,
        seatCount: defaultSeatCount(template, PlayMode.individual),
      );
      final json = rulesFor(template).defaultRules(config).toJson();
      for (final field in ruleFields(template)) {
        final value = json[field.key];
        expect(value, isA<int>(), reason: '${template.name}.${field.key}');
        expect(field.accepts(value! as int), isTrue, reason: field.key);
      }
    }
  });

  test('kural alanı sınırları denetler', () {
    final minBid = ruleFields(GameTemplate.batak)
        .firstWhere((f) => f.key == 'minBid');
    expect(minBid.accepts(0), isFalse);
    expect(minBid.accepts(5), isTrue);
    expect(minBid.accepts(18), isFalse);
    final zero = ruleFields(GameTemplate.batak)
        .firstWhere((f) => f.key == 'zeroTricksPoints');
    expect(zero.accepts(-5), isTrue);
    expect(zero.allowsNegative, isTrue);
  });
}
