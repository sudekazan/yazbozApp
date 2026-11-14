import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/core/router/app_router.dart';
import 'package:yazboz/data/db/app_database.dart';
import 'package:yazboz/data/repositories/game_models.dart';
import 'package:yazboz/data/repositories/game_repository.dart';
import 'package:yazboz/data/repositories/group_repository.dart';
import 'package:yazboz/data/repositories/settings_repository.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/rules/free_rules.dart';

import '../../helpers.dart';

Future<void> openSetup(
  WidgetTester tester,
  AppDatabase db,
  GameTemplate template, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) => pumpApp(
  tester,
  db: db,
  location: AppRoutes.setup(template.name),
  size: size,
  textScale: textScale,
);

Finder nameField(int seat) => find.byKey(ValueKey('player-name-$seat'));

Future<void> start(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Oyunu Başlat'));
  await tester.tap(find.text('Oyunu Başlat'));
  await tester.pumpAndSettle();
}

/// Kurulan tek oyunun hali.
Future<GameSnapshot> createdGame(AppDatabase db) async {
  final id = (await db.select(db.games).getSingle()).id;
  return ((await GameRepository(db).loadGame(id)) as GameLoaded).snapshot;
}

void main() {
  group('Serbest kurulum', () {
    testApp('varsayılan isimlerle başlatılır ve tablo açılır', (
      tester,
      db,
    ) async {
      await openSetup(tester, db, GameTemplate.free);
      expect(find.byType(TextField), findsNWidgets(5)); // 4 isim + hedef
      await start(tester);

      expect(find.text('El Ekle'), findsOneWidget);
      final game = await createdGame(db);
      expect(game.currentNames, [
        'Oyuncu 1',
        'Oyuncu 2',
        'Oyuncu 3',
        'Oyuncu 4',
      ]);
      expect(game.nextDealerSeat, 0);
      expect(game.rules.toJson(), const FreeRuleSet().toJson());
    });

    testApp('kişi sayısı değişince girilen isimler korunur', (
      tester,
      db,
    ) async {
      await openSetup(tester, db, GameTemplate.free);
      await tester.enterText(nameField(0), 'Ayşe');
      await tester.tap(find.byTooltip('Kişi sayısını artır'));
      await tester.pumpAndSettle();
      expect(nameField(4), findsOneWidget);
      await start(tester);
      final game = await createdGame(db);
      expect(game.config.seatCount, 5);
      expect(game.currentNames.first, 'Ayşe');
    });

    testApp('boş isimle başlatılamaz, hata çözüm söyler', (tester, db) async {
      await openSetup(tester, db, GameTemplate.free);
      await tester.enterText(nameField(1), '   ');
      await start(tester);
      expect(find.text('İsim boş kalamaz. Bir isim yaz.'), findsOneWidget);
      expect(await db.select(db.games).get(), isEmpty);
    });

    testApp('hatalı isim alanına odaklanılır', (tester, db) async {
      await openSetup(tester, db, GameTemplate.free);
      await tester.enterText(nameField(1), '');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await start(tester);
      expect(tester.widget<TextField>(nameField(1)).focusNode!.hasFocus, true);
    });

    testApp('Oyunu Başlat iki kez basılsa da tek oyun açılır', (
      tester,
      db,
    ) async {
      await openSetup(tester, db, GameTemplate.free);
      await tester.tap(find.text('Oyunu Başlat'));
      await tester.tap(find.text('Oyunu Başlat'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(await db.select(db.games).get(), hasLength(1));
    });

    testApp('hedef ve kazanma yönü kurallara yazılır', (tester, db) async {
      await openSetup(tester, db, GameTemplate.free);
      await tester.tap(find.text('En düşük'));
      await tester.enterText(find.byKey(const ValueKey('target')), '100');
      await start(tester);
      final rules = (await createdGame(db)).rules as FreeRuleSet;
      expect((rules.winDirection, rules.target), (WinDirection.lowest, 100));
    });

    testApp('ilk dağıtıcı dokunarak seçilir', (tester, db) async {
      await openSetup(tester, db, GameTemplate.free);
      await tester.tap(find.byTooltip('Oyuncu 3 ilk dağıtsın'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('İlk dağıtan: Oyuncu 3'), findsOneWidget);
      await start(tester);
      expect((await createdGame(db)).nextDealerSeat, 2);
    });

    testApp('oyuncular tutamaçtan sürüklenerek sıralanır', (tester, db) async {
      await openSetup(tester, db, GameTemplate.free);
      await tester.enterText(nameField(0), 'Ayşe');
      await tester.pumpAndSettle();
      final handle = find.byKey(const ValueKey('player-handle-0'));
      final rowHeight = tester.getSize(nameField(0)).height;
      await tester.timedDrag(
        handle,
        Offset(0, rowHeight * 1.8),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();
      await start(tester);
      expect((await createdGame(db)).currentNames.take(2), [
        'Oyuncu 2',
        'Ayşe',
      ]);
    });

    testApp('ayarda dağıtıcı göstergesi kapalıysa oyun da kapalı başlar', (
      tester,
      db,
    ) async {
      await SettingsRepository(db)
          .save(const AppSettingsData(dealerIndicatorDefault: false));
      await openSetup(tester, db, GameTemplate.free);
      await start(tester);
      expect((await createdGame(db)).dealerIndicator, isFalse);
    });
  });

  group('Gruplar ve öneriler', () {
    testApp('gruba dokununca kişi sayısı ve isimler dolar', (tester, db) async {
      await GroupRepository(db).createGroup('Ailem', ['Ayşe', 'Mehmet', 'Can']);
      await openSetup(tester, db, GameTemplate.free);
      await tester.tap(find.text('Ailem'));
      await tester.pumpAndSettle();
      await start(tester);
      expect((await createdGame(db)).currentNames, ['Ayşe', 'Mehmet', 'Can']);
    });

    testApp('4 kişilik grup Piştide eşli oyuna geçirir', (tester, db) async {
      await GroupRepository(db).createGroup('Kuzenler', ['A', 'B', 'C', 'D']);
      await openSetup(tester, db, GameTemplate.pisti);
      await tester.tap(find.text('Kuzenler'));
      await tester.pumpAndSettle();
      expect(
        find.text('Karşılıklı oturanlar eş.', findRichText: true),
        findsOneWidget,
      );
      await start(tester);
      final game = await createdGame(db);
      expect(game.config.playMode, PlayMode.pairs);
      expect(game.currentNames, ['A', 'B', 'C', 'D']);
    });

    testApp('uymayan grupta oynanabilen kişi sayısı söylenir', (
      tester,
      db,
    ) async {
      await GroupRepository(db).createGroup('Üçlü', ['A', 'B', 'C']);
      await openSetup(tester, db, GameTemplate.pisti);
      await tester.tap(find.text('Üçlü'));
      await tester.pump();
      expect(
        find.text(
          'Üçlü grubunda 3 kişi var; bu oyun 2 ya da 4 kişiyle oynanır.',
        ),
        findsOneWidget,
      );
    });

    testApp('isimler grup olarak kaydedilir', (tester, db) async {
      await openSetup(tester, db, GameTemplate.free);
      expect(find.text('Grup Olarak Kaydet'), findsNothing);
      await tester.enterText(nameField(0), 'Ayşe');
      await tester.pump();
      await tester.ensureVisible(find.text('Grup Olarak Kaydet'));
      await tester.tap(find.text('Grup Olarak Kaydet'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byKey(const ValueKey('group-name')), 'Cuma');
      await tester.tap(find.text('Kaydet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Cuma grubu kaydedildi'), findsOneWidget);
      final group = await db.select(db.playerGroups).getSingle();
      expect(group.name, 'Cuma');
      expect(group.membersJson, startsWith('["Ayşe"'));
    });

    testApp('daha önce kullanılan isim öneriden seçilir', (tester, db) async {
      await GameRepository(db).createGame(
        config: const GameConfig(template: GameTemplate.free, seatCount: 2),
        rules: const FreeRuleSet(),
        playerNames: const ['Elif', 'Kaan'],
      );
      await openSetup(tester, db, GameTemplate.free);
      await tester.tap(nameField(2));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Elif'));
      await tester.pumpAndSettle();
      await start(tester);
      final id = (await db.select(db.games).get()).last.id;
      final game =
          ((await GameRepository(db).loadGame(id)) as GameLoaded).snapshot;
      expect(game.currentNames[2], 'Elif');
    });

    testApp('ikinci öneri sonraki varsayılan isimli alana yazılır', (
      tester,
      db,
    ) async {
      await GameRepository(db).createGame(
        config: const GameConfig(template: GameTemplate.free, seatCount: 2),
        rules: const FreeRuleSet(),
        playerNames: const ['Elif', 'Kaan'],
      );
      await openSetup(tester, db, GameTemplate.free);
      await tester.tap(nameField(2));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Elif'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Kaan'));
      await tester.pumpAndSettle();
      await start(tester);
      final id = (await db.select(db.games).get()).last.id;
      final game =
          ((await GameRepository(db).loadGame(id)) as GameLoaded).snapshot;
      expect(game.currentNames, ['Oyuncu 1', 'Oyuncu 2', 'Elif', 'Kaan']);
    });
  });

  group('Şablona özel seçenekler', () {
    testApp('Tavlada dağıtıcı seçilmez, hedef seçenekten gelir', (
      tester,
      db,
    ) async {
      await openSetup(tester, db, GameTemplate.tavla);
      expect(find.byTooltip('Oyuncu 2 ilk dağıtsın'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, '7'));
      await start(tester);
      expect((await createdGame(db)).rules.toJson()['target'], 7);
    });

    testApp('Batakta hedef puanla oynanırken hedef zorunlu', (
      tester,
      db,
    ) async {
      await openSetup(tester, db, GameTemplate.batak);
      await tester.scrollUntilVisible(
        find.text('Hedef puan'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Hedef puan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hedef puan'));
      await tester.pumpAndSettle();
      await start(tester);
      expect(find.text('Hedef puanı gir.'), findsOneWidget);
      expect(await db.select(db.games).get(), isEmpty);

      await tester.enterText(find.byKey(const ValueKey('target')), '51');
      await start(tester);
      final json = (await createdGame(db)).rules.toJson();
      expect((json['length'], json['target']), ('target', 51));
    });

    testApp('kurallar düzenlenir, geçersiz değer engellenir', (
      tester,
      db,
    ) async {
      await openSetup(tester, db, GameTemplate.okey);
      await tester.tap(find.text('Kurallar'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('rule-startingPoints'));
      await tester.ensureVisible(field);
      await tester.enterText(field, '0');
      await tester.pumpAndSettle();
      expect(find.text('1 ile 99.999 arasında bir sayı gir.'), findsOneWidget);
      await start(tester);
      expect(await db.select(db.games).get(), isEmpty);

      await tester.enterText(field, '15');
      await start(tester);
      expect((await createdGame(db)).rules.toJson()['startingPoints'], 15);
    });
  });

  testApp('küçük ekranda büyük yazıyla taşma olmaz', (tester, db) async {
    await openSetup(
      tester,
      db,
      GameTemplate.batak,
      size: const Size(375, 667),
      textScale: 2,
    );
    await tester.tap(find.text('Eşli'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
