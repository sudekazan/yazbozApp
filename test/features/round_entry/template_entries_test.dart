import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/core/router/app_router.dart';
import 'package:yazboz/data/db/app_database.dart';
import 'package:yazboz/data/repositories/game_models.dart';
import 'package:yazboz/data/repositories/game_repository.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/models/rule_set.dart';
import 'package:yazboz/domain/rules/batak_rules.dart';
import 'package:yazboz/domain/rules/okey101_rules.dart';
import 'package:yazboz/domain/rules/okey_rules.dart';
import 'package:yazboz/domain/rules/pisti_rules.dart';
import 'package:yazboz/domain/rules/tavla_rules.dart';

import '../../helpers.dart';

const four = ['Ayşe', 'Mehmet', 'Zeynep', 'Can'];
const two = ['Ayşe', 'Mehmet'];

Future<int> createGame(
  AppDatabase db,
  GameTemplate template,
  RuleSet rules,
  List<String> names, {
  PlayMode mode = PlayMode.individual,
}) => GameRepository(db).createGame(
  config: GameConfig(
    template: template,
    seatCount: names.length,
    playMode: mode,
  ),
  rules: rules,
  playerNames: names,
);

Future<StoredRound> onlyRound(AppDatabase db, int id) async =>
    ((await GameRepository(
      db,
    ).loadGame(id)) as GameLoaded).snapshot.rounds.single;

Future<void> openEntry(WidgetTester tester, AppDatabase db, int id) async {
  await pumpApp(tester, db: db, location: AppRoutes.game(id));
  await tester.tap(find.text('El Ekle'));
  await tester.pumpAndSettle();
}

/// Sayfa içinde görünür yapıp dokunur.
Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

/// Sayfadaki [text] yazılı [index]. öğe (aynı isim birden çok bölümde var).
Finder inSheet(String text, [int index = 0]) => find
    .descendant(of: find.byType(BottomSheet), matching: find.text(text))
    .at(index);

Future<void> press(WidgetTester tester, String keys) async {
  for (final key in keys.split('')) {
    await tester.tap(
      key == 'v'
          ? find.byTooltip('Sonraki oyuncuya geç')
          : find.descendant(
              of: find.bySemanticsLabel('Sayı tuşları'),
              matching: find.text(key),
            ),
    );
    await tester.pump();
  }
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
  await tester.pumpAndSettle();
}

