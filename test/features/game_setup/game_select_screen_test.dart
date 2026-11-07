import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/core/router/app_router.dart';

import '../../helpers.dart';

void main() {
  testApp('altı şablon isim ve açıklamasıyla iki sütunda listelenir', (
    tester,
    db,
  ) async {
    await pumpApp(tester, db: db, location: AppRoutes.newGame);
    for (final (name, description) in const [
      ('Serbest', 'Her oyun için'),
      ('Okey', "20'den geriye"),
      ('101 Okey', 'Düşük puan kazanır'),
      ('Tavla', 'Mars ve küp'),
      ('Pişti', 'Sayaçla puan'),
      ('Batak', 'Düz ya da ihaleli'),
    ]) {
      expect(find.text(name), findsOneWidget);
      expect(find.text(description), findsOneWidget);
    }
    final serbest = tester.getTopLeft(find.text('Serbest'));
    final okey = tester.getTopLeft(find.text('Okey'));
    expect(okey.dy, serbest.dy, reason: 'aynı satırda');
    expect(okey.dx, greaterThan(serbest.dx));
  });

  testApp('şablona dokununca o şablonun kurulumu açılır', (tester, db) async {
    await pumpApp(tester, db: db, location: AppRoutes.newGame);
    await tester.tap(find.text('Pişti'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Pişti'), findsOneWidget);
  });

  testApp('bilinmeyen şablon adresi bulunamadı ekranına düşer', (
    tester,
    db,
  ) async {
    await pumpApp(tester, db: db, location: '/new/poker');
    expect(find.text('Sayfa bulunamadı'), findsOneWidget);
  });

  testApp('küçük ekranda büyük yazıyla taşma olmaz', (tester, db) async {
    await pumpApp(
      tester,
      db: db,
      location: AppRoutes.newGame,
      size: const Size(375, 667),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
