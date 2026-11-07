import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/game_config.dart';
import '../../domain/models/round.dart';
import '../../domain/models/rule_set.dart';
import '../../domain/rules/rules_registry.dart';
import '../../domain/seating.dart';
import '../../domain/validation.dart';
import '../db/app_database.dart';
import 'game_models.dart';

/// Oyunların kaydı. Her değişiklik tek bir transaction'da hemen yazılır;
/// uygulama kapansa da oyun kaybolmaz.
class GameRepository {
  GameRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Oyun başına saklanan en fazla geri alma kaydı.
  static const int maxUndoActions = 50;

  static const _active = 'active';
  static const _finished = 'finished';

  // ---------------------------------------------------------------- oluşturma

  Future<int> createGame({
    required GameConfig config,
    required RuleSet rules,
    required List<String> playerNames,
    int firstDealerSeat = 0,
    bool dealerIndicator = true,
  }) async {
    final engine = rulesFor(config.template);
    if (!engine.supports(config)) {
      throw ArgumentError.value(
        config,
        'config',
        'Şablon bu kurulumu desteklemiyor',
      );
    }
    if (rules.template != config.template || rules.validate().isNotEmpty) {
      throw ArgumentError.value(rules, 'rules', 'Kural seti geçersiz');
    }
    if (playerNames.length != config.seatCount) {
      throw ArgumentError.value(
        playerNames,
        'playerNames',
        'İsim sayısı koltuk sayısıyla uyuşmuyor',
      );
    }
    if (firstDealerSeat < 0 || firstDealerSeat >= config.seatCount) {
      throw RangeError.range(
        firstDealerSeat,
        0,
        config.seatCount - 1,
        'firstDealerSeat',
      );
    }
    final names = _cleanNames(playerNames);

    return _db.transaction(() async {
      final now = _clock();
      final id = await _db
          .into(_db.games)
          .insert(
            GamesCompanion.insert(
              template: config.template.name,
              playMode: config.playMode.name,
              seatCount: config.seatCount,
              rulesJson: jsonEncode(rules.toJson()),
              status: _active,
              firstDealerSeat: Value(firstDealerSeat),
              dealerIndicator: Value(dealerIndicator),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _insertOccupants(id, [
        for (var seat = 0; seat < names.length; seat++)
          (seat: seat, name: names[seat], fromSequence: 0),
      ]);
      return id;
    });
  }

  // ------------------------------------------------------------------- okuma

  Future<GameLoad> loadGame(int id) async {
    final row = await (_db.select(
      _db.games,
    )..where((g) => g.id.equals(id) & g.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return GameNotFound(id);
    return _loadRow(row);
  }

  /// Oyunu izler; oyunla ilgili her değişiklikte yeni hali yayınlar.
  Stream<GameLoad> watchGame(int id) =>
      _changes().asyncMap((_) => loadGame(id));

  /// Silinmemiş oyunların özetleri, son güncellenen en üstte.
  Stream<List<GameSummary>> watchGames() => _changes().asyncMap((_) async {
    final rows =
        await (_db.select(_db.games)
              ..where((g) => g.deletedAt.isNull())
              ..orderBy([
                (g) => OrderingTerm.desc(g.updatedAt),
                (g) => OrderingTerm.desc(g.id),
              ]))
            .get();
    return [for (final row in rows) _summaryOf(row, await _loadRow(row))];
  });

  // --------------------------------------------------------------------- eller

  /// Eli hesaplayıp kaydeder; yeni elin kimliğini döner. Girdi geçersizse
  /// [InvalidRoundException], oyun düzenlenemiyorsa [StateError] fırlatır.
  Future<int> addRound(int gameId, RoundInput input) => _db.transaction(
    () async {
      final game = await _requireEditable(gameId);
      final result = game.engine.calculateRound(input, game.rules, game.config);
      final now = _clock();
      final id = await _db
          .into(_db.rounds)
          .insert(
            RoundsCompanion.insert(
              gameId: gameId,
              sequence: await _nextSequence(game),
              inputJson: jsonEncode(input.toJson()),
              pointsJson: jsonEncode(result.points),
              multiplier: Value(result.multiplier),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _recordUndo(gameId, _UndoKind.roundAdded, {'roundId': id}, now);
      await _touch(gameId, now);
      return id;
    },
  );

  Future<void> updateRound(int roundId, RoundInput input) => _db.transaction(
    () async {
      final row = await _requireRound(roundId);
      final game = await _requireEditable(row.gameId);
      final result = game.engine.calculateRound(input, game.rules, game.config);
      final now = _clock();
      await _recordUndo(row.gameId, _UndoKind.roundEdited, {
        'roundId': row.id,
        'inputJson': row.inputJson,
        'pointsJson': row.pointsJson,
        'multiplier': row.multiplier,
        'updatedAt': row.updatedAt.millisecondsSinceEpoch,
      }, now);
      await (_db.update(_db.rounds)..where((r) => r.id.equals(roundId))).write(
        RoundsCompanion(
          inputJson: Value(jsonEncode(input.toJson())),
          pointsJson: Value(jsonEncode(result.points)),
          multiplier: Value(result.multiplier),
          updatedAt: Value(now),
        ),
      );
      await _touch(row.gameId, now);
    },
  );

  Future<void> deleteRound(int roundId) => _db.transaction(() async {
    final row = await _requireRound(roundId);
    await _requireEditable(row.gameId);
    final now = _clock();
    await _recordUndo(row.gameId, _UndoKind.roundDeleted, {
      'roundId': row.id,
      'sequence': row.sequence,
      'inputJson': row.inputJson,
      'pointsJson': row.pointsJson,
      'multiplier': row.multiplier,
      'createdAt': row.createdAt.millisecondsSinceEpoch,
      'updatedAt': row.updatedAt.millisecondsSinceEpoch,
    }, now);
    await (_db.delete(_db.rounds)..where((r) => r.id.equals(roundId))).go();
    await _touch(row.gameId, now);
  });

  // -------------------------------------------------------------- geri alma

  /// Oyundaki son işlemi geri alır. Geri alınacak işlem yoksa ya da kayıt
  /// bozuksa `false` döner (bozuk kayıt atlanır, uygulama çökmez).
  Future<bool> undo(int gameId) => _db.transaction(() async {
    final action =
        await (_db.select(_db.undoActions)
              ..where((a) => a.gameId.equals(gameId))
              ..orderBy([(a) => OrderingTerm.desc(a.id)])
              ..limit(1))
            .getSingleOrNull();
    if (action == null) return false;
    await _requireEditable(gameId);
    await (_db.delete(
      _db.undoActions,
    )..where((a) => a.id.equals(action.id))).go();
    try {
      await _applyInverse(gameId, action);
    } on FormatException {
      return false;
    }
    await _touch(gameId, _clock());
    return true;
  });

  Future<void> _applyInverse(int gameId, UndoActionRow action) async {
    final payload = _decodeObject(action.payloadJson);
    int readInt(String key) => switch (payload[key]) {
      final int value => value,
      final other => throw FormatException(
        'Geri alma alanı geçersiz: $key',
        other,
      ),
    };
    String readText(String key) => switch (payload[key]) {
      final String value => value,
      final other => throw FormatException(
        'Geri alma alanı geçersiz: $key',
        other,
      ),
    };
    DateTime readTime(String key) =>
        DateTime.fromMillisecondsSinceEpoch(readInt(key));

    switch (_UndoKind.fromName(action.kind)) {
      case _UndoKind.roundAdded:
        await (_db.delete(
          _db.rounds,
        )..where((r) => r.id.equals(readInt('roundId')))).go();
      case _UndoKind.roundEdited:
        await (_db.update(
          _db.rounds,
        )..where((r) => r.id.equals(readInt('roundId')))).write(
          RoundsCompanion(
            inputJson: Value(readText('inputJson')),
            pointsJson: Value(readText('pointsJson')),
            multiplier: Value(readInt('multiplier')),
            updatedAt: Value(readTime('updatedAt')),
          ),
        );
      case _UndoKind.roundDeleted:
        await _db
            .into(_db.rounds)
            .insert(
              RoundsCompanion.insert(
                id: Value(readInt('roundId')),
                gameId: gameId,
                sequence: readInt('sequence'),
                inputJson: readText('inputJson'),
                pointsJson: readText('pointsJson'),
                multiplier: Value(readInt('multiplier')),
                createdAt: readTime('createdAt'),
                updatedAt: readTime('updatedAt'),
              ),
            );
      case null:
        throw FormatException('Bilinmeyen geri alma türü', action.kind);
    }
  }

  Future<void> _recordUndo(
    int gameId,
    _UndoKind kind,
    Map<String, Object?> payload,
    DateTime now,
  ) async {
    await _db
        .into(_db.undoActions)
        .insert(
          UndoActionsCompanion.insert(
            gameId: gameId,
            kind: kind.name,
            payloadJson: jsonEncode(payload),
            createdAt: now,
          ),
        );
    // En eski kayıtlar sınırı aşınca silinir.
    final keep =
        await (_db.selectOnly(_db.undoActions)
              ..addColumns([_db.undoActions.id])
              ..where(_db.undoActions.gameId.equals(gameId))
              ..orderBy([OrderingTerm.desc(_db.undoActions.id)])
              ..limit(1, offset: maxUndoActions - 1))
            .getSingleOrNull();
    final oldestKept = keep?.read(_db.undoActions.id);
    if (oldestKept != null) {
      await (_db.delete(_db.undoActions)..where(
            (a) =>
                a.gameId.equals(gameId) & a.id.isSmallerThanValue(oldestKept),
          ))
          .go();
    }
  }

  // ------------------------------------------------------------- yardımcılar

  Stream<void> _changes() => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {_db.games, _db.seatOccupants, _db.rounds, _db.undoActions},
      )
      .watch();

  List<String> _cleanNames(List<String> raw) => [
    for (var seat = 0; seat < raw.length; seat++)
      switch (validatePlayerName(raw[seat])) {
        null => normalizeName(raw[seat]),
        final error => throw InvalidPlayerNameException(seat, error),
      },
  ];

  Future<void> _insertOccupants(
    int gameId,
    List<({int seat, String name, int fromSequence})> occupants,
  ) async {
    for (final o in occupants) {
      await _db
          .into(_db.seatOccupants)
          .insert(
            SeatOccupantsCompanion.insert(
              gameId: gameId,
              seat: o.seat,
              playerName: o.name,
              fromSequence: o.fromSequence,
            ),
          );
    }
  }

  Future<void> _touch(int gameId, DateTime now) =>
      (_db.update(_db.games)..where((g) => g.id.equals(gameId))).write(
        GamesCompanion(updatedAt: Value(now)),
      );

  /// Yeni elin sıra numarası: hem son elden hem de bekleyen oyuncu
  /// değişikliklerinden sonra gelir; böylece değişiklik doğru ele denk gelir.
  Future<int> _nextSequence(GameSnapshot game) async {
    final lastRound = game.rounds.isEmpty ? 0 : game.rounds.last.sequence;
    final occupants = await (_db.select(
      _db.seatOccupants,
    )..where((o) => o.gameId.equals(game.id))).get();
    final pending = occupants.fold(
      0,
      (max, o) => o.fromSequence > max ? o.fromSequence : max,
    );
    return lastRound + 1 > pending ? lastRound + 1 : pending;
  }

  Future<RoundRow> _requireRound(int roundId) async {
    final row = await (_db.select(
      _db.rounds,
    )..where((r) => r.id.equals(roundId))).getSingleOrNull();
    if (row == null) throw StateError('El bulunamadı: $roundId');
    return row;
  }

  Future<GameSnapshot> _requireEditable(int gameId) async {
    final load = await loadGame(gameId);
    return switch (load) {
      GameLoaded(:final snapshot) when !snapshot.isFinished => snapshot,
      GameLoaded() => throw StateError('Biten oyun düzenlenemez: $gameId'),
      GameNotFound() => throw StateError('Oyun bulunamadı: $gameId'),
      GameUnreadable() => throw StateError('Oyun okunamadı: $gameId'),
    };
  }

  Future<GameLoad> _loadRow(GameRow row) async {
    final occupants = await (_db.select(
      _db.seatOccupants,
    )..where((o) => o.gameId.equals(row.id))).get();
    final rounds =
        await (_db.select(_db.rounds)
              ..where((r) => r.gameId.equals(row.id))
              ..orderBy([(r) => OrderingTerm.asc(r.sequence)]))
            .get();
    final undoCount = await _undoCount(row.id);
    try {
      return GameLoaded(_toSnapshot(row, occupants, rounds, undoCount));
    } on FormatException catch (e) {
      return GameUnreadable(row.id, e);
    }
  }

  Future<int> _undoCount(int gameId) async {
    final count = _db.undoActions.id.count();
    final query = _db.selectOnly(_db.undoActions)
      ..addColumns([count])
      ..where(_db.undoActions.gameId.equals(gameId));
    return (await query.getSingle()).read(count) ?? 0;
  }

  GameSummary _summaryOf(GameRow row, GameLoad load) {
    if (load is! GameLoaded) {
      return GameSummary(
        id: row.id,
        updatedAt: row.updatedAt,
        isReadable: false,
      );
    }
    final game = load.snapshot;
    final status = game.status;
    final names = game.currentNames;
    return GameSummary(
      id: game.id,
      updatedAt: game.updatedAt,
      isReadable: true,
      template: game.config.template,
      playMode: game.config.playMode,
      playerNames: names,
      roundsPlayed: game.rounds.length,
      isFinished: game.isFinished,
      status: status,
      winnerNames: [
        if (game.isFinished)
          for (final winner in status.winners)
            _contenderName(game, winner, names),
      ],
    );
  }

  String _contenderName(GameSnapshot game, int contender, List<String> names) {
    final units = game.engine.units(game.config);
    final unitIndices = game.engine.contenders(game.config)[contender];
    final seats = [for (final u in unitIndices) ...units[u].seats];
    return seats.map((s) => names[s]).join(' & ');
  }

  // --------------------------------------------------------- satır → model

  /// Kayıtları domain modeline çevirir; tutarsızlıkta [FormatException].
  GameSnapshot _toSnapshot(
    GameRow row,
    List<SeatOccupantRow> occupants,
    List<RoundRow> rounds,
    int undoCount,
  ) {
    final template =
        GameTemplate.fromName(row.template) ??
        (throw FormatException('Bilinmeyen şablon', row.template));
    final playMode = PlayMode.values.firstWhere(
      (m) => m.name == row.playMode,
      orElse: () => throw FormatException('Bilinmeyen oynanış', row.playMode),
    );
    final config = GameConfig(
      template: template,
      seatCount: row.seatCount,
      playMode: playMode,
    );
    final engine = rulesFor(template);
    if (!engine.supports(config)) {
      throw const FormatException('Desteklenmeyen kurulum');
    }
    final rules = decodeRuleSet(_decodeObject(row.rulesJson));
    if (rules.template != template) {
      throw const FormatException('Kural seti başka şablona ait');
    }
    final status = switch (row.status) {
      _active => false,
      _finished => true,
      final other => throw FormatException('Bilinmeyen durum', other),
    };

    final unitCount = engine.units(config).length;
    final stored = [
      for (final r in rounds)
        StoredRound(
          id: r.id,
          sequence: r.sequence,
          createdAt: r.createdAt,
          round: Round(
            input: decodeRoundInput(template, _decodeObject(r.inputJson)),
            result: RoundResult(
              _decodePoints(r.pointsJson, unitCount),
              multiplier: r.multiplier,
            ),
          ),
        ),
    ];

    return GameSnapshot(
      id: row.id,
      config: config,
      rules: rules,
      isFinished: status,
      firstDealerSeat: row.firstDealerSeat,
      dealerOffset: row.dealerOffset,
      dealerIndicator: row.dealerIndicator,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      finishedAt: row.finishedAt,
      seating: seatingFromRows(occupants, [
        for (final r in rounds) r.sequence,
      ], config.seatCount),
      rounds: List.unmodifiable(stored),
      canUndo: undoCount > 0,
    );
  }

  Map<String, Object?> _decodeObject(String text) {
    final value = jsonDecode(text);
    if (value is Map<String, Object?>) return value;
    throw FormatException('JSON nesnesi bekleniyordu', text);
  }

  List<int> _decodePoints(String text, int unitCount) {
    final value = jsonDecode(text);
    if (value is List &&
        value.length == unitCount &&
        value.every((e) => e is int)) {
      return List<int>.unmodifiable(value.cast<int>());
    }
    throw FormatException('Puan listesi geçersiz', text);
  }
}

/// Koltuk kayıtlarını, elin kalıcı sıra numarasından el konumuna çevirerek
/// [Seating]'e dönüştürür. Her koltukta ilk elden oturan biri yoksa
/// [FormatException].
Seating seatingFromRows(
  List<SeatOccupantRow> rows,
  List<int> roundSequences,
  int seatCount,
) {
  int positionOf(int fromSequence) =>
      1 + roundSequences.where((s) => s < fromSequence).length;

  // Aynı koltukta aynı konuma düşen kayıtlardan en yenisi geçerlidir.
  final bySeatAndPosition = <(int, int), SeatOccupantRow>{};
  for (final row in rows) {
    final key = (row.seat, positionOf(row.fromSequence));
    final existing = bySeatAndPosition[key];
    if (existing == null || row.fromSequence > existing.fromSequence) {
      bySeatAndPosition[key] = row;
    }
  }
  for (var seat = 0; seat < seatCount; seat++) {
    if (!bySeatAndPosition.containsKey((seat, 1))) {
      throw FormatException('Koltukta oyuncu yok', seat);
    }
  }
  if (bySeatAndPosition.keys.any((k) => k.$1 < 0 || k.$1 >= seatCount)) {
    throw const FormatException('Masada olmayan koltuk');
  }
  return Seating([
    for (final MapEntry(key: (seat, position), value: row)
        in bySeatAndPosition.entries)
      SeatOccupant(seat: seat, name: row.playerName, fromRound: position),
  ]);
}

/// Geri alma kaydı türleri. `name` veritabanında saklanır; değiştirilmemeli.
enum _UndoKind {
  roundAdded,
  roundEdited,
  roundDeleted;

  static _UndoKind? fromName(String name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}
