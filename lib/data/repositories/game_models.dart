import '../../domain/models/game.dart';
import '../../domain/models/game_config.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/round.dart';
import '../../domain/models/rule_set.dart';
import '../../domain/rules/game_rules.dart';
import '../../domain/rules/rules_registry.dart';
import '../../domain/seating.dart' as seating_rules;
import '../../domain/seating.dart' show Seating;
import '../../domain/validation.dart';

/// Kayıtlı bir el.
class StoredRound {
  const StoredRound({
    required this.id,
    required this.sequence,
    required this.round,
    required this.createdAt,
  });

  final int id;

  /// Kalıcı sıra numarası (silinen el geri gelince aynı numarayla döner).
  final int sequence;
  final Round round;
  final DateTime createdAt;
}

/// Bir oyunun veritabanındaki tam hali.
class GameSnapshot {
  const GameSnapshot({
    required this.id,
    required this.config,
    required this.rules,
    required this.isFinished,
    required this.firstDealerSeat,
    required this.dealerOffset,
    required this.dealerIndicator,
    required this.createdAt,
    required this.updatedAt,
    required this.finishedAt,
    required this.seating,
    required this.rounds,
    required this.canUndo,
  });

  final int id;
  final GameConfig config;
  final RuleSet rules;
  final bool isFinished;
  final int firstDealerSeat;
  final int dealerOffset;
  final bool dealerIndicator;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? finishedAt;

  /// Oyuncular; `fromRound` değerleri el konumuna (1'den başlar) çevrilmiştir.
  final Seating seating;

  /// Sıra numarasına göre dizili eller.
  final List<StoredRound> rounds;
  final bool canUndo;

  GameRules get engine => rulesFor(config.template);

  Game get game => Game(
    config: config,
    rules: rules,
    rounds: [for (final r in rounds) r.round],
  );

  GameStatus get status => engine.evaluate(game);

  /// Kazanan yarışmacılar: motor oyunu bitmiş sayıyorsa onun kazananları;
  /// oyun "Oyunu Bitir" ile elle bitirildiyse o anki liderler. Sürüyorsa boş.
  List<int> get winners {
    final current = status;
    if (current.isFinished) return current.winners;
    return isFinished ? current.leaders : const [];
  }

  /// Sıradaki eli dağıtacak koltuk.
  int get nextDealerSeat => seating_rules.nextDealerSeat(
    seatCount: config.seatCount,
    firstDealerSeat: firstDealerSeat,
    roundsPlayed: rounds.length,
    offset: dealerOffset,
  );

  /// Bir sonraki elde oturanlar.
  List<String> get currentNames => seating.namesForRound(rounds.length + 1);
}

/// Bir oyunu okumanın sonucu.
sealed class GameLoad {
  const GameLoad();
}

class GameLoaded extends GameLoad {
  const GameLoaded(this.snapshot);
  final GameSnapshot snapshot;
}

class GameNotFound extends GameLoad {
  const GameNotFound(this.id);
  final int id;
}

/// Kayıt bozuk; uygulama çökmez, kullanıcıya "açılamadı" denir.
class GameUnreadable extends GameLoad {
  const GameUnreadable(this.id, this.error);
  final int id;
  final Object error;
}

/// Ana sayfa listesindeki bir oyun.
class GameSummary {
  const GameSummary({
    required this.id,
    required this.updatedAt,
    required this.isReadable,
    this.template,
    this.playMode = PlayMode.individual,
    this.playerNames = const [],
    this.roundsPlayed = 0,
    this.isFinished = false,
    this.status,
    this.winnerNames = const [],
  });

  final int id;
  final DateTime updatedAt;
  final bool isReadable;
  final GameTemplate? template;
  final PlayMode playMode;
  final List<String> playerNames;
  final int roundsPlayed;
  final bool isFinished;
  final GameStatus? status;

  /// Biten oyunda kazananlar (eşlide "Ayşe & Zeynep" biçiminde).
  final List<String> winnerNames;
}

/// Kaydedilemeyen oyuncu ismi.
class InvalidPlayerNameException implements Exception {
  const InvalidPlayerNameException(this.seat, this.error);
  final int seat;
  final NameError error;

  @override
  String toString() => 'InvalidPlayerNameException(seat: $seat, $error)';
}
