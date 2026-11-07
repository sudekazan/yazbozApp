import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/core/router/app_router.dart';
import 'package:yazboz/data/db/app_database.dart';

import '../../helpers.dart';

Future<void> openApp(WidgetTester tester, AppDatabase db, {String? at}) =>
    pumpApp(tester, db: db, location: at ?? AppRoutes.home);

void main() {
  testApp('Ana sayfadan oyun seçimine gidilir, geri tuşu ana sayfaya döner', (
    tester,
    db,
  ) async {
    await openApp(tester, db);
    await tester.tap(find.text('Yeni Oyun Kur'));
    await tester.pumpAndSettle();
    expect(find.text('Oyun Seç'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Yeni Oyun Kur'), findsOneWidget);
  });

  testApp('Ayarlar ikonu ayarlar ekranını açar ve etiketi vardır', (
    tester,
    db,
  ) async {
    await openApp(tester, db);
    final settings = find.byTooltip('Ayarlar');
    expect(settings, findsOneWidget);

    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Ayarlar'), findsOneWidget);
  });

  final screens = {
    AppRoutes.setup('okey'): 'Oyun Kurulumu',
    AppRoutes.game(3): 'Skor Tablosu',
    AppRoutes.gameOver(3): 'Oyun Sonu',
  };
  for (final MapEntry(key: location, value: title) in screens.entries) {
    testApp('$location adresi "$title" ekranını açar', (tester, db) async {
      await openApp(tester, db, at: location);
      expect(find.text(title), findsOneWidget);
    });
  }

  for (final bad in ['/yok', '/game/abc', '/game/0', '/game/-4/result']) {
    testApp('Geçersiz adres ($bad) çökmeden "bulunamadı" ekranı gösterir', (
      tester,
      db,
    ) async {
      await openApp(tester, db, at: bad);
      expect(find.text('Sayfa bulunamadı'), findsOneWidget);

      await tester.tap(find.text('Ana Sayfaya Dön'));
      await tester.pumpAndSettle();
      expect(find.text('Yeni Oyun Kur'), findsOneWidget);
    });
  }
}
