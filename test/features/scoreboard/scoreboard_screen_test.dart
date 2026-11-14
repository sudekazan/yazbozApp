import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/core/router/app_router.dart';
import 'package:yazboz/data/db/app_database.dart';
import 'package:yazboz/data/repositories/game_models.dart';
import 'package:yazboz/data/repositories/game_repository.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/rules/free_rules.dart';
import 'package:yazboz/domain/rules/okey101_rules.dart';

import '../../helpers.dart';

Future<int> freeGame(AppDatabase db, List<String> names, {int? target}) =>
    GameRepository(db).createGame(
      config: GameConfig(template: GameTemplate.free, seatCount: names.length),
      rules: FreeRuleSet(target: target),
      playerNames: names,
    );

Future<GameSnapshot> snapshotOf(AppDatabase db, int id) async =>
    (await GameRepository(db).loadGame(id) as GameLoaded).snapshot;

Future<void> openGame(
  WidgetTester tester,
  AppDatabase db,
  int id, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) => pumpApp(
  tester,
  db: db,
  location: AppRoutes.game(id),
  size: size,
  textScale: textScale,
);

Finder addRoundButton() => find.widgetWithText(FilledButton, 'El Ekle');

void main() {
  testApp('isimler, toplamlar ve eller görünür', (tester, db) async {
    final repo = GameRepository(db);
    final id = await freeGame(db, ['Ayşe', 'Mehmet'], target: 100);
    await repo.addRound(id, const FreeRoundInput([12, -5]));
    await repo.addRound(id, const FreeRoundInput([3, 40]));
    await openGame(tester, db, id);

    expect(find.text('Serbest'), findsOneWidget);
    expect(find.text('2 el · Hedef 100'), findsOneWidget);
    expect(find.text('Ayşe'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('35'), findsOneWidget);
    expect(find.text('−5'), findsOneWidget);
    expect(find.bySemanticsLabel('2. el: Ayşe 3, Mehmet 40'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Mehmet, toplam 35, önde')),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(addRoundButton()).onPressed, isNotNull);
  });

  testApp('hiç el yokken açıklama görünür', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await openGame(tester, db, id);
    expect(find.textContaining('Henüz el yok.'), findsOneWidget);
    expect(find.text('Henüz el yok'), findsOneWidget); // başlık altı
  });

  testApp('uzun basılan el onaydan sonra silinir, "Geri Al" ile döner', (
    tester,
    db,
  ) async {
    final repo = GameRepository(db);
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await repo.addRound(id, const FreeRoundInput([1, 2]));
    final second = await repo.addRound(id, const FreeRoundInput([7, 9]));
    await openGame(tester, db, id);

    await tester.longPress(find.byKey(ValueKey('round-$second')));
    await tester.pumpAndSettle();
    expect(find.text('2. el silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Eli Sil'));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('round-$second')), findsNothing);
    expect(find.text('2. el silindi'), findsOneWidget);
    expect((await snapshotOf(db, id)).rounds, hasLength(1));

    await tester.tap(find.text('Geri Al'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('round-$second')), findsOneWidget);
  });

  testApp('silme onayında vazgeçilirse el kalır', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    final round = await GameRepository(db)
        .addRound(id, const FreeRoundInput([1, 2]));
    await openGame(tester, db, id);

    await tester.longPress(find.byKey(ValueKey('round-$round')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect((await snapshotOf(db, id)).rounds, hasLength(1));
  });

  testApp('geri al son eli kaldırır', (tester, db) async {
    final repo = GameRepository(db);
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    final round = await repo.addRound(id, const FreeRoundInput([1, 2]));
    await openGame(tester, db, id);

    await tester.tap(find.byTooltip('Son işlemi geri al'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('round-$round')), findsNothing);
    final undo = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.undo),
    );
    expect(undo.onPressed, isNull);
  });

  testApp('isim düzenlenince not bırakmaz', (tester, db) async {
    final repo = GameRepository(db);
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await repo.addRound(id, const FreeRoundInput([1, 2]));
    await openGame(tester, db, id);

    await tester.tap(find.text('Ayşe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İsmi Düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('player-name')), 'Ayşen');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Ayşen'), findsOneWidget);
    expect(find.textContaining('elden itibaren'), findsNothing);
  });

  testApp('oyuncu değişince sütun sürer, tabloda not çıkar', (
    tester,
    db,
  ) async {
    final repo = GameRepository(db);
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await repo.addRound(id, const FreeRoundInput([4, 2]));
    await openGame(tester, db, id);

    await tester.longPress(find.text('Ayşe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oyuncuyu Değiştir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2. elden itibaren geçerli'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('player-name')), 'Elif');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Elif'), findsOneWidget);
    expect(find.text('2. elden itibaren: Ayşe → Elif'), findsOneWidget);
    expect(find.text('4'), findsNWidgets(2)); // toplam ve el puanı
  });

  testApp('boş isim kaydedilmez, hata çözüm söyler', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await openGame(tester, db, id);

    await tester.tap(find.text('Mehmet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İsmi Düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('player-name')), '   ');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('İsim boş kalamaz. Bir isim yaz.'), findsOneWidget);
    expect((await snapshotOf(db, id)).currentNames, ['Ayşe', 'Mehmet']);
  });

  testApp('dağıtıcı başka oyuncuya verilebilir', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet', 'Can']);
    await openGame(tester, db, id);
    expect(
      find.bySemanticsLabel(RegExp('Ayşe sıradaki eli dağıtacak')),
      findsOneWidget,
    );

    await tester.tap(find.text('Can'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dağıtıcı Yap'));
    await tester.pumpAndSettle();

    expect((await snapshotOf(db, id)).nextDealerSeat, 2);
    expect(
      find.bySemanticsLabel(RegExp('Can sıradaki eli dağıtacak')),
      findsOneWidget,
    );
  });

  testApp('ekran okuyucu sütunu açabilir ve eli silebilir', (tester, db) async {
    final semantics = tester.ensureSemantics();
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await GameRepository(db).addRound(id, const FreeRoundInput([1, 2]));
    await openGame(tester, db, id);

    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('^Ayşe, toplam 1'))),
      isSemantics(isButton: true, hasTapAction: true),
    );
    final round = tester
        .getSemantics(find.bySemanticsLabel('1. el: Ayşe 1, Mehmet 2'))
        .getSemanticsData();
    expect(round.hasAction(SemanticsAction.tap), isTrue);
    expect([
      for (final id in round.customSemanticsActionIds ?? <int>[])
        CustomSemanticsAction.getAction(id)?.label,
    ], contains('Eli Sil'));
    semantics.dispose();
  });

  testApp('menüden dağıtıcı göstergesi kapatılır', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await openGame(tester, db, id);

    await tester.tap(find.byTooltip('Oyun menüsü'));
    await tester.pumpAndSettle();
    // Onaylı menü öğesinde yazı dokunuşu almaz; öğenin kendisine dokunulur.
    await tester.tap(
      find.ancestor(
        of: find.text('Dağıtıcıyı Göster'),
        matching: find.byWidgetPredicate((w) => w is CheckedPopupMenuItem),
      ),
    );
    await tester.pumpAndSettle();

    expect((await snapshotOf(db, id)).dealerIndicator, isFalse);
    expect(find.byIcon(Icons.style_outlined), findsNothing);
  });

  testApp('yeniden başlatma kaç elin silineceğini sorar', (tester, db) async {
    final repo = GameRepository(db);
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await repo.addRound(id, const FreeRoundInput([1, 2]));
    await repo.addRound(id, const FreeRoundInput([3, 4]));
    await openGame(tester, db, id);

    await tester.tap(find.byTooltip('Oyun menüsü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeniden Başlat'));
    await tester.pumpAndSettle();
    expect(find.text('Bu oyundaki 2 el silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Elleri Sil'));
    await tester.pumpAndSettle();

    expect((await snapshotOf(db, id)).rounds, isEmpty);
    expect(find.textContaining('Henüz el yok.'), findsOneWidget);
  });

  testApp('kurallar salt okunur görünür', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet'], target: 50);
    await openGame(tester, db, id);

    await tester.tap(find.byTooltip('Oyun menüsü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kuralları Gör'));
    await tester.pumpAndSettle();

    expect(find.text('Kurallar'), findsOneWidget);
    expect(find.text('Hedef puan'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testApp('oyunu bitir onaydan sonra sonuç ekranını açar', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await GameRepository(db).addRound(id, const FreeRoundInput([1, 2]));
    await openGame(tester, db, id);

    await tester.tap(find.byTooltip('Oyun menüsü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oyunu Bitir'));
    await tester.pumpAndSettle();
    expect(find.text('Oyun bitirilsin mi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Oyunu Bitir'));
    await tester.pumpAndSettle();

    expect(find.text('Oyun Sonu'), findsOneWidget);
    expect((await snapshotOf(db, id)).isFinished, isTrue);
  });

  testApp('hedefe ulaşınca "El Ekle" yerine "Sonucu Gör" çıkar', (
    tester,
    db,
  ) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet'], target: 10);
    await GameRepository(db).addRound(id, const FreeRoundInput([12, 3]));
    await openGame(tester, db, id);

    expect(addRoundButton(), findsNothing);
    await tester.tap(find.text('Sonucu Gör'));
    await tester.pumpAndSettle();
    expect(find.text('Oyun Sonu'), findsOneWidget);
  });

  testApp('biten oyunun tablosu salt okunur', (tester, db) async {
    final repo = GameRepository(db);
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    final round = await repo.addRound(id, const FreeRoundInput([1, 2]));
    await repo.finishGame(id);
    await openGame(tester, db, id);

    expect(find.text('Oyun bitti · 1 el'), findsOneWidget);
    expect(find.byTooltip('Son işlemi geri al'), findsNothing);
    expect(find.text('Sonucu Gör'), findsOneWidget);

    await tester.longPress(find.byKey(ValueKey('round-$round')));
    await tester.pumpAndSettle();
    expect(find.text('1. el silinsin mi?'), findsNothing);

    await tester.tap(find.text('Ayşe'));
    await tester.pumpAndSettle();
    expect(find.text('İsmi Düzenle'), findsNothing);
  });

  testApp('eşli 101\'de takım toplamı ve çarpan görünür', (tester, db) async {
    final repo = GameRepository(db);
    final id = await repo.createGame(
      config: const GameConfig(
        template: GameTemplate.okey101,
        seatCount: 4,
        playMode: PlayMode.pairs,
      ),
      rules: const Okey101RuleSet(),
      playerNames: const ['Ayşe', 'Mehmet', 'Zeynep', 'Can'],
    );
    await repo.addRound(
      id,
      const Okey101RoundInput(
        finisherSeat: 1,
        withOkey: true,
        players: [
          Okey101Player(state: Okey101PlayerState.opened, remaining: 10),
          Okey101Player(state: Okey101PlayerState.opened),
          Okey101Player(state: Okey101PlayerState.opened, remaining: 5),
          Okey101Player(state: Okey101PlayerState.opened, remaining: 7),
        ],
      ),
    );
    await openGame(tester, db, id);

    expect(find.text('101 Okey · Eşli'), findsOneWidget);
    expect(find.text('1/9 el · 8 el kaldı'), findsOneWidget);
    expect(find.text('x2'), findsOneWidget);
    expect(find.text('Ayşe & Zeynep'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Mehmet & Can, takım toplamı .*, önde')),
      findsOneWidget,
    );
  });

  testApp('olmayan oyun çökmez, çıkış yolu gösterir', (tester, db) async {
    await openGame(tester, db, 99);
    expect(find.textContaining('Bu oyun bulunamadı'), findsOneWidget);
    await tester.tap(find.text('Ana Sayfaya Dön'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni Oyun Kur'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testApp('8 kişi, küçük ekran ve büyük yazıda taşma yok '
        '(${dark ? 'koyu' : 'açık'})', (tester, db) async {
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final repo = GameRepository(db);
      final id = await freeGame(db, [
        for (var i = 1; i <= 8; i++) 'Uzun İsimli Oyuncu $i',
      ]);
      for (var i = 0; i < 12; i++) {
        await repo.addRound(
          id,
          const FreeRoundInput([
            -99999,
            99999,
            -1234,
            5678,
            0,
            -1,
            12345,
            -99999,
          ]),
        );
      }
      await repo.replacePlayer(id, 3, 'Yeni Gelen Oyuncu 4');
      await openGame(tester, db, id, size: const Size(320, 568), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }
}
