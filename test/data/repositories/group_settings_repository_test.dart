import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/data/db/app_database.dart';
import 'package:yazboz/data/repositories/group_repository.dart';
import 'package:yazboz/data/repositories/settings_repository.dart';
import 'package:yazboz/domain/validation.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  var tick = 0;
  DateTime clock() => DateTime(2026, 11, 7, 12).add(Duration(minutes: tick++));

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('Oyuncu grupları', () {
    late GroupRepository groups;
    setUp(() => groups = GroupRepository(db, clock: clock));

    test(
      'grup isim ve sıralı üyelerle kaydedilir, isimler temizlenir',
      () async {
        await groups.createGroup('  Ailem ', [' Ayşe', 'Mehmet\n', 'Zeynep']);
        final group = (await groups.watchGroups().first).single;
        expect(group.name, 'Ailem');
        expect(group.members, ['Ayşe', 'Mehmet', 'Zeynep']);
      },
    );

    test('son kullanılan grup listede önce gelir', () async {
      final family = await groups.createGroup('Ailem', ['A', 'B']);
      await groups.createGroup('İş', ['C', 'D']);
      await groups.markUsed(family);
      expect((await groups.watchGroups().first).map((g) => g.name), [
        'Ailem',
        'İş',
      ]);
    });

    test('grup düzenlenebilir ve silinebilir', () async {
      final id = await groups.createGroup('Cuma', ['A', 'B', 'C']);
      await groups.updateGroup(id, name: 'Cuma ekibi', members: ['C', 'A']);
      final group = (await groups.watchGroups().first).single;
      expect(group.name, 'Cuma ekibi');
      expect(group.members, ['C', 'A']);
      await groups.deleteGroup(id);
      expect(await groups.watchGroups().first, isEmpty);
    });

    test('grup ismi boş ya da 30 karakterden uzun olamaz', () async {
      await expectLater(
        groups.createGroup(' ', ['A', 'B']),
        throwsA(
          isA<InvalidGroupException>().having(
            (e) => e.problem,
            'problem',
            GroupProblem.name,
          ),
        ),
      );
      await expectLater(
        groups.createGroup('g' * 31, ['A', 'B']),
        throwsA(isA<InvalidGroupException>()),
      );
    });

    test('geçersiz üye ismi hangi sırada olduğunu söyler', () async {
      await expectLater(
        groups.createGroup('Ailem', ['A', '', 'C']),
        throwsA(
          isA<InvalidGroupException>()
              .having((e) => e.problem, 'problem', GroupProblem.member)
              .having((e) => e.memberIndex, 'memberIndex', 1)
              .having((e) => e.nameError, 'nameError', NameError.empty),
        ),
      );
    });

    test('üye sayısı 2 ile 8 arasında olmalı', () async {
      await expectLater(
        groups.createGroup('Tek', ['A']),
        throwsA(
          isA<InvalidGroupException>().having(
            (e) => e.problem,
            'problem',
            GroupProblem.memberCount,
          ),
        ),
      );
      await expectLater(
        groups.createGroup('Kalabalık', [
          for (var i = 0; i < 9; i++) 'Kişi $i',
        ]),
        throwsA(isA<InvalidGroupException>()),
      );
    });

    test('bozuk grup kaydı listeyi çökertmez, atlanır', () async {
      await groups.createGroup('Sağlam', ['A', 'B']);
      await db
          .into(db.playerGroups)
          .insert(
            PlayerGroupsCompanion.insert(
              name: 'Bozuk',
              membersJson: '{bozuk',
              createdAt: clock(),
              updatedAt: clock(),
            ),
          );
      expect((await groups.watchGroups().first).map((g) => g.name), ['Sağlam']);
    });
  });

  group('Ayarlar', () {
    late SettingsRepository settings;
    setUp(() => settings = SettingsRepository(db));

    test('ilk açılışta varsayılanlar: sistem teması, ekran açık, titreşim ve dağıtıcı açık', () async {
      final value = await settings.load();
      expect(value.themeMode, AppThemeMode.system);
      expect(value.keepScreenOn, isTrue);
      expect(value.haptics, isTrue);
      expect(value.dealerIndicatorDefault, isTrue);
    });

    test('değişiklik kaydedilir ve izleyene yayınlanır', () async {
      final expectation = expectLater(
        settings.watch().map((s) => s.themeMode),
        emitsThrough(AppThemeMode.dark),
      );
      final current = await settings.load();
      await settings.save(
        current.copyWith(themeMode: AppThemeMode.dark, haptics: false),
      );
      await expectation;
      final saved = await settings.load();
      expect((saved.themeMode, saved.haptics), (AppThemeMode.dark, false));
    });

    test('bilinmeyen tema değeri sisteme düşer', () async {
      await settings.save(await settings.load());
      await db
          .update(db.appSettings)
          .write(const AppSettingsCompanion(themeMode: Value('mor')));
      expect((await settings.load()).themeMode, AppThemeMode.system);
    });
  });
}
