import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/data/db/app_database.dart';
import 'package:yazboz/data/repositories/game_models.dart';
import 'package:yazboz/data/repositories/game_repository.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/rules/free_rules.dart';
import 'package:yazboz/domain/rules/okey_rules.dart';

const config = GameConfig(template: GameTemplate.free, seatCount: 3);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late GameRepository repo;
  late int gameId;
  var tick = 0;
  DateTime clock() => DateTime(2026, 11, 7, 12).add(Duration(minutes: tick++));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = GameRepository(db, clock: clock);
    gameId = await repo.createGame(
      config: config,
      rules: const FreeRuleSet(target: 100),
      playerNames: const ['Ayşe', 'Mehmet', 'Can'],
    );
  });
  tearDown(() => db.close());

  Future<GameSnapshot> game([int? id]) async =>
      ((await repo.loadGame(id ?? gameId)) as GameLoaded).snapshot;

  Future<int> add(List<int> points) =>
      repo.addRound(gameId, FreeRoundInput(points));

  group('Oyuncu değiştirme', () {
    test(
      'yeni oyuncu bir sonraki elden oturur, puanlar koltukta kalır',
      () async {
        await add([10, 0, 0]);
        await add([5, 0, 0]);
        await repo.replacePlayer(gameId, 2, 'Burak');
        await add([0, 0, 7]);

        final g = await game();
        expect(g.seating.nameAt(2, 2), 'Can');
        expect(g.seating.nameAt(2, 3), 'Burak');
        final change = g.seating.changes().single;
        expect((change.fromRound, change.from, change.to), (3, 'Can', 'Burak'));
        expect(g.status.standings.firstWhere((s) => s.contender == 2).total, 7);
        expect(g.currentNames, ['Ayşe', 'Mehmet', 'Burak']);
      },
    );

    test('hiç el oynanmadan değiştirme sadece ismi değiştirir', () async {
      await repo.replacePlayer(gameId, 0, 'Aylin');
      final g = await game();
      expect(g.seating.namesForRound(1).first, 'Aylin');
      expect(g.seating.changes(), isEmpty);
    });

    test('değiştirme geri alınabilir', () async {
      await add([1, 1, 1]);
      await repo.replacePlayer(gameId, 1, 'Elif');
      await repo.undo(gameId);
      final g = await game();
      expect(g.currentNames, ['Ayşe', 'Mehmet', 'Can']);
      expect(g.seating.changes(), isEmpty);
    });

    test('önceki bir el silinse de değişiklik doğru elde kalır', () async {
      await add([1, 0, 0]);
      await add([2, 0, 0]);
      await repo.replacePlayer(gameId, 0, 'Elif');
      await add([3, 0, 0]);
      final first = (await game()).rounds.first.id;
      await repo.deleteRound(first);

      final g = await game();
      // Kalan eller: 2 (Ayşe) ve 3 (Elif).
      expect(g.seating.nameAt(0, 1), 'Ayşe');
      expect(g.seating.nameAt(0, 2), 'Elif');
    });

    test(
      'değişiklikten sonra son el silinirse yeni oyuncu sıradaki eli oynar',
      () async {
        await add([1, 0, 0]);
        final second = await add([2, 0, 0]);
        await repo.replacePlayer(gameId, 0, 'Elif');
        await repo.deleteRound(second);
        await add([9, 0, 0]);

        final g = await game();
        expect(g.seating.nameAt(0, 1), 'Ayşe');
        expect(g.seating.nameAt(0, 2), 'Elif');
      },
    );

    test('ismi düzenlemek not bırakmaz ve geri alınabilir', () async {
      await add([1, 1, 1]);
      await repo.renamePlayer(gameId, 1, 'Mehmet K.');
      var g = await game();
      expect(g.seating.nameAt(1, 1), 'Mehmet K.');
      expect(g.seating.changes(), isEmpty);
      await repo.undo(gameId);
      g = await game();
      expect(g.seating.nameAt(1, 1), 'Mehmet');
    });

    test('geçersiz isim ya da koltuk reddedilir', () async {
      await expectLater(
        repo.replacePlayer(gameId, 0, ''),
        throwsA(isA<InvalidPlayerNameException>()),
      );
      await expectLater(repo.replacePlayer(gameId, 3, 'Ali'), throwsRangeError);
    });
  });

  group('Dağıtıcı', () {
    test('elle seçilen dağıtıcı sonraki ellerde de sırayla ilerler', () async {
      await add([1, 1, 1]);
      await repo.setDealer(gameId, 0);
      expect((await game()).nextDealerSeat, 0);
      await add([1, 1, 1]);
      expect((await game()).nextDealerSeat, 1);
    });

    test('elle değiştirme geri alınabilir', () async {
      await add([1, 1, 1]);
      await repo.setDealer(gameId, 0);
      await repo.undo(gameId);
      expect((await game()).nextDealerSeat, 1);
    });

    test('dağıtıcı göstergesi oyun bazında kapatılabilir', () async {
      await repo.setDealerIndicator(gameId, enabled: false);
      expect((await game()).dealerIndicator, isFalse);
    });
  });

  group('Oyun sonu', () {
    test('biten oyun düzenlenemez ve geri alma kaydı temizlenir', () async {
      await add([60, 0, 0]);
      await repo.finishGame(gameId);
      final g = await game();
      expect(g.isFinished, isTrue);
      expect(g.finishedAt, isNotNull);
      expect(g.canUndo, isFalse);
      await expectLater(add([1, 1, 1]), throwsStateError);
    });

    test('biten oyun listede kazananıyla görünür', () async {
      await add([120, 3, 4]);
      await repo.finishGame(gameId);
      final summary = (await repo.watchGames().first).single;
      expect(summary.isFinished, isTrue);
      expect(summary.winnerNames, ['Ayşe']);
    });

    test('eşli oyunda kazanan takım iki isimle yazılır', () async {
      final okey = await repo.createGame(
        config: const GameConfig(
          template: GameTemplate.okey,
          seatCount: 4,
          playMode: PlayMode.pairs,
        ),
        rules: const OkeyRuleSet(),
        playerNames: const ['Ayşe', 'Mehmet', 'Zeynep', 'Can'],
      );
      await repo.addRound(okey, const OkeyRoundInput(finisherSeat: 0));
      await repo.finishGame(okey);
      final summary = (await repo.watchGames().first).firstWhere(
        (s) => s.id == okey,
      );
      expect(summary.winnerNames, ['Ayşe & Zeynep']);
    });

    test('rövanş aynı oyuncu ve kurallarla yeni oyun açar', () async {
      await add([1, 1, 1]);
      await repo.replacePlayer(gameId, 2, 'Burak');
      final rematch = await repo.rematch(gameId);

      final old = await game();
      final fresh = await game(rematch);
      expect(old.isFinished, isTrue);
      expect(fresh.isFinished, isFalse);
      expect(fresh.rounds, isEmpty);
      expect(fresh.currentNames, ['Ayşe', 'Mehmet', 'Burak']);
      expect(fresh.rules.toJson(), old.rules.toJson());
      // Önceki oyunda sıradaki dağıtıcı rövanşın ilk dağıtıcısı olur.
      expect(fresh.nextDealerSeat, old.nextDealerSeat);
    });

    test('yeniden başlatma elleri siler, oyuncular kalır', () async {
      await add([1, 1, 1]);
      await repo.replacePlayer(gameId, 0, 'Elif');
      await add([2, 2, 2]);
      await repo.setDealer(gameId, 2);
      await repo.restartGame(gameId);

      final g = await game();
      expect(g.rounds, isEmpty);
      expect(g.currentNames, ['Elif', 'Mehmet', 'Can']);
      expect(g.seating.changes(), isEmpty);
      expect(g.nextDealerSeat, 0);
      expect(g.canUndo, isFalse);
    });
  });

  group('Silme', () {
    test('silinen oyun listeden kalkar, geri alınınca döner', () async {
      await repo.softDeleteGame(gameId);
      expect(await repo.watchGames().first, isEmpty);
      expect(await repo.loadGame(gameId), isA<GameNotFound>());

      await repo.restoreGame(gameId);
      expect((await repo.watchGames().first).single.id, gameId);
    });

    test('kalıcı silme sadece silinmiş oyunları kaldırır', () async {
      final keep = await repo.createGame(
        config: config,
        rules: const FreeRuleSet(),
        playerNames: const ['D', 'E', 'F'],
      );
      await add([1, 1, 1]);
      await repo.softDeleteGame(gameId);
      await repo.purgeDeletedGames();

      final ids = (await db.select(db.games).get()).map((g) => g.id);
      expect(ids, [keep]);
      expect(await db.select(db.rounds).get(), isEmpty);
    });
  });

  group('İsim önerileri', () {
    test('önce en son kullanılanlar, her isim bir kez', () async {
      final second = await repo.createGame(
        config: config,
        rules: const FreeRuleSet(),
        playerNames: const ['Zeynep', 'Ayşe', 'Deniz'],
      );
      await repo.addRound(second, const FreeRoundInput([1, 1, 1]));
      final names = await repo.nameSuggestions();
      expect(names.take(3), unorderedEquals(['Zeynep', 'Ayşe', 'Deniz']));
      expect(names.toSet(), {'Zeynep', 'Ayşe', 'Deniz', 'Mehmet', 'Can'});
      expect(names, hasLength(5));
    });

    test('kayıtlı gruplardaki isimler de önerilir', () async {
      await db
          .into(db.playerGroups)
          .insert(
            PlayerGroupsCompanion.insert(
              name: 'Ailem',
              membersJson: '["Selin","Kaan"]',
              createdAt: clock(),
              updatedAt: clock(),
            ),
          );
      final names = await repo.nameSuggestions();
      expect(names, containsAll(['Selin', 'Kaan']));
      expect(names.first, isIn(['Selin', 'Kaan']));
    });

    test('silinmiş oyunların isimleri önerilmez, sınır uygulanır', () async {
      await repo.softDeleteGame(gameId);
      expect(await repo.nameSuggestions(), isEmpty);
      await repo.restoreGame(gameId);
      expect(await repo.nameSuggestions(limit: 2), hasLength(2));
    });
  });
}
