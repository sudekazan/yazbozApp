/// Oyun şablonları. `name` veritabanında ve adreslerde kimlik olarak kullanılır;
/// değiştirilmemeli.
enum GameTemplate {
  free,
  okey,
  okey101,
  tavla,
  pisti,
  batak;

  static GameTemplate? fromName(String name) {
    for (final template in values) {
      if (template.name == name) return template;
    }
    return null;
  }
}

enum PlayMode { individual, pairs }

/// Skor tablosundaki bir sütun: bir koltuk ya da bir takım (iki koltuk).
class ScoringUnit {
  const ScoringUnit(this.seats);

  final List<int> seats;

  bool contains(int seat) => seats.contains(seat);
}

/// Oyunun kurulum bilgisi: şablon, koltuk sayısı, bireysel ya da eşli.
///
/// Eşli oyunda eşler karşılıklı oturur: 0 ile 2, 1 ile 3 aynı takımdadır.
class GameConfig {
  const GameConfig({
    required this.template,
    required this.seatCount,
    this.playMode = PlayMode.individual,
  });

  static const int minSeats = 2;
  static const int maxSeats = 8;

  final GameTemplate template;
  final int seatCount;
  final PlayMode playMode;

  bool get isPairs => playMode == PlayMode.pairs;

  bool get isValid =>
      seatCount >= minSeats &&
      seatCount <= maxSeats &&
      (!isPairs || seatCount == 4);

  int? teamOf(int seat) => isPairs ? seat % 2 : null;

  int? partnerOf(int seat) => isPairs ? (seat + 2) % 4 : null;

  /// Her koltuk ayrı bir sütun.
  List<ScoringUnit> seatUnits() =>
      List.generate(seatCount, (seat) => ScoringUnit([seat]));

  /// Her takım bir sütun: [0, 2] ve [1, 3].
  List<ScoringUnit> teamUnits() => List.generate(
    2,
    (team) => ScoringUnit([
      for (var seat = 0; seat < seatCount; seat++)
        if (seat % 2 == team) seat,
    ]),
  );
}
