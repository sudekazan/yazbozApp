/// Bir yarışmacının (oyuncu ya da takım) anlık durumu.
class Standing {
  const Standing({
    required this.contender,
    required this.units,
    required this.total,
    required this.rank,
  });

  /// Yarışmacı sırası (kurulumdaki sıra).
  final int contender;

  /// Bu yarışmacıya ait sütunlar.
  final List<int> units;

  final int total;

  /// 1'den başlar; eşit toplamlar aynı sırayı paylaşır (1, 1, 3...).
  final int rank;
}

/// Yarışmacıları toplamlarına göre sıralar. Bir yarışmacının toplamı,
/// sütunlarının toplamıdır (eşli 101'de iki oyuncunun toplamı gibi).
List<Standing> rankStandings({
  required List<List<int>> contenders,
  required List<int> unitTotals,
  required bool higherIsBetter,
}) {
  final totals = [
    for (final units in contenders)
      units.fold<int>(0, (sum, unit) => sum + unitTotals[unit]),
  ];
  bool better(int a, int b) => higherIsBetter ? a > b : a < b;

  final standings = [
    for (var i = 0; i < contenders.length; i++)
      Standing(
        contender: i,
        units: contenders[i],
        total: totals[i],
        rank: 1 + totals.where((other) => better(other, totals[i])).length,
      ),
  ];
  standings.sort((a, b) {
    final byRank = a.rank.compareTo(b.rank);
    return byRank != 0 ? byRank : a.contender.compareTo(b.contender);
  });
  return standings;
}

/// Oyunun durumu: sürüyor mu, sıralama, lider ve kazanan.
class GameStatus {
  const GameStatus({
    required this.isFinished,
    required this.standings,
    this.target,
    this.roundsLeft,
  });

  final bool isFinished;

  /// Sıraya göre dizili.
  final List<Standing> standings;

  /// Hedef puanla oynanıyorsa hedef; yoksa `null`.
  final int? target;

  /// El sayısıyla oynanıyorsa kalan el; yoksa `null`.
  final int? roundsLeft;

  /// Şu an birinci olan yarışmacılar (eşitlikte birden fazla).
  List<int> get leaders => [
    for (final standing in standings)
      if (standing.rank == 1) standing.contender,
  ];

  /// Oyun bittiyse kazananlar; sürüyorsa boş.
  List<int> get winners => isFinished ? leaders : const [];
}
