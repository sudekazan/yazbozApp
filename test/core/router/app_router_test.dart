import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/app.dart';
import 'package:yazboz/core/router/app_router.dart';

Future<void> openApp(WidgetTester tester, {String? at}) async {
  final router = createAppRouter(initialLocation: at ?? AppRoutes.home);
  addTearDown(router.dispose);
  await tester.pumpWidget(YazbozApp(router: router));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Ana sayfadan oyun seçimine gidilir, geri tuşu ana sayfaya döner',
    (tester) async {
      await openApp(tester);
      await tester.tap(find.text('Yeni Oyun Kur'));
      await tester.pumpAndSettle();
      expect(find.text('Oyun Seç'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Yeni Oyun Kur'), findsOneWidget);
    },
  );

  testWidgets('Ayarlar ikonu ayarlar ekranını açar ve etiketi vardır', (
    tester,
  ) async {
    await openApp(tester);
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
    testWidgets('$location adresi "$title" ekranını açar', (tester) async {
      await openApp(tester, at: location);
      expect(find.text(title), findsOneWidget);
    });
  }

  for (final bad in ['/yok', '/game/abc', '/game/0', '/game/-4/result']) {
    testWidgets('Geçersiz adres ($bad) çökmeden "bulunamadı" ekranı gösterir', (
      tester,
    ) async {
      await openApp(tester, at: bad);
      expect(find.text('Sayfa bulunamadı'), findsOneWidget);

      await tester.tap(find.text('Ana Sayfaya Dön'));
      await tester.pumpAndSettle();
      expect(find.text('Yeni Oyun Kur'), findsOneWidget);
    });
  }
}
