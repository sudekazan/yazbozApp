import '../models/game.dart';
import '../models/game_config.dart';
import '../models/game_status.dart';
import '../models/round.dart';
import '../models/rule_set.dart';
import '../validation.dart';

/// Her şablonun puan motorunun ortak arayüzü. UI'dan bağımsız, saf Dart.
///
/// Talimattaki `calculateRound(input, rules)` imzasına oyun kurulumu da
/// eklendi: eşli oyunda takım ve eş hesabı için gerekli.
abstract class GameRules {
  const GameRules();

  GameTemplate get template;

  /// Bu şablon verilen oyuncu sayısı ve oynanışla oynanabilir mi?
  bool supports(GameConfig config);

  RuleSet defaultRules(GameConfig config);

  /// Kayıtlı kural setini okur; eksik ya da bozuk alanlar varsayılana düşer.
  RuleSet ruleSetFromJson(Map<String, Object?> json);

  /// Kayıtlı el girdisini okur; bozuksa [FormatException] fırlatır.
  RoundInput roundInputFromJson(Map<String, Object?> json);

  /// Skor tablosunun sütunları.
  List<ScoringUnit> units(GameConfig config);

  /// Sıralamaya giren yarışmacılar (sütun numaralarıyla). Varsayılan: her
  /// sütun ayrı yarışmacı.
  List<List<int>> contenders(GameConfig config) => [
    for (var i = 0; i < units(config).length; i++) [i],
  ];

  /// Hataları döner; boşsa girdi geçerlidir.
  List<RoundError> validate(RoundInput input, RuleSet rules, GameConfig config);

  /// Geçerli girdinin puanlarını hesaplar; geçersizse
  /// [InvalidRoundException] fırlatır.
  RoundResult calculateRound(
    RoundInput input,
    RuleSet rules,
    GameConfig config,
  ) {
    final errors = validate(input, rules, config);
    if (errors.isNotEmpty) throw InvalidRoundException(errors);
    return scoreValidRound(input, rules, config);
  }

  /// [validate]'ten geçmiş girdinin puanları. Doğrudan çağrılmamalı.
  RoundResult scoreValidRound(
    RoundInput input,
    RuleSet rules,
    GameConfig config,
  );

  GameStatus evaluate(Game game);
}

/// Her sütunun toplamı: başlangıç puanı + ellerin puanları. Bozuk kayıtlarda
/// eksik puan 0 sayılır, fazla puan yok sayılır.
List<int> unitTotals(Game game, int unitCount, {int start = 0}) {
  final totals = List<int>.filled(unitCount, start);
  for (final round in game.rounds) {
    final points = round.result.points;
    for (var i = 0; i < unitCount && i < points.length; i++) {
      totals[i] += points[i];
    }
  }
  return totals;
}

/// Sıralamada birinci tek mi? Hedefli oyunlarda eşitlik oyunu sürdürür.
bool hasSingleLeader(List<Standing> standings) =>
    standings.where((s) => s.rank == 1).length == 1;

/// Sütun puanlarının sayısı ve aralığı denetimi.
List<RoundError> validatePointList(List<int> points, int unitCount) {
  if (points.length != unitCount) {
    return [
      RoundError(
        RoundErrorCode.wrongUnitCount,
        expected: unitCount,
        actual: points.length,
      ),
    ];
  }
  return [
    for (var unit = 0; unit < points.length; unit++)
      if (!isPointsInRange(points[unit]))
        RoundError(RoundErrorCode.pointsOutOfRange, unit: unit),
  ];
}

/// Motorun beklediği türde değilse açıklayıcı hata fırlatır.
T expectType<T>(Object value) {
  if (value is! T) {
    throw ArgumentError.value(value, 'value', '$T bekleniyordu');
  }
  return value as T;
}
