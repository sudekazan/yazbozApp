import '../../data/repositories/game_models.dart';
import '../../domain/models/game_config.dart';
import '../../domain/seating.dart';

/// Tablonun bir sütunu: bir koltuk ya da bir takım (iki koltuk).
class ScoreColumn {
  const ScoreColumn({
    required this.seats,
    required this.names,
    required this.total,
    required this.isLeader,
    this.dealerSeat,
  });

  /// Bu sütunun koltukları, oturma sırasıyla.
  final List<int> seats;

  /// Koltuklarda şu an oturanlar; [seats] ile aynı sırada.
  final List<String> names;

  /// Başlangıç puanı dahil toplam.
  final int total;

  /// Tek başına lider mi (eşitlikte birden çok sütun lider olabilir).
  final bool isLeader;

  /// Sıradaki eli bu sütundaki hangi koltuk dağıtacak; dağıtıcı bu sütunda
  /// değilse ya da gösterge kapalıysa `null`.
  final int? dealerSeat;
}

/// Birden çok sütunu olan yarışmacının toplamı (eşli 101'de takım toplamı).
class TeamTotal {
  const TeamTotal({
    required this.names,
    required this.total,
    required this.isLeader,
  });

  final List<String> names;
  final int total;
  final bool isLeader;
}

/// Tablodaki bir satır: el ya da oyuncu değişikliği notu.
sealed class ScoreRow {
  const ScoreRow();
}

class RoundScoreRow extends ScoreRow {
  const RoundScoreRow({
    required this.roundId,
    required this.number,
    required this.points,
    required this.multiplier,
    required this.names,
  });

  final int roundId;

  /// Tabloda görünen el numarası (1'den başlar).
  final int number;

  /// Sütun sırasıyla puanlar.
  final List<int> points;

  /// 1'den büyükse "x2" gibi rozet gösterilir.
  final int multiplier;

  /// O elde her sütunda oturanlar; ekran okuyucu etiketi için.
  final List<List<String>> names;
}

class SeatChangeRow extends ScoreRow {
  const SeatChangeRow(this.change);

  final SeatChange change;
}

/// Skor tablosu ekranının ihtiyaç duyduğu her şey, oyunun anlık halinden
/// türetilir. Saf hesap; widget'tan bağımsız test edilir.
class ScoreboardView {
  const ScoreboardView({
    required this.columns,
    required this.teamTotals,
    required this.rows,
    required this.roundsPlayed,
    required this.isReadOnly,
    required this.isOver,
    required this.showsDealer,
    required this.target,
    required this.roundsLeft,
  });

  final List<ScoreColumn> columns;

  /// Takım toplamı ayrıca gösterilecekse dolu (eşli 101), değilse boş.
  final List<TeamTotal> teamTotals;

  /// Eller ve değişiklik notları, eskiden yeniye.
  final List<ScoreRow> rows;

  final int roundsPlayed;

  /// Oyun kesin bitti; tablo sadece okunur.
  final bool isReadOnly;

  /// Motor oyunu bitmiş sayıyor ya da oyun kesin bitti; "El Ekle" yerine
  /// "Sonucu Gör" çıkar.
  final bool isOver;

  /// Dağıtıcı göstergesi bu oyunda kullanılabilir mi (Tavla'da yok).
  final bool showsDealer;

  final int? target;
  final int? roundsLeft;
}

ScoreboardView buildScoreboard(GameSnapshot game) {
  final engine = game.engine;
  final config = game.config;
  final units = engine.units(config);
  final contenders = engine.contenders(config);
  final status = game.status;
  final played = game.rounds.length;
  final names = game.currentNames;
  final showsDealer = config.template != GameTemplate.tavla;
  final dealer = showsDealer && game.dealerIndicator && !game.isFinished
      ? game.nextDealerSeat
      : null;

  // Hiç el yokken ya da herkes eşitken lider gösterilmez.
  final leaders = played > 0 && status.leaders.length < contenders.length
      ? status.leaders.toSet()
      : const <int>{};
  bool leads(int contender) => leaders.contains(contender);

  final columns = [
    for (var unit = 0; unit < units.length; unit++)
      ScoreColumn(
        seats: units[unit].seats,
        names: [for (final seat in units[unit].seats) names[seat]],
        total: unit < status.unitTotals.length ? status.unitTotals[unit] : 0,
        isLeader: _singleUnitLeader(contenders, unit, leads),
        dealerSeat: dealer != null && units[unit].contains(dealer)
            ? dealer
            : null,
      ),
  ];

  final teamTotals = contenders.every((c) => c.length == 1)
      ? const <TeamTotal>[]
      : [
          for (final standing in [
            ...status.standings,
          ]..sort((a, b) => a.contender.compareTo(b.contender)))
            TeamTotal(
              names: [
                for (final unit in standing.units)
                  for (final seat in units[unit].seats) names[seat],
              ],
              total: standing.total,
              isLeader: leads(standing.contender),
            ),
        ];

  return ScoreboardView(
    columns: columns,
    teamTotals: teamTotals,
    rows: _rows(game, units),
    roundsPlayed: played,
    isReadOnly: game.isFinished,
    isOver: game.isFinished || status.isFinished,
    showsDealer: showsDealer,
    target: status.target,
    roundsLeft: status.roundsLeft,
  );
}

/// Sütun tek başına bir yarışmacıysa ve o lider ise `true`. Takım
/// toplamının ayrıca gösterildiği oyunlarda lider takım satırında görünür.
bool _singleUnitLeader(
  List<List<int>> contenders,
  int unit,
  bool Function(int contender) leads,
) {
  for (var c = 0; c < contenders.length; c++) {
    if (contenders[c].length == 1 && contenders[c].single == unit) {
      return leads(c);
    }
  }
  return false;
}

/// Eller sırayla; her oyuncu değişikliği notu, geçerli olduğu elin üstünde.
/// Sıradaki elden geçerli değişiklik en altta görünür.
List<ScoreRow> _rows(GameSnapshot game, List<ScoringUnit> units) {
  final changes = game.seating.changes();
  final rows = <ScoreRow>[];
  var next = 0;
  for (var i = 0; i < game.rounds.length; i++) {
    final number = i + 1;
    while (next < changes.length && changes[next].fromRound <= number) {
      rows.add(SeatChangeRow(changes[next++]));
    }
    final stored = game.rounds[i];
    rows.add(
      RoundScoreRow(
        roundId: stored.id,
        number: number,
        points: stored.round.result.points,
        multiplier: stored.round.result.multiplier,
        names: [
          for (final unit in units)
            [for (final seat in unit.seats) game.seating.nameAt(seat, number)],
        ],
      ),
    );
  }
  while (next < changes.length) {
    rows.add(SeatChangeRow(changes[next++]));
  }
  return rows;
}
