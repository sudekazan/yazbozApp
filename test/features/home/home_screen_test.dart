import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/data/db/app_database.dart';
import 'package:yazboz/data/repositories/game_repository.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/rules/free_rules.dart';
import 'package:yazboz/domain/rules/okey101_rules.dart';
import 'package:yazboz/domain/rules/pisti_rules.dart';

import '../../helpers.dart';

Future<int> freeGame(AppDatabase db, List<String> names) =>
    GameRepository(db).createGame(
      config: GameConfig(template: GameTemplate.free, seatCount: names.length),
      rules: const FreeRuleSet(target: 50),
      playerNames: names,
    );

void main() {
  testApp('hiç oyun yokken kısa açıklama ve kurma butonu görünür', (
    tester,
    db,
  ) async {
    await pumpApp(tester, db: db);
    expect(find.textContaining('Henüz oyun yok'), findsOneWidget);
    expect(find.text('Yeni Oyun Kur'), findsOneWidget);
    expect(find.text('Devam Eden Oyunlar'), findsNothing);
  });

  testApp('devam eden ve biten oyunlar ayrı bölümlerde listelenir', (
    tester,
    db,
  ) async {
    final repo = GameRepository(db);
    final ongoing = await freeGame(db, ['Ayşe', 'Mehmet', 'Can']);
    await repo.addRound(ongoing, const FreeRoundInput([5, 3, 1]));
    final done = await freeGame(db, ['Elif', 'Kaan']);
    await repo.addRound(done, const FreeRoundInput([60, 10]));
    await repo.finishGame(done);
    await repo.createGame(
      config: const GameConfig(template: GameTemplate.okey101, seatCount: 4),
      rules: const Okey101RuleSet(),
      playerNames: const ['A', 'B', 'C', 'D'],
    );
    await pumpApp(tester, db: db);

    expect(find.text('Devam Eden Oyunlar'), findsOneWidget);
    expect(find.text('Biten Oyunlar'), findsOneWidget);
    expect(find.text('Ayşe, Mehmet, Can · 1 el'), findsOneWidget);
    expect(find.text('Kazanan: Elif'), findsOneWidget);
    expect(find.text('A, B, C, D · 0/9 el'), findsOneWidget);
  });

  testApp('eşli oyunda takımlar yan yana yazılır', (tester, db) async {
    await GameRepository(db).createGame(
      config: const GameConfig(
        template: GameTemplate.pisti,
        seatCount: 4,
        playMode: PlayMode.pairs,
      ),
      rules: const PistiRuleSet(),
      playerNames: const ['Ayşe', 'Mehmet', 'Zeynep', 'Can'],
    );
    await pumpApp(tester, db: db);
    expect(find.text('Pişti · Eşli'), findsOneWidget);
    expect(find.textContaining('Ayşe & Zeynep – Mehmet & Can'), findsOneWidget);
  });

  testApp('oyuna dokununca skor tablosu açılır', (tester, db) async {
    await freeGame(db, ['Ayşe', 'Mehmet']);
    await pumpApp(tester, db: db);
    await tester.tap(find.text('Serbest'));
    await tester.pumpAndSettle();
    expect(find.text('El Ekle'), findsOneWidget);
  });

  testApp('kaydırarak silinen oyun "Geri Al" ile döner', (tester, db) async {
    await freeGame(db, ['Ayşe', 'Mehmet']);
    await pumpApp(tester, db: db);

    await tester.drag(find.text('Serbest'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Serbest oyunu silindi'), findsOneWidget);
    expect(find.text('Ayşe, Mehmet · Henüz el yok'), findsNothing);

    await tester.tap(find.text('Geri Al'));
    await tester.pumpAndSettle();
    expect(find.text('Ayşe, Mehmet · Henüz el yok'), findsOneWidget);
    expect(await db.select(db.games).get(), hasLength(1));
  });

  testApp('bildirim kapanınca silinen oyun kalıcı silinir', (tester, db) async {
    await freeGame(db, ['Ayşe', 'Mehmet']);
    await pumpApp(tester, db: db);

    await tester.drag(find.text('Serbest'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(await db.select(db.games).get(), isEmpty);
  });

  testApp('bozuk kayıtlı oyun açılamadı olarak görünür', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await (db.update(db.games)..where((g) => g.id.equals(id))).write(
      const GamesCompanion(rulesJson: Value('{bozuk')),
    );
    await pumpApp(tester, db: db);
    expect(find.text('Bu oyun açılamadı'), findsOneWidget);
    expect(find.textContaining('Kaydırarak silebilirsin'), findsOneWidget);
  });

  testApp('küçük ekranda büyük yazıyla taşma olmaz', (tester, db) async {
    await freeGame(db, ['Ayşegül', 'Mehmet Ali', 'Zeynep', 'Can']);
    await freeGame(db, ['Elif', 'Kaan']);
    await pumpApp(tester, db: db, size: const Size(375, 667), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Yeni Oyun Kur'), findsOneWidget);
  });

  testApp('ayarlar ikonunun ekran okuyucu etiketi vardır', (tester, db) async {
    await pumpApp(tester, db: db);
    expect(find.byTooltip('Ayarlar'), findsOneWidget);
  });
}
