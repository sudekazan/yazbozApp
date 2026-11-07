import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/models/game_status.dart';

void main() {
  group('GameConfig', () {
    test('eşli oyunda karşılıklı oturanlar aynı takımdadır', () {
      const config = GameConfig(
        template: GameTemplate.okey,
        seatCount: 4,
        playMode: PlayMode.pairs,
      );
      expect([0, 1, 2, 3].map(config.teamOf), [0, 1, 0, 1]);
      expect([0, 1, 2, 3].map(config.partnerOf), [2, 3, 0, 1]);
    });

    test('bireysel oyunda takım ve eş yoktur', () {
      const config = GameConfig(template: GameTemplate.okey, seatCount: 4);
      expect(config.teamOf(0), isNull);
      expect(config.partnerOf(0), isNull);
    });

    test('koltuk ve takım sütunları doğru kurulur', () {
      const config = GameConfig(
        template: GameTemplate.pisti,
        seatCount: 4,
        playMode: PlayMode.pairs,
      );
      expect(config.seatUnits().map((u) => u.seats), [
        [0],
        [1],
        [2],
        [3],
      ]);
      expect(config.teamUnits().map((u) => u.seats), [
        [0, 2],
        [1, 3],
      ]);
    });

    test('eşli oyun 4 kişi değilse geçersizdir', () {
      const config = GameConfig(
        template: GameTemplate.batak,
        seatCount: 3,
        playMode: PlayMode.pairs,
      );
      expect(config.isValid, isFalse);
    });

    test('2-8 dışındaki oyuncu sayısı geçersizdir', () {
      expect(
        const GameConfig(template: GameTemplate.free, seatCount: 1).isValid,
        isFalse,
      );
      expect(
        const GameConfig(template: GameTemplate.free, seatCount: 9).isValid,
        isFalse,
      );
      expect(
        const GameConfig(template: GameTemplate.free, seatCount: 8).isValid,
        isTrue,
      );
    });

    test('şablon adı kayıtlı isimden çözülür, bilinmeyen isim null döner', () {
      expect(GameTemplate.fromName('okey101'), GameTemplate.okey101);
      expect(GameTemplate.fromName('poker'), isNull);
    });
  });

  group('Sıralama', () {
    test('yüksek iyi olduğunda eşitler aynı sırayı paylaşır', () {
      final standings = rankStandings(
        contenders: const [
          [0],
          [1],
          [2],
          [3],
        ],
        unitTotals: const [10, 30, 30, 5],
        higherIsBetter: true,
      );
      expect(standings.map((s) => (s.contender, s.rank)), [
        (1, 1),
        (2, 1),
        (0, 3),
        (3, 4),
      ]);
    });

    test('düşük iyi olduğunda en düşük toplam birinci olur', () {
      final standings = rankStandings(
        contenders: const [
          [0],
          [1],
          [2],
        ],
        unitTotals: const [10, -5, 30],
        higherIsBetter: false,
      );
      expect(standings.first.contender, 1);
      expect(standings.first.total, -5);
    });

    test('takım toplamı sütunların toplamıdır', () {
      final standings = rankStandings(
        contenders: const [
          [0, 2],
          [1, 3],
        ],
        unitTotals: const [10, 20, 5, 1],
        higherIsBetter: false,
      );
      expect(standings.map((s) => (s.contender, s.total)), [(0, 15), (1, 21)]);
    });

    test('devam eden oyunda kazanan yoktur ama lider vardır', () {
      final status = GameStatus(
        isFinished: false,
        standings: rankStandings(
          contenders: const [
            [0],
            [1],
          ],
          unitTotals: const [3, 7],
          higherIsBetter: true,
        ),
      );
      expect(status.leaders, [1]);
      expect(status.winners, isEmpty);
    });
  });
}
