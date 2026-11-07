import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/data/db/app_database.dart';
import 'package:yazboz/data/repositories/game_models.dart';
import 'package:yazboz/data/repositories/game_repository.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/rules/free_rules.dart';

const config = GameConfig(template: GameTemplate.free, seatCount: 3);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late GameRepository repo;
  late int gameId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = GameRepository(db);
    gameId = await repo.createGame(
      config: config,
      rules: const FreeRuleSet(),
      playerNames: const ['A', 'B', 'C'],
    );
  });
  tearDown(() => db.close());

  Future<GameSnapshot> snapshot() async =>
      ((await repo.loadGame(gameId)) as GameLoaded).snapshot;

  Future<List<List<int>>> points() async =>
      (await snapshot()).rounds.map((r) => r.round.result.points).toList();

  test('başta geri alınacak işlem yoktur', () async {
    expect((await snapshot()).canUndo, isFalse);
    expect(await repo.undo(gameId), isFalse);
  });

  test('el eklemeyi geri alma eli siler, dağıtıcı da geri döner', () async {
    await repo.addRound(gameId, const FreeRoundInput([1, 2, 3]));
    expect((await snapshot()).canUndo, isTrue);
    expect((await snapshot()).nextDealerSeat, 1);

    expect(await repo.undo(gameId), isTrue);
    expect(await points(), isEmpty);
    expect((await snapshot()).nextDealerSeat, 0);
    expect((await snapshot()).canUndo, isFalse);
  });

  test('el düzenlemeyi geri alma eski girdiyi ve puanı getirir', () async {
    final id = await repo.addRound(gameId, const FreeRoundInput([1, 2, 3]));
    await repo.updateRound(id, const FreeRoundInput([7, 7, 7]));
    await repo.undo(gameId);
    final round = (await snapshot()).rounds.single.round;
    expect(round.result.points, [1, 2, 3]);
    expect(round.input.toJson(), const FreeRoundInput([1, 2, 3]).toJson());
  });

  test('el silmeyi geri alma eli aynı yerine geri koyar', () async {
    await repo.addRound(gameId, const FreeRoundInput([1, 1, 1]));
    final middle = await repo.addRound(gameId, const FreeRoundInput([2, 2, 2]));
    await repo.addRound(gameId, const FreeRoundInput([3, 3, 3]));
    await repo.deleteRound(middle);
    expect((await snapshot()).nextDealerSeat, 2);

    await repo.undo(gameId);
    expect((await points()).map((p) => p.first), [1, 2, 3]);
    expect((await snapshot()).rounds[1].id, middle);
    expect((await snapshot()).nextDealerSeat, 0);
  });

  test('işlemler sondan başa sırayla geri alınır', () async {
    final first = await repo.addRound(gameId, const FreeRoundInput([1, 1, 1]));
    await repo.addRound(gameId, const FreeRoundInput([2, 2, 2]));
    await repo.updateRound(first, const FreeRoundInput([9, 9, 9]));

    await repo.undo(gameId);
    expect(await points(), [
      [1, 1, 1],
      [2, 2, 2],
    ]);
    await repo.undo(gameId);
    expect(await points(), [
      [1, 1, 1],
    ]);
    await repo.undo(gameId);
    expect(await points(), isEmpty);
  });

  test('oyun başına son 50 işlem saklanır', () async {
    for (var i = 0; i < 55; i++) {
      await repo.addRound(gameId, FreeRoundInput([i, 0, 0]));
    }
    var undone = 0;
    while (await repo.undo(gameId)) {
      undone++;
    }
    expect(undone, GameRepository.maxUndoActions);
    expect(await points(), hasLength(5));
  });

  test('bozuk geri alma kaydı çökme yapmaz, atlanır', () async {
    await repo.addRound(gameId, const FreeRoundInput([1, 2, 3]));
    await db
        .update(db.undoActions)
        .write(const UndoActionsCompanion(payloadJson: Value('{bozuk')));
    expect(await repo.undo(gameId), isFalse);
    expect(await points(), hasLength(1));
    expect((await snapshot()).canUndo, isFalse);
  });

  test('bir oyunun geri alması diğer oyunu etkilemez', () async {
    final other = await repo.createGame(
      config: config,
      rules: const FreeRuleSet(),
      playerNames: const ['D', 'E', 'F'],
    );
    await repo.addRound(other, const FreeRoundInput([5, 5, 5]));
    expect(await repo.undo(gameId), isFalse);
    final otherGame = ((await repo.loadGame(other)) as GameLoaded).snapshot;
    expect(otherGame.rounds, hasLength(1));
  });
}