void main() {
  group('Tavla', () {
    testApp('kazanan seçilmeden kaydedilmez, hata çözüm söyler', (
      tester,
      db,
    ) async {
      final id = await createGame(
        db,
        GameTemplate.tavla,
        const TavlaRuleSet(),
        two,
      );
      await openEntry(tester, db, id);
      await save(tester);
      expect(find.text('Eli kazananı seç.'), findsOneWidget);
    });

    testApp('mars ve küp puanı çarpar', (tester, db) async {
      final id = await createGame(
        db,
        GameTemplate.tavla,
        const TavlaRuleSet(doublingCube: true),
        two,
      );
      await openEntry(tester, db, id);
      await tapOn(tester, inSheet('Mehmet'));
      await tapOn(tester, inSheet('Mars'));
      await tapOn(tester, inSheet('x4'));
      await save(tester);

      final round = await onlyRound(db, id);
      expect(round.round.result.points, [0, 8]);
      expect(round.round.result.multiplier, 4);
    });
  });

  group('Okey', () {
    testApp('bitiren, bitiş türü ve gösterge birlikte hesaplanır', (
      tester,
      db,
    ) async {
      final id = await createGame(
        db,
        GameTemplate.okey,
        const OkeyRuleSet(),
        four,
      );
      await openEntry(tester, db, id);
      await tapOn(tester, inSheet('Mehmet'));
      await tapOn(tester, inSheet('Okey atarak'));
      // İkinci "Zeynep" gösterge bölümünde.
      await tapOn(tester, inSheet('Zeynep', 1));
      expect(
        find.bySemanticsLabel('Ayşe −5, Mehmet −1, Zeynep −4, Can −5'),
        findsOneWidget,
      );
      await save(tester);
      expect((await onlyRound(db, id)).round.result.points, [-5, -1, -4, -5]);
    });

    testApp('kimse bitiremediyse sadece gösterge işler', (tester, db) async {
      final id = await createGame(
        db,
        GameTemplate.okey,
        const OkeyRuleSet(),
        four,
      );
      await openEntry(tester, db, id);
      await save(tester);
      expect(find.textContaining('Eli bitireni seç'), findsOneWidget);

      await tapOn(tester, inSheet('Kimse bitiremedi'));
      expect(find.text('Nasıl bitti?'), findsNothing);
      await tapOn(tester, inSheet('Ayşe', 1));
      await save(tester);
      expect((await onlyRound(db, id)).round.result.points, [0, -1, -1, -1]);
    });
  });

  group('101', () {
    testApp('kalan taşlar, açamayan, çift ve ceza kaydedilir', (
      tester,
      db,
    ) async {
      final id = await createGame(
        db,
        GameTemplate.okey101,
        const Okey101RuleSet(),
        four,
      );
      await openEntry(tester, db, id);
      await tapOn(tester, inSheet('Mehmet'));
      await tapOn(tester, inSheet('Okeyle ×2'));
      expect(find.text('Bitirdi'), findsOneWidget);

      // Odak ilk yazılabilir alanda (Ayşe); Zeynep açamadı, Can çiftten açtı.
      await press(tester, '38');
      await tapOn(tester, find.widgetWithText(FilterChip, 'Açamadı').at(1));
      await tapOn(tester, find.widgetWithText(FilterChip, 'Çift').at(2));
      await press(tester, 'v10');

      await tapOn(tester, find.text('Ceza Ekle'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Zeynep'),
        ),
      );
      await tester.tap(find.text('İşler taş atma'));
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Ceza Ekle'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Zeynep · İşler taş atma +101'), findsOneWidget);

      await save(tester);
      final round = await onlyRound(db, id);
      final input = round.round.input as Okey101RoundInput;
      expect(input.finisherSeat, 1);
      expect(input.withOkey, isTrue);
      expect(input.players.map((p) => (p.state, p.remaining)), [
        (Okey101PlayerState.opened, 38),
        (Okey101PlayerState.opened, 0),
        (Okey101PlayerState.notOpened, 0),
        (Okey101PlayerState.openedPairs, 10),
      ]);
      expect(input.penalties.single.seat, 2);
      expect(round.round.result.multiplier, 2);
    });

    testApp('eşlide bitirenin eşi alan yazmaz', (tester, db) async {
      final id = await createGame(
        db,
        GameTemplate.okey101,
        const Okey101RuleSet(),
        four,
        mode: PlayMode.pairs,
      );
      await openEntry(tester, db, id);
      await tapOn(tester, inSheet('Ayşe'));
      expect(find.text('Eşi bitirdi, 0 yazar'), findsOneWidget);
      // Odak Mehmet'te; Zeynep atlanır, ↓ Can'a geçer.
      await press(tester, '5v7');
      await save(tester);
      final input = (await onlyRound(db, id)).round.input as Okey101RoundInput;
      expect(input.players.map((p) => p.remaining), [0, 5, 0, 7]);
    });
  });

  group('Pişti', () {
    testApp('sayaçlar ve tek sahipli kartlarla hesaplanır', (tester, db) async {
      final id = await createGame(
        db,
        GameTemplate.pisti,
        const PistiRuleSet(),
        two,
      );
      await openEntry(tester, db, id);
      await tapOn(tester, find.byTooltip('Ayşe: Pişti artır'));
      for (var i = 0; i < 3; i++) {
        await tapOn(tester, find.byTooltip('Ayşe: As artır'));
      }
      await save(tester);
      expect(find.textContaining('Kart çoğunluğunu alanı seç'), findsOneWidget);

      // Kart çoğunluğu: Ayşe, Sinek 2: Mehmet, Karo 10: Ayşe.
      await tapOn(tester, inSheet('Ayşe', 4));
      await save(tester);
      expect(find.text('Sinek 2\'yi alanı seç.'), findsOneWidget);
      await tapOn(tester, inSheet('Mehmet', 5));
      await tapOn(tester, inSheet('Ayşe', 6));
      await save(tester);

      final input = (await onlyRound(db, id)).round.input as PistiCountInput;
      // Mehmet'in ası 4'ten kalanla doldu.
      expect(input.counts.map((c) => c.aces), [3, 1]);
      expect((await onlyRound(db, id)).round.result.points, [19, 3]);
    });

    testApp('doğrudan puan girilebilir', (tester, db) async {
      final id = await createGame(
        db,
        GameTemplate.pisti,
        const PistiRuleSet(),
        two,
      );
      await openEntry(tester, db, id);
      await tapOn(tester, find.text('Doğrudan puan'));
      await press(tester, '25v7');
      await save(tester);
      expect((await onlyRound(db, id)).round.result.points, [25, 7]);
    });
  });

  group('Batak', () {
    testApp('son oyuncu kalanla dolar, batan ihale eksi yazar', (
      tester,
      db,
    ) async {
      final id = await createGame(
        db,
        GameTemplate.batak,
        const BatakRuleSet(),
        four,
      );
      await openEntry(tester, db, id);
      await save(tester);
      expect(find.text('İhaleyi alanı seç.'), findsOneWidget);

      await tapOn(tester, inSheet('Zeynep'));
      for (var i = 0; i < 3; i++) {
        await tapOn(tester, find.byTooltip('İhaleyi artır'));
      }
      Future<void> add(String name, int times) async {
        for (var i = 0; i < times; i++) {
          await tapOn(tester, find.byTooltip('$name el sayısını artır'));
        }
      }

      await add('Ayşe', 2);
      await add('Mehmet', 3);
      await add('Zeynep', 7);
      expect(find.text('İhale 8 · battı'), findsOneWidget);
      await save(tester);
      expect((await onlyRound(db, id)).round.result.points, [2, 3, -8, 1]);
    });

    testApp('toplam tutmazsa kaç olması gerektiğini söyler', (
      tester,
      db,
    ) async {
      final id = await createGame(
        db,
        GameTemplate.batak,
        const BatakRuleSet(mode: BatakMode.plain),
        ['Ayşe', 'Mehmet', 'Can'],
      );
      await openEntry(tester, db, id);
      expect(find.text('İhaleyi alan'), findsNothing);
      await tapOn(tester, find.byTooltip('Ayşe el sayısını artır'));
      // Son oyuncu elle değiştirilince artık kendiliğinden dolmaz:
      // 1 + 0 + 17 = 18.
      await tapOn(tester, find.byTooltip('Can el sayısını artır'));
      await save(tester);
      expect(
        find.text('Toplam el sayısı 17 olmalı, şu an 18.'),
        findsOneWidget,
      );
      // Hata kaydet denendikten sonra canlı güncellenir.
      await tapOn(tester, find.byTooltip('Mehmet el sayısını artır'));
      expect(
        find.text('Toplam el sayısı 17 olmalı, şu an 19.'),
        findsOneWidget,
      );
    });

    testApp('eşlide takım başına el girilir', (tester, db) async {
      final id = await createGame(
        db,
        GameTemplate.batak,
        const BatakRuleSet(),
        four,
        mode: PlayMode.pairs,
      );
      await openEntry(tester, db, id);
      await tapOn(tester, inSheet('Mehmet'));
      for (var i = 0; i < 5; i++) {
        await tapOn(tester, find.byTooltip('Ayşe & Zeynep el sayısını artır'));
      }
      await save(tester);
      // Mehmet & Can 8 aldı, ihale 5 tuttu.
      expect((await onlyRound(db, id)).round.result.points, [5, 8]);
    });
  });

  for (final template in [GameTemplate.okey101, GameTemplate.batak]) {
    testApp('${template.name}: küçük ekran ve büyük yazıda taşma yok', (
      tester,
      db,
    ) async {
      final id = await createGame(
        db,
        template,
        template == GameTemplate.okey101
            ? const Okey101RuleSet()
            : const BatakRuleSet(),
        const [
          'Uzun İsimli Oyuncu 1',
          'Uzun İsimli Oyuncu 2',
          'Uzun İsimli Oyuncu 3',
          'Uzun İsimli Oyuncu 4',
        ],
      );
      await pumpApp(
        tester,
        db: db,
        location: AppRoutes.game(id),
        size: const Size(320, 568),
        textScale: 2,
      );
      await tester.tap(find.text('El Ekle'));
      await tester.pumpAndSettle();
      await tapOn(tester, inSheet('Uzun İsimli Oyuncu 2'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
