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

  // ------------------------------------------------- oyuncu, dağıtıcı, durum

  /// Koltuğa yeni oyuncu oturtur; bir sonraki elden itibaren geçerli,
  /// koltuğun puanları aynen sürer. Geri alınabilir.
  Future<void> replacePlayer(int gameId, int seat, String name) =>
      _changeSeating(
        gameId,
        seat,
        name,
        (seating, played, clean) =>
            seating.replace(seat, clean, roundsPlayed: played),
      );

  /// Koltukta şu an oturanın ismini düzeltir; not bırakmaz. Geri alınabilir.
  Future<void> renamePlayer(int gameId, int seat, String name) =>
      _changeSeating(
        gameId,
        seat,
        name,
        (seating, played, clean) =>
            seating.rename(seat, clean, roundsPlayed: played),
      );

  /// Sıradaki eli [seat] dağıtsın. Geri alınabilir.
  Future<void> setDealer(int gameId, int seat) => _db.transaction(() async {
    final game = await _requireEditable(gameId);
    RangeError.checkValueInInterval(seat, 0, game.config.seatCount - 1, 'seat');
    final offset = dealerOffsetFor(
      seatCount: game.config.seatCount,
      firstDealerSeat: game.firstDealerSeat,
      roundsPlayed: game.rounds.length,
      dealerSeat: seat,
    );
    if (offset == game.dealerOffset) return;
    final now = _clock();
    await _recordUndo(gameId, _UndoKind.dealerChanged, {
      'offset': game.dealerOffset,
    }, now);
    await _updateGame(gameId, GamesCompanion(dealerOffset: Value(offset)));
    await _touch(gameId, now);
  });

  Future<void> setDealerIndicator(int gameId, {required bool enabled}) =>
      _updateGame(gameId, GamesCompanion(dealerIndicator: Value(enabled)));

  /// Oyunu kesin olarak bitirir; artık düzenlenemez, geri alma kaydı silinir.
  Future<void> finishGame(int gameId) => _db.transaction(() async {
    final game = await _requireReadable(gameId);
    if (game.isFinished) return;
    final now = _clock();
    await _updateGame(
      gameId,
      GamesCompanion(
        status: const Value(_finished),
        finishedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await (_db.delete(
      _db.undoActions,
    )..where((a) => a.gameId.equals(gameId))).go();
  });

  /// Aynı kurulum, kurallar ve son oturan oyuncularla yeni oyun açar; eski
  /// oyun bitmemişse bitirir. İlk dağıtıcı, eski oyunda sıradaki dağıtıcıdır.
  Future<int> rematch(int gameId) => _db.transaction(() async {
    final game = await _requireReadable(gameId);
    await finishGame(gameId);
    return createGame(
      config: game.config,
      rules: game.rules,
      playerNames: game.currentNames,
      firstDealerSeat: game.nextDealerSeat,
      dealerIndicator: game.dealerIndicator,
    );
  });

  /// Elleri siler, oyuncular kalır. Geri alınamaz (arayüz onay ister).
  Future<void> restartGame(int gameId) => _db.transaction(() async {
    final game = await _requireEditable(gameId);
    final names = game.currentNames;
    await (_db.delete(_db.rounds)..where((r) => r.gameId.equals(gameId))).go();
    await (_db.delete(
      _db.undoActions,
    )..where((a) => a.gameId.equals(gameId))).go();
    await (_db.delete(
      _db.seatOccupants,
    )..where((o) => o.gameId.equals(gameId))).go();
    await _insertOccupants(gameId, [
      for (var seat = 0; seat < names.length; seat++)
        (seat: seat, name: names[seat], fromSequence: 0),
    ]);
    await _updateGame(gameId, const GamesCompanion(dealerOffset: Value(0)));
    await _touch(gameId, _clock());
  });

  /// Listeden kaldırır; "Geri Al" için [restoreGame], kalıcı silmek için
  /// [purgeDeletedGames].
  Future<void> softDeleteGame(int gameId) =>
      _updateGame(gameId, GamesCompanion(deletedAt: Value(_clock())));

  Future<void> restoreGame(int gameId) =>
      _updateGame(gameId, const GamesCompanion(deletedAt: Value(null)));

  /// Silinmiş işaretli oyunları bağlı kayıtlarıyla kalıcı siler.
  Future<void> purgeDeletedGames() =>
      (_db.delete(_db.games)..where((g) => g.deletedAt.isNotNull())).go();

  /// Daha önce kullanılan isimler; en son kullanılan önce, her isim bir kez.
  /// Silinmiş oyunların isimleri önerilmez; kayıtlı gruplardakiler önerilir.
  Future<List<String>> nameSuggestions({int limit = 20}) async {
    final lastUsed = <String, DateTime>{};
    void use(String name, DateTime at) {
      final current = lastUsed[name];
      if (current == null || at.isAfter(current)) lastUsed[name] = at;
    }

    final rows = await (_db.select(_db.seatOccupants).join([
      innerJoin(_db.games, _db.games.id.equalsExp(_db.seatOccupants.gameId)),
    ])..where(_db.games.deletedAt.isNull())).get();
    for (final row in rows) {
      use(
        row.readTable(_db.seatOccupants).playerName,
        row.readTable(_db.games).updatedAt,
      );
    }
    for (final group in await _db.select(_db.playerGroups).get()) {
      final members = _tryDecodeNames(group.membersJson);
      for (final name in members) {
        use(name, group.updatedAt);
      }
    }
    final names = lastUsed.keys.toList()
      ..sort((a, b) {
        final byTime = lastUsed[b]!.compareTo(lastUsed[a]!);
        return byTime != 0 ? byTime : a.compareTo(b);
      });
    return names.take(limit).toList();
  }

  Future<void> _changeSeating(
    int gameId,
    int seat,
    String rawName,
    Seating Function(Seating seating, int roundsPlayed, String name) change,
  ) => _db.transaction(() async {
    final game = await _requireEditable(gameId);
    RangeError.checkValueInInterval(seat, 0, game.config.seatCount - 1, 'seat');
    final error = validatePlayerName(rawName);
    if (error != null) throw InvalidPlayerNameException(seat, error);
    final name = normalizeName(rawName);
    if (game.currentNames[seat] == name) return;

    final now = _clock();
    final oldRows = await (_db.select(
      _db.seatOccupants,
    )..where((o) => o.gameId.equals(gameId))).get();
    await _recordUndo(gameId, _UndoKind.seatingChanged, {
      'occupants': [
        for (final o in oldRows)
          {
            'seat': o.seat,
            'name': o.playerName,
            'fromSequence': o.fromSequence,
          },
      ],
    }, now);
    await _saveSeating(game, change(game.seating, game.rounds.length, name));
    await _touch(gameId, now);
  });

  /// Konumlu oturma düzenini kalıcı el numaralarıyla yazar.
  Future<void> _saveSeating(GameSnapshot game, Seating seating) async {
    final next = await _nextSequence(game);
    int sequenceFor(int position) {
      if (position <= 1) return 0;
      if (position - 1 < game.rounds.length) {
        return game.rounds[position - 1].sequence;
      }
      return next;
    }

    await (_db.delete(
      _db.seatOccupants,
    )..where((o) => o.gameId.equals(game.id))).go();
    await _insertOccupants(game.id, [
      for (final o in seating.occupants)
        (seat: o.seat, name: o.name, fromSequence: sequenceFor(o.fromRound)),
    ]);
  }

  List<String> _tryDecodeNames(String text) {
    try {
      final value = jsonDecode(text);
      if (value is List) {
        return [
          for (final e in value)
            if (e is String) e,
        ];
      }
    } on FormatException {
      // Bozuk grup kaydı öneriyi engellemez.
    }
    return const [];
  }

  Future<void> _updateGame(int gameId, GamesCompanion change) =>
      (_db.update(_db.games)..where((g) => g.id.equals(gameId))).write(change);

  Future<GameSnapshot> _requireReadable(int gameId) async {
    final load = await loadGame(gameId);
    return switch (load) {
      GameLoaded(:final snapshot) => snapshot,
      GameNotFound() => throw StateError('Oyun bulunamadı: $gameId'),
      GameUnreadable() => throw StateError('Oyun okunamadı: $gameId'),
    };
  }

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
      case _UndoKind.seatingChanged:
        final occupants = payload['occupants'];
        if (occupants is! List) {
          throw const FormatException('Oyuncu kaydı geçersiz');
        }
        final restored = [
          for (final o in occupants)
            if (o case {
              'seat': final int seat,
              'name': final String name,
              'fromSequence': final int fromSequence,
            })
              (seat: seat, name: name, fromSequence: fromSequence)
            else
              throw FormatException('Oyuncu kaydı geçersiz', o),
        ];
        await (_db.delete(
          _db.seatOccupants,
        )..where((o) => o.gameId.equals(gameId))).go();
        await _insertOccupants(gameId, restored);
      case _UndoKind.dealerChanged:
        await _updateGame(
          gameId,
          GamesCompanion(dealerOffset: Value(readInt('offset'))),
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
        for (final winner in game.winners) _contenderName(game, winner, names),
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
  roundDeleted,
  seatingChanged,
  dealerChanged;

  static _UndoKind? fromName(String name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}
