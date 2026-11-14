import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/app.dart';
import 'package:yazboz/app/providers.dart';
import 'package:yazboz/core/router/app_router.dart';
import 'package:yazboz/data/db/app_database.dart';

/// Bellekte veritabanıyla uygulama testi. Gövde bitince ağaç sökülür ve
/// drift'in akış kapanışında bıraktığı zamanlayıcılar boşaltılır; bu
/// test gövdesi içinde yapılmalı, çünkü çerçeve bekleyen zamanlayıcıları
/// tearDown'dan önce denetler.
void testApp(
  String description,
  Future<void> Function(WidgetTester tester, AppDatabase db) body,
) {
  testWidgets(description, (tester) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    try {
      await body(tester, db);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
      await db.close();
    }
  });
}

/// Uygulamayı verilen veritabanı ve adresle açar.
Future<void> pumpApp(
  WidgetTester tester, {
  required AppDatabase db,
  String location = AppRoutes.home,
  Size size = const Size(390, 844),
  double textScale = 1,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = createAppRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db), ...overrides],
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(size: size, textScaler: TextScaler.linear(textScale)),
          child: YazbozApp(router: router),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
