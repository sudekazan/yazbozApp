import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/data/db/app_database.dart';
import 'package:yazboz/data/repositories/game_models.dart';
import 'package:yazboz/data/repositories/game_repository.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/models/round.dart';
import 'package:yazboz/domain/rules/free_rules.dart';
import 'package:yazboz/domain/rules/okey_rules.dart';
import 'package:yazboz/domain/validation.dart';

const freeConfig = GameConfig(template: GameTemplate.free, seatCount: 3);
const okeyConfig = GameConfig(template: GameTemplate.okey, seatCount: 4);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late GameRepository repo;
  var tick = 0;
  DateTime clock() => DateTime(2026, 11, 7, 12).add(Duration(minutes: tick++));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = GameRepository(db, clock: clock);
  });
  tearDown(() => db.close());

  Future<int> newFreeGame([
    List<String> names = const ['Ayşe', 'Mehmet', 'Zeynep'],
  ]) => repo.createGame(
    config: freeConfig,
    rules: const FreeRuleSet(),
    playerNames: names,
  );

  Future<GameSnapshot> snapshotOf(int id) async {
    final load = await repo.loadGame(id);
    expect(load, isA<GameLoaded>());
    return (load as GameLoaded).snapshot;
  }

  group('Oyun oluşturma', () {
    test('kurulum, kurallar ve oyuncular kaydedilir', () async {
      final id = await repo.createGame(
        config: okeyConfig,
        rules: const OkeyRuleSet(startingPoints: 15),
        playerNames: const ['Ayşe', 'Mehmet', 'Zeynep', 'Can'],
        firstDealerSeat: 2,
      );
      final game = await snapshotOf(id);
      expect(game.config.template, GameTemplate.okey);
      expect(game.config.seatCount, 4);
      expect(
        game.rules.toJson(),
        const OkeyRuleSet(startingPoints: 15).toJson(),
      );
      expect(game.seating.namesForRound(1), [
        'Ayşe',
        'Mehmet',
        'Zeynep',
        'Can',
      ]);
      expect(game.isFinished, isFalse);
      expect(game.rounds, isEmpty);
      expect(game.nextDealerSeat, 2);
      expect(game.dealerIndicator, isTrue);
    });

    test('isimler kaydedilmeden önce düzenlenir', () async {
      final id = await newFreeGame(['  Ali\n', 'Veli   Can', 'Su']);
      expect((await snapshotOf(id)).seating.namesForRound(1), [
        'Ali',
        'Veli Can',
        'Su',
      ]);
    });

    test('boş ya da çok uzun isim hangi koltukta olduğunu söyler', () async {
      await expectLater(
        newFreeGame(['Ayşe', '  ', 'Can']),
        throwsA(
          isA<InvalidPlayerNameException>()
              .having((e) => e.seat, 'seat', 1)
              .having((e) => e.error, 'error', NameError.empty),
        ),
      );
      await expectLater(
        newFreeGame(['Ayşe', 'Can', 'x' * 21]),
        throwsA(
          isA<InvalidPlayerNameException>().having((e) => e.seat, 'seat', 2),
        ),
      );
      expect(await db.select(db.games).get(), isEmpty);
    });

    test(
      'şablonun desteklemediği kurulum ya da geçersiz kural reddedilir',
      () async {
        await expectLater(
          repo.createGame(
            config: const GameConfig(template: GameTemplate.okey, seatCount: 3),
            rules: const OkeyRuleSet(),
            playerNames: const ['A', 'B', 'C'],
          ),
          throwsArgumentError,
        );
        await expectLater(
          repo.createGame(
            config: freeConfig,
            rules: const FreeRuleSet(target: 0),
            playerNames: const ['A', 'B', 'C'],
          ),
          throwsArgumentError,
        );
      },
    );

    test('olmayan oyun "bulunamadı" döner', () async {
      expect(await repo.loadGame(42), isA<GameNotFound>());
    });
  });

  group('El kaydı', () {
    test('el puanı motorla hesaplanıp kaydedilir', () async {
      final id = await repo.createGame(
        config: okeyConfig,
        rules: const OkeyRuleSet(),
        playerNames: const ['A', 'B', 'C', 'D'],
      );
      await repo.addRound(id, const OkeyRoundInput(finisherSeat: 1));
      final round = (await snapshotOf(id)).rounds.single;
      expect(round.round.result.points, [-2, 0, -2, -2]);
      expect(
        round.round.input.toJson(),
        const OkeyRoundInput(finisherSeat: 1).toJson(),
      );
    });

    test('eller sırayla eklenir ve dağıtıcı ilerler', () async {
      final id = await newFreeGame();
      await repo.addRound(id, const FreeRoundInput([1, 2, 3]));
      await repo.addRound(id, const FreeRoundInput([4, 5, 6]));
      final game = await snapshotOf(id);
      expect(game.rounds.map((r) => r.round.result.points), [
        [1, 2, 3],
        [4, 5, 6],
      ]);
      expect(game.nextDealerSeat, 2);
    });

    test('geçersiz el kaydedilmez', () async {
      final id = await newFreeGame();
      await expectLater(
        repo.addRound(id, const FreeRoundInput([1, 2])),
        throwsA(isA<InvalidRoundException>()),
      );
      expect((await snapshotOf(id)).rounds, isEmpty);
    });

    test('el düzenlenince puan yeni girdiden yeniden hesaplanır', () async {
      final id = await newFreeGame();
      final roundId = await repo.addRound(id, const FreeRoundInput([1, 2, 3]));
      await repo.updateRound(roundId, const FreeRoundInput([9, 8, 7]));
      expect((await snapshotOf(id)).rounds.single.round.result.points, [
        9,
        8,
        7,
      ]);
    });

    test('el silinince diğerleri sırasını korur', () async {
      final id = await newFreeGame();
      await repo.addRound(id, const FreeRoundInput([1, 1, 1]));
      final second = await repo.addRound(id, const FreeRoundInput([2, 2, 2]));
      await repo.addRound(id, const FreeRoundInput([3, 3, 3]));
      await repo.deleteRound(second);
      final game = await snapshotOf(id);
      expect(game.rounds.map((r) => r.round.result.points.first), [1, 3]);
      expect(game.nextDealerSeat, 2);
    });

    test(
      'her el kaydedildiği anda yazılır; uygulama kapanıp açılınca durur',
      () async {
        final dir = Directory.systemTemp.createTempSync('yazboz_test');
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = File('${dir.path}/yazboz.sqlite');

        final first = AppDatabase(NativeDatabase(file));
        final id = await GameRepository(first).createGame(
          config: freeConfig,
          rules: const FreeRuleSet(),
          playerNames: const ['A', 'B', 'C'],
        );
        await GameRepository(first)
            .addRound(id, const FreeRoundInput([5, 0, -5]));
        await first.close();

        final reopened = AppDatabase(NativeDatabase(file));
        addTearDown(reopened.close);
        final load = await GameRepository(reopened).loadGame(id);
        expect(
          (load as GameLoaded).snapshot.rounds.single.round.result.points,
          [5, 0, -5],
        );
      },
    );

    test('oyun değişince izleyen akış yeni hali yayınlar', () async {
      final id = await newFreeGame();
      final stream = repo.watchGame(id);
      final expectation = expectLater(
        stream.map((load) => (load as GameLoaded).snapshot.rounds.length),
        emitsThrough(1),
      );
      await repo.addRound(id, const FreeRoundInput([1, 2, 3]));
      await expectation;
    });
  });

  group('Oyun listesi', () {
    test('son güncellenen oyun en üstte; isim ve el sayısı görünür', () async {
      final older = await newFreeGame(['A', 'B', 'C']);
      final newer = await newFreeGame(['D', 'E', 'F']);
      await repo.addRound(older, const FreeRoundInput([1, 1, 1]));

      final list = await repo.watchGames().first;
      expect(list.map((g) => g.id), [older, newer]);
      expect(list.first.playerNames, ['A', 'B', 'C']);
      expect(list.first.roundsPlayed, 1);
      expect(list.first.template, GameTemplate.free);
    });
  });

  group('Bozuk veri', () {
    Future<void> corrupt(int id, GamesCompanion change) =>
        (db.update(db.games)..where((g) => g.id.equals(id))).write(change);

    test('bozuk kural JSON çökme yerine "okunamadı" döner', () async {
      final id = await newFreeGame();
      await corrupt(id, const GamesCompanion(rulesJson: Value('{bozuk')));
      expect(await repo.loadGame(id), isA<GameUnreadable>());
    });

    test('bilinmeyen şablon adı "okunamadı" döner', () async {
      final id = await newFreeGame();
      await corrupt(id, const GamesCompanion(template: Value('poker')));
      expect(await repo.loadGame(id), isA<GameUnreadable>());
    });

    test('bozuk el girdisi "okunamadı" döner', () async {
      final id = await newFreeGame();
      final roundId = await repo.addRound(id, const FreeRoundInput([1, 2, 3]));
      await (db.update(db.rounds)..where((r) => r.id.equals(roundId))).write(
        const RoundsCompanion(inputJson: Value('{"type":"free","points":"x"}')),
      );
      expect(await repo.loadGame(id), isA<GameUnreadable>());
    });

    test('puan sayısı oyuncu sayısıyla uyuşmazsa "okunamadı" döner', () async {
      final id = await newFreeGame();
      final roundId = await repo.addRound(id, const FreeRoundInput([1, 2, 3]));
      await (db.update(db.rounds)..where((r) => r.id.equals(roundId))).write(
        const RoundsCompanion(pointsJson: Value('[1]')),
      );
      expect(await repo.loadGame(id), isA<GameUnreadable>());
    });

    test('okunamayan oyun listede işaretli görünür, liste çökmez', () async {
      final good = await newFreeGame();
      final bad = await newFreeGame();
      await corrupt(bad, const GamesCompanion(rulesJson: Value('[]')));
      final list = await repo.watchGames().first;
      expect(list.firstWhere((g) => g.id == bad).isReadable, isFalse);
      expect(list.firstWhere((g) => g.id == good).isReadable, isTrue);
    });

    test('okunamayan oyuna el eklenemez', () async {
      final id = await newFreeGame();
      await corrupt(id, const GamesCompanion(rulesJson: Value('{bozuk')));
      await expectLater(
        repo.addRound(id, const FreeRoundInput([1, 2, 3])),
        throwsStateError,
      );
    });
  });
}
