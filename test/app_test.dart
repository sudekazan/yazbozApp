import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/data/repositories/settings_repository.dart';

import 'helpers.dart';

void main() {
  testApp('uygulama Türkçe açılır ve tema ayarı sistemden gelir', (
    tester,
    db,
  ) async {
    await pumpApp(tester, db: db);

    expect(find.text('Yazboz'), findsWidgets);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    final context = tester.element(find.byType(Scaffold).first);
    expect(Localizations.localeOf(context).languageCode, 'tr');
  });

  testApp('ayarlarda koyu tema seçiliyse uygulama koyu açılır', (
    tester,
    db,
  ) async {
    await SettingsRepository(db)
        .save(const AppSettingsData(themeMode: AppThemeMode.dark));
    await pumpApp(tester, db: db);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
