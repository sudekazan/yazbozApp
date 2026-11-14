import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/core/router/app_router.dart';
import 'package:yazboz/data/repositories/group_repository.dart';
import 'package:yazboz/data/repositories/settings_repository.dart';

import '../../helpers.dart';

/// drift akışını gerçek zamanda okur; sahte saatte `await` takılır.
Future<List<PlayerGroup>> readGroups(
  WidgetTester tester,
  GroupRepository groups,
) async => (await tester.runAsync(() => groups.watchGroups().first))!;

void main() {
  testApp('ayarlar varsayılan değerlerle açılır', (tester, db) async {
    await pumpApp(tester, db: db, location: AppRoutes.settings);
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Ekranı açık tut'),
          )
          .value,
      isTrue,
    );
    expect(find.textContaining('Henüz kayıtlı grup yok'), findsOneWidget);
  });

  testApp('tema değişince kaydedilir ve uygulanır', (tester, db) async {
    await pumpApp(tester, db: db, location: AppRoutes.settings);
    await tester.tap(find.text('Koyu'));
    await tester.pumpAndSettle();

    expect((await SettingsRepository(db).load()).themeMode, AppThemeMode.dark);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testApp('anahtarlar kaydedilir', (tester, db) async {
    await pumpApp(tester, db: db, location: AppRoutes.settings);
    for (final label in [
      'Ekranı açık tut',
      'Titreşim',
      'Dağıtıcı göstergesi',
    ]) {
      await tester.tap(find.widgetWithText(SwitchListTile, label));
      await tester.pumpAndSettle();
    }
    final saved = await SettingsRepository(db).load();
    expect(saved.keepScreenOn, isFalse);
    expect(saved.haptics, isFalse);
    expect(saved.dealerIndicatorDefault, isFalse);
  });

  testApp('kayıtlı grup düzenlenir: ad, sıra ve oyuncu', (tester, db) async {
    final groups = GroupRepository(db);
    final id = await groups.createGroup('Ailem', ['Ayşe', 'Mehmet']);
    await pumpApp(tester, db: db, location: AppRoutes.settings);

    await tester.tap(find.text('Ailem'));
    await tester.pumpAndSettle();
    expect(find.text('Grubu Düzenle'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('group-name')), 'Aile');
    await tester.tap(find.text('Oyuncu Ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '3. oyuncunun adı'),
      'Can',
    );
    await tester.tap(find.byTooltip('Ayşe adını gruptan çıkar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final saved = (await readGroups(tester, groups)).single;
    expect(saved.id, id);
    expect(saved.name, 'Aile');
    expect(saved.members, ['Mehmet', 'Can']);
  });

  testApp('boş isimle grup kaydedilmez, hata çözüm söyler', (tester, db) async {
    final groups = GroupRepository(db);
    await groups.createGroup('Ailem', ['Ayşe', 'Mehmet']);
    await pumpApp(tester, db: db, location: AppRoutes.settings);

    await tester.tap(find.text('Ailem'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '1. oyuncunun adı'),
      ' ',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('İsim boş kalamaz. Bir isim yaz.'), findsOneWidget);
    expect((await readGroups(tester, groups)).single.members, [
      'Ayşe',
      'Mehmet',
    ]);
  });

  testApp('grup silmeden önce sorar, "Geri Al" ile döner', (tester, db) async {
    final groups = GroupRepository(db);
    await groups.createGroup('Ailem', ['Ayşe', 'Mehmet']);
    await pumpApp(tester, db: db, location: AppRoutes.settings);

    await tester.tap(find.byTooltip('Ailem grubunu sil'));
    await tester.pumpAndSettle();
    expect(find.text('Ailem grubu silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Grubu Sil'));
    await tester.pumpAndSettle();
    expect(await readGroups(tester, groups), isEmpty);

    await tester.tap(find.text('Geri Al'));
    await tester.pumpAndSettle();
    final back = (await readGroups(tester, groups)).single;
    expect((back.name, back.members.join(' ')), ('Ailem', 'Ayşe Mehmet'));
  });

  testApp('hakkında diyaloğu açılır', (tester, db) async {
    await pumpApp(tester, db: db, location: AppRoutes.settings);
    await tester.ensureVisible(find.text('Hakkında'));
    await tester.tap(find.text('Hakkında'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tüm veriler bu cihazda kalır'), findsOneWidget);
  });

  testApp('küçük ekran ve büyük yazıda taşma yok', (tester, db) async {
    await GroupRepository(db).createGroup('Uzun Adlı Bir Grup', [
      for (var i = 1; i <= 8; i++) 'Uzun İsimli Oyuncu $i',
    ]);
    await pumpApp(
      tester,
      db: db,
      location: AppRoutes.settings,
      size: const Size(320, 568),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Uzun Adlı Bir Grup'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Uzun Adlı Bir Grup'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
