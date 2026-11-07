import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<int> insertGame() {
    final now = DateTime(2026, 11, 7);
    return db
        .into(db.games)
        .insert(
          GamesCompanion.insert(
            template: 'free',
            playMode: 'individual',
            seatCount: 2,
            rulesJson: '{}',
            status: 'active',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  test('yabancı anahtar denetimi açıktır', () async {
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.data.values.single, 1);
  });

  test('oyun silinince koltuk, el ve geri alma kayıtları da silinir', () async {
    final gameId = await insertGame();
    final now = DateTime(2026, 11, 7);
    await db
        .into(db.seatOccupants)
        .insert(
          SeatOccupantsCompanion.insert(
            gameId: gameId,
            seat: 0,
            playerName: 'Ayşe',
            fromRound: 1,
          ),
        );
    await db
        .into(db.rounds)
        .insert(
          RoundsCompanion.insert(
            gameId: gameId,
            sequence: 1,
            inputJson: '{}',
            pointsJson: '[1, 2]',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.undoActions)
        .insert(
          UndoActionsCompanion.insert(
            gameId: gameId,
            kind: 'roundAdded',
            payloadJson: '{}',
            createdAt: now,
          ),
        );

    await (db.delete(db.games)..where((g) => g.id.equals(gameId))).go();

    expect(await db.select(db.seatOccupants).get(), isEmpty);
    expect(await db.select(db.rounds).get(), isEmpty);
    expect(await db.select(db.undoActions).get(), isEmpty);
  });

  test('aynı oyunda aynı sıra numarasıyla iki el olamaz', () async {
    final gameId = await insertGame();
    final now = DateTime(2026, 11, 7);
    RoundsCompanion round() => RoundsCompanion.insert(
      gameId: gameId,
      sequence: 1,
      inputJson: '{}',
      pointsJson: '[]',
      createdAt: now,
      updatedAt: now,
    );
    await db.into(db.rounds).insert(round());
    expect(
      () => db.into(db.rounds).insert(round()),
      throwsA(isA<SqliteException>()),
    );
  });

  test('olmayan oyuna el eklenemez', () async {
    final now = DateTime(2026, 11, 7);
    expect(
      () => db
          .into(db.rounds)
          .insert(
            RoundsCompanion.insert(
              gameId: 999,
              sequence: 1,
              inputJson: '{}',
              pointsJson: '[]',
              createdAt: now,
              updatedAt: now,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });
}
