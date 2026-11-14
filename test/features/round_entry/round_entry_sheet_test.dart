import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/core/router/app_router.dart';
import 'package:yazboz/data/db/app_database.dart';
import 'package:yazboz/data/repositories/game_models.dart';
import 'package:yazboz/data/repositories/game_repository.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/rules/free_rules.dart';

import '../../helpers.dart';

Future<int> freeGame(AppDatabase db, List<String> names, {int? target}) =>
    GameRepository(db).createGame(
      config: GameConfig(template: GameTemplate.free, seatCount: names.length),
      rules: FreeRuleSet(target: target),
      playerNames: names,
    );

Future<GameSnapshot> snapshotOf(AppDatabase db, int id) async =>
    (await GameRepository(db).loadGame(id) as GameLoaded).snapshot;

/// Tuş takımında sırayla basar: rakamlar, "-" eksi, "v" sonraki, "^" önceki,
/// "<" sil.
Future<void> press(WidgetTester tester, String keys) async {
  for (final key in keys.split('')) {
    final finder = switch (key) {
      '-' => find.bySemanticsLabel('Eksi'),
      'v' => find.byTooltip('Sonraki oyuncuya geç'),
      '^' => find.byTooltip('Önceki oyuncuya geç'),
      '<' => find.byTooltip('Son rakamı sil'),
      _ => find.descendant(
        of: find.bySemanticsLabel('Sayı tuşları'),
        matching: find.text(key),
      ),
    };
    await tester.tap(finder);
    await tester.pump();
  }
}

Future<void> openEntry(WidgetTester tester) async {
  await tester.tap(find.text('El Ekle'));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
  await tester.pumpAndSettle();
}

void main() {
  testApp('puanlar tuş takımıyla girilip kaydedilir', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet', 'Can']);
    await pumpApp(tester, db: db, location: AppRoutes.game(id));
    await openEntry(tester);

    expect(find.text('1. el'), findsOneWidget);
    await press(tester, '12v-5');
    expect(find.text('Yeni toplam 12'), findsOneWidget);
    expect(find.text('Yeni toplam −5'), findsOneWidget);
    await save(tester);

    final game = await snapshotOf(db, id);
    expect(game.rounds.single.round.result.points, [12, -5, 0]);
    expect(find.text('1. el'), findsNothing);
    expect(
      find.bySemanticsLabel('1. el: Ayşe 12, Mehmet −5, Can 0'),
      findsOneWidget,
    );
  });

  testApp('önceki oyuncuya dönülüp düzeltilebilir', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await pumpApp(tester, db: db, location: AppRoutes.game(id));
    await openEntry(tester);

    await press(tester, '9v3^<4');
    await save(tester);
    expect((await snapshotOf(db, id)).rounds.single.round.result.points, [
      4,
      3,
    ]);
  });

  testApp('oyuncu satırına dokununca o alana geçilir', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await pumpApp(tester, db: db, location: AppRoutes.game(id));
    await openEntry(tester);

    await tester.tap(find.text('Mehmet').last);
    await tester.pump();
    await press(tester, '7');
    await save(tester);
    expect((await snapshotOf(db, id)).rounds.single.round.result.points, [
      0,
      7,
    ]);
  });

  testApp('kapatınca el kaydedilmez', (tester, db) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await pumpApp(tester, db: db, location: AppRoutes.game(id));
    await openEntry(tester);

    await press(tester, '5');
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    expect((await snapshotOf(db, id)).rounds, isEmpty);
  });

  testApp('ele dokununca kayıtlı puanlarla düzenleme açılır', (
    tester,
    db,
  ) async {
    final repo = GameRepository(db);
    final id = await freeGame(db, ['Ayşe', 'Mehmet']);
    await repo.addRound(id, const FreeRoundInput([1, 2]));
    final second = await repo.addRound(id, const FreeRoundInput([10, -4]));
    await pumpApp(tester, db: db, location: AppRoutes.game(id));

    await tester.tap(find.byKey(ValueKey('round-$second')));
    await tester.pumpAndSettle();
    expect(find.text('2. el'), findsOneWidget);
    // Önizleme bu eli saymadan toplar: 1 + 10.
    expect(find.text('Yeni toplam 11'), findsOneWidget);

    await press(tester, '<5');
    await save(tester);
    final game = await snapshotOf(db, id);
    expect(game.rounds.map((r) => r.round.result.points.join(' ')), [
      '1 2',
      '15 -4',
    ]);
  });

  testApp('hedefe ulaşan el kaydedilince sonuç ekranı açılır', (
    tester,
    db,
  ) async {
    final id = await freeGame(db, ['Ayşe', 'Mehmet'], target: 50);
    await pumpApp(tester, db: db, location: AppRoutes.game(id));
    await openEntry(tester);

    await press(tester, '60');
    await save(tester);
    expect(find.text('Oyun Sonu'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testApp('8 kişi, küçük ekran ve büyük yazıda taşma yok '
        '(${dark ? 'koyu' : 'açık'})', (tester, db) async {
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final id = await freeGame(db, [
        for (var i = 1; i <= 8; i++) 'Uzun İsimli Oyuncu $i',
      ]);
      await pumpApp(
        tester,
        db: db,
        location: AppRoutes.game(id),
        size: const Size(320, 568),
        textScale: 2,
      );
      await openEntry(tester);
      // Son oyuncuya kadar ilerle; odaktaki satır görünür kalmalı.
      await press(tester, '-99999vvvvvvv12345');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('12345'), findsOneWidget);
      await save(tester);
      final points = (await snapshotOf(db, id)).rounds.single.round.result;
      expect(points.points.first, -99999);
      expect(points.points.last, 12345);
    });
  }
}
