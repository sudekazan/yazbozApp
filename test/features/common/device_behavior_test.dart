import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/core/router/app_router.dart';
import 'package:yazboz/data/db/app_database.dart';
import 'package:yazboz/data/repositories/game_repository.dart';
import 'package:yazboz/data/repositories/settings_repository.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/rules/free_rules.dart';
import 'package:yazboz/features/common/keep_awake.dart';

import '../../helpers.dart';

/// Wakelock ve titreşim platform kanallarını dinler.
class _Channels {
  final List<String> haptics = [];

  void attach() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add('${call.arguments}');
      }
      return null;
    });
  }
}

Future<int> game(AppDatabase db) => GameRepository(db).createGame(
  config: const GameConfig(template: GameTemplate.free, seatCount: 2),
  rules: const FreeRuleSet(),
  playerNames: const ['Ayşe', 'Mehmet'],
);

void main() {
  testApp('titreşim açıkken tuşlar titreşir', (tester, db) async {
    final channels = _Channels()..attach();
    final id = await game(db);
    await pumpApp(tester, db: db, location: AppRoutes.game(id));
    await tester.tap(find.text('El Ekle'));
    await tester.pumpAndSettle();
    channels.haptics.clear();

    await tester.tap(
      find.descendant(
        of: find.bySemanticsLabel('Sayı tuşları'),
        matching: find.text('5'),
      ),
    );
    await tester.pump();
    expect(channels.haptics, isNotEmpty);
  });

  testApp('titreşim kapalıyken tuşlar titreşmez', (tester, db) async {
    final channels = _Channels()..attach();
    final id = await game(db);
    await SettingsRepository(db).save(const AppSettingsData(haptics: false));
    await pumpApp(tester, db: db, location: AppRoutes.game(id));
    await tester.tap(find.text('El Ekle'));
    await tester.pumpAndSettle();
    channels.haptics.clear();

    await tester.tap(
      find.descendant(
        of: find.bySemanticsLabel('Sayı tuşları'),
        matching: find.text('5'),
      ),
    );
    await tester.pump();
    expect(channels.haptics, isEmpty);
  });

  /// Tabloyu verilen ayarla açar; ekranı açık tutma çağrılarını toplar.
  Future<List<bool>> openBoard(
    WidgetTester tester,
    AppDatabase db,
    AppSettingsData settings, {
    Future<void> Function()? then,
  }) async {
    final calls = <bool>[];
    final id = await game(db);
    await SettingsRepository(db).save(settings);
    await pumpApp(
      tester,
      db: db,
      location: AppRoutes.game(id),
      overrides: [
        screenAwakeSwitchProvider.overrideWithValue(
          (on) async => calls.add(on),
        ),
      ],
    );
    await then?.call();
    return calls;
  }

  testApp('ayar açıkken tablo ekranı açık tutar, çıkınca bırakır', (
    tester,
    db,
  ) async {
    final calls = await openBoard(tester, db, const AppSettingsData());
    expect(calls, [true]);
    await tester.pumpWidget(const SizedBox());
    expect(calls, [true, false]);
  });

  testApp('ayar kapalıyken ekran açık tutulmaz', (tester, db) async {
    final calls = await openBoard(
      tester,
      db,
      const AppSettingsData(keepScreenOn: false),
    );
    expect(calls, isEmpty);
  });
}
