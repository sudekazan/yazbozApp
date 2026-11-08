import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/core/router/app_router.dart';
import 'package:yazboz/data/db/app_database.dart';
import 'package:yazboz/data/repositories/game_models.dart';
import 'package:yazboz/data/repositories/game_repository.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/rules/free_rules.dart';
import 'package:yazboz/domain/rules/okey101_rules.dart';

import '../../helpers.dart';

Future<int> freeGame(
  AppDatabase db,
  List<String> names, {
  int? target = 50,
  WinDirection direction = WinDirection.highest,
}) => GameRepository(db).createGame(
  config: GameConfig(template: GameTemplate.free, seatCount: names.length),
  rules: FreeRuleSet(target: target, winDirection: direction),
  playerNames: names,
);

Future<GameSnapshot> snapshotOf(AppDatabase db, int id) async =>
    (await GameRepository(db).loadGame(id) as GameLoaded).snapshot;

Future<void> openResult(
  WidgetTester tester,
  AppDatabase db,
  int id, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) => pumpApp(
  tester,
  db: db,
  location: AppRoutes.gameOver(id),
  size: size,
  textScale: textScale,
);

void main() {
  testApp('kazanan, özet ve final sıralaması görünür', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet', 'Can']);
    await GameRepository(db).addRound(id, const FreeRoundInput([20, 60, 5]));
    await openResult(tester, db, id);
    expect(find.text('Kazanan'), findsOneWidget);
    expect(find.text('Mehmet'), findsNWidgets(2)); // başlık ve sıralama
    expect(find.text('60 puan · Serbest · 1 el'), findsOneWidget);
    expect(find.bySemanticsLabel('1. Mehmet, 60 puan'), findsOneWidget);
    expect(find.bySemanticsLabel('2. Ayşe, 20 puan'), findsOneWidget);
    expect(find.bySemanticsLabel('3. Can, 5 puan'), findsOneWidget);
  });

  testApp('eşit kazananlar birlikte yazılır', (tester, db) async {
    final id = await freeGame(
      db,
      ['Ayşe', 'Mehmet', 'Can'],
      target: 10,
      direction: WinDirection.lowest,
    );
    await GameRepository(db).addRound(id, const FreeRoundInput([12, 5, 5]));
    await openResult(tester, db, id);

    expect(find.text('Kazananlar'), findsOneWidget);
    expect(find.text('Mehmet, Can'), findsOneWidget);
  });

  testApp('oyuncu değişikliği sıralamada not olarak görünür', (
    tester,
    db,
  ) async {
    final repo = GameRepository(db);
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await repo.addRound(id, const FreeRoundInput([10, 5]));
    await repo.replacePlayer(id, 0, 'Elif');
    await repo.addRound(id, const FreeRoundInput([45, 5]));
    await openResult(tester, db, id);

    expect(find.text('Elif'), findsNWidgets(2));
    expect(find.text('2. elden itibaren Ayşe yerine'), findsOneWidget);
  });

  testApp('eşli oyunda takımlar sıralanır', (tester, db) async {
    final repo = GameRepository(db);
    final id = await repo.createGame(
      config: const GameConfig(
        template: GameTemplate.okey101,
        seatCount: 4,
        playMode: PlayMode.pairs,
      ),
      rules: const Okey101RuleSet(rounds: 1),
      playerNames: const ['Ayşe', 'Mehmet', 'Zeynep', 'Can'],
    );
    await repo.addRound(
      id,
      const Okey101RoundInput(
        finisherSeat: 1,
        players: [
          Okey101Player(state: Okey101PlayerState.opened, remaining: 10),
          Okey101Player(state: Okey101PlayerState.opened),
          Okey101Player(state: Okey101PlayerState.opened, remaining: 20),
          Okey101Player(state: Okey101PlayerState.opened),
        ],
      ),
    );
    await openResult(tester, db, id);

    expect(find.text('Mehmet & Can'), findsNWidgets(2));
    expect(find.bySemanticsLabel('2. Ayşe & Zeynep, 30 puan'), findsOneWidget);
  });

  testApp('rövanş aynı oyuncularla yeni oyun açar, eskisi biter', (
    tester,
    db,
  ) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await GameRepository(db).addRound(id, const FreeRoundInput([60, 5]));
    await openResult(tester, db, id);

    await tester.tap(find.text('Rövanş Yap'));
    await tester.pumpAndSettle();

    expect(find.text('El Ekle'), findsOneWidget);
    expect(find.text('Henüz el yok · Hedef 50'), findsOneWidget);
    expect((await snapshotOf(db, id)).isFinished, isTrue);
    final next = await snapshotOf(db, id + 1);
    expect(next.currentNames, ['Ayşe', 'Mehmet']);
    // İlk dağıtan, eski oyunda sıradaki dağıtandır.
    expect(next.firstDealerSeat, 1);
  });

  testApp('ana sayfaya dönünce oyun biter', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await GameRepository(db).addRound(id, const FreeRoundInput([60, 5]));
    await openResult(tester, db, id);

    await tester.tap(find.text('Ana Sayfaya Dön'));
    await tester.pumpAndSettle();

    expect(find.text('Biten Oyunlar'), findsOneWidget);
    expect((await snapshotOf(db, id)).isFinished, isTrue);
  });

  testApp('geri tuşu tabloya döner, son el düzeltilebilir', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await GameRepository(db).addRound(id, const FreeRoundInput([60, 5]));
    await openResult(tester, db, id);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Sonucu Gör'), findsOneWidget);
    expect(find.byTooltip('Son işlemi geri al'), findsOneWidget);
    expect((await snapshotOf(db, id)).isFinished, isFalse);
  });

  testApp('bitmemiş oyunda tabloya dönme yolu gösterilir', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await openResult(tester, db, id);

    expect(find.textContaining('henüz bitmedi'), findsOneWidget);
    await tester.tap(find.text('Tabloya Dön'));
    await tester.pumpAndSettle();
    expect(find.text('El Ekle'), findsOneWidget);
  });

  testApp('küçük ekran ve büyük yazıda taşma yok', (tester, db) async {
    final names = [for (var i = 1; i <= 8; i++) 'Uzun İsimli Oyuncu $i'];
    final id = await freeGame(db, names, target: 10);
    await GameRepository(db)
        .addRound(id, const FreeRoundInput([99999, 1, 2, 3, 4, 5, 6, -99999]));
    await openResult(tester, db, id, size: const Size(320, 568), textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
