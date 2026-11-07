/// Sıradaki eli dağıtacak koltuk.
///
/// Dağıtıcı kaydedilmez, türetilir: ilk dağıtıcı + oynanan el sayısı +
/// elle değiştirme kaydırması. Böylece el silinince ya da geri alınınca
/// gösterge kendiliğinden doğru kalır.
int nextDealerSeat({
  required int seatCount,
  required int firstDealerSeat,
  required int roundsPlayed,
  int offset = 0,
}) {
  assert(seatCount > 0, 'seatCount pozitif olmalı');
  return (firstDealerSeat + roundsPlayed + offset) % seatCount;
}

/// Kullanıcı dağıtıcıyı elle [dealerSeat] yaptığında saklanacak kaydırma.
/// Her zaman 0 ile `seatCount - 1` arasındadır.
int dealerOffsetFor({
  required int seatCount,
  required int firstDealerSeat,
  required int roundsPlayed,
  required int dealerSeat,
}) {
  assert(seatCount > 0, 'seatCount pozitif olmalı');
  return (dealerSeat - firstDealerSeat - roundsPlayed) % seatCount;
}

/// Bir koltukta [fromRound]. elden itibaren oturan oyuncu (eller 1'den başlar).
class SeatOccupant {
  const SeatOccupant({
    required this.seat,
    required this.name,
    required this.fromRound,
  });

  final int seat;
  final String name;
  final int fromRound;

  SeatOccupant withName(String newName) =>
      SeatOccupant(seat: seat, name: newName, fromRound: fromRound);
}

/// Tabloda gösterilecek değişiklik notu: "[fromRound]. elden itibaren: from → to".
class SeatChange {
  const SeatChange({
    required this.seat,
    required this.fromRound,
    required this.from,
    required this.to,
  });

  final int seat;
  final int fromRound;
  final String from;
  final String to;
}

/// Koltuklar ve oturan oyuncular. Puanlar koltuğa bağlıdır; oyuncu
/// değişince koltuğun puanı aynen devam eder.
class Seating {
  Seating(Iterable<SeatOccupant> occupants)
    : occupants = List<SeatOccupant>.unmodifiable(
        <SeatOccupant>[...occupants]..sort((a, b) {
          final bySeat = a.seat.compareTo(b.seat);
          return bySeat != 0 ? bySeat : a.fromRound.compareTo(b.fromRound);
        }),
      );

  factory Seating.initial(List<String> names) => Seating([
    for (var seat = 0; seat < names.length; seat++)
      SeatOccupant(seat: seat, name: names[seat], fromRound: 1),
  ]);

  /// Koltuğa, sonra ele göre sıralı.
  final List<SeatOccupant> occupants;

  int get seatCount =>
      occupants.fold(0, (max, o) => o.seat + 1 > max ? o.seat + 1 : max);

  /// [roundNumber]. elde [seat] koltuğunda oturan.
  String nameAt(int seat, int roundNumber) =>
      _occupantAt(seat, roundNumber).name;

  List<String> namesForRound(int roundNumber) => [
    for (var seat = 0; seat < seatCount; seat++) nameAt(seat, roundNumber),
  ];

  /// Koltuğa yeni oyuncu oturtur; bir sonraki elden itibaren geçerlidir.
  Seating replace(int seat, String name, {required int roundsPlayed}) {
    final fromRound = roundsPlayed + 1;
    final rest = occupants
        .where((o) => !(o.seat == seat && o.fromRound == fromRound))
        .toList();
    // Aynı elden önce yapılmış değişiklik varsa yerine geçer; hiç el
    // oynanmadıysa ilk oturanın yerine geçer (not bırakmaz).
    final previous = _latestBefore(rest, seat, fromRound);
    // Eski oyuncu geri gelirse değişiklik satırına gerek yok.
    if (previous != null && previous.name == name) return Seating(rest);
    return Seating([
      ...rest,
      SeatOccupant(seat: seat, name: name, fromRound: fromRound),
    ]);
  }

  /// Koltukta şu an oturanın ismini düzeltir; değişiklik notu bırakmaz.
  Seating rename(int seat, String name, {required int roundsPlayed}) {
    final current = _occupantAt(seat, roundsPlayed + 1);
    return Seating([
      for (final o in occupants) identical(o, current) ? o.withName(name) : o,
    ]);
  }

  /// İlk el dışındaki oyuncu değişiklikleri, ele göre sıralı.
  List<SeatChange> changes() {
    final result = <SeatChange>[];
    for (final o in occupants) {
      if (o.fromRound <= 1) continue;
      final previous = _latestBefore(occupants, o.seat, o.fromRound);
      if (previous == null) continue;
      result.add(
        SeatChange(
          seat: o.seat,
          fromRound: o.fromRound,
          from: previous.name,
          to: o.name,
        ),
      );
    }
    result.sort((a, b) {
      final byRound = a.fromRound.compareTo(b.fromRound);
      return byRound != 0 ? byRound : a.seat.compareTo(b.seat);
    });
    return result;
  }

  SeatOccupant _occupantAt(int seat, int roundNumber) {
    final found = _latestBefore(occupants, seat, roundNumber + 1);
    if (found == null) {
      throw RangeError('Koltuk $seat için oyuncu yok');
    }
    return found;
  }

  /// [seat] koltuğunda [round]. elden önce başlamış en son oyuncu.
  static SeatOccupant? _latestBefore(
    List<SeatOccupant> list,
    int seat,
    int round,
  ) {
    SeatOccupant? latest;
    for (final o in list) {
      if (o.seat == seat &&
          o.fromRound < round &&
          (latest == null || o.fromRound > latest.fromRound)) {
        latest = o;
      }
    }
    return latest;
  }
}
