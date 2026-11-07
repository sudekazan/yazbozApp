import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/domain/seating.dart';

void main() {
  group('Dağıtıcı sırası', () {
    int next(
      int roundsPlayed, {
      int first = 0,
      int offset = 0,
      int seats = 4,
    }) => nextDealerSeat(
      seatCount: seats,
      firstDealerSeat: first,
      roundsPlayed: roundsPlayed,
      offset: offset,
    );

    test('ilk eli ilk dağıtıcı dağıtır', () {
      expect(next(0), 0);
      expect(next(0, first: 2), 2);
    });

    test('her el eklendiğinde oturma sırasına göre bir sonrakine geçer', () {
      expect([0, 1, 2, 3, 4, 5].map(next), [0, 1, 2, 3, 0, 1]);
    });

    test('3 kişilik masada döner', () {
      expect(next(4, first: 1, seats: 3), 2);
    });

    test('el silinince ya da geri alınınca gösterge de geri döner', () {
      expect(next(3), 3);
      expect(next(2), 2);
    });

    test('elle değiştirme sonraki ellerde de korunur', () {
      // 2 el oynandı, sıra 2. koltukta; kullanıcı 0. koltuğu seçti.
      final offset = dealerOffsetFor(
        seatCount: 4,
        firstDealerSeat: 0,
        roundsPlayed: 2,
        dealerSeat: 0,
      );
      expect(next(2, offset: offset), 0);
      expect(next(3, offset: offset), 1);
      // Elle değiştirmeden sonra bir el silinirse gösterge bir geri gider.
      expect(next(1, offset: offset), 3);
    });

    test('elle değiştirme geri alınınca eski sıraya döner', () {
      expect(next(2), 2);
    });

    test('ilk dağıtıcı sondaki koltuksa kaydırma negatife düşmez', () {
      final offset = dealerOffsetFor(
        seatCount: 4,
        firstDealerSeat: 3,
        roundsPlayed: 0,
        dealerSeat: 0,
      );
      expect(offset, inInclusiveRange(0, 3));
      expect(next(0, first: 3, offset: offset), 0);
    });
  });

  group('Koltuk ve oyuncu', () {
    Seating start() => Seating.initial(['Ayşe', 'Mehmet', 'Zeynep', 'Can']);

    test('başlangıçta herkes kendi koltuğunda', () {
      expect(start().namesForRound(1), ['Ayşe', 'Mehmet', 'Zeynep', 'Can']);
      expect(start().changes(), isEmpty);
    });

    test('oyuncu değiştirme bir sonraki elden itibaren geçerli olur', () {
      final seating = start().replace(3, 'Burak', roundsPlayed: 2);
      expect(seating.nameAt(3, 2), 'Can');
      expect(seating.nameAt(3, 3), 'Burak');
      expect(seating.namesForRound(5), ['Ayşe', 'Mehmet', 'Zeynep', 'Burak']);
    });

    test('değişiklik notu hangi elden kimin kime geçtiğini söyler', () {
      final seating = start().replace(3, 'Burak', roundsPlayed: 2);
      final change = seating.changes().single;
      expect(
        (change.seat, change.fromRound, change.from, change.to),
        (3, 3, 'Can', 'Burak'),
      );
    });

    test(
      'değiştirme koltuk numarasını değiştirmez, diğer koltuklar aynı kalır',
      () {
        final seating = start().replace(1, 'Elif', roundsPlayed: 4);
        expect(seating.seatCount, 4);
        expect(seating.nameAt(0, 5), 'Ayşe');
        expect(seating.nameAt(2, 5), 'Zeynep');
      },
    );

    test('hiç el oynanmadan değiştirme sadece ismi düzeltir, not bırakmaz', () {
      final seating = start().replace(0, 'Aylin', roundsPlayed: 0);
      expect(seating.nameAt(0, 1), 'Aylin');
      expect(seating.changes(), isEmpty);
    });

    test('aynı elden önce iki kez değiştirmede tek not kalır', () {
      final seating = start()
          .replace(2, 'Deniz', roundsPlayed: 3)
          .replace(2, 'Selin', roundsPlayed: 3);
      final change = seating.changes().single;
      expect((change.from, change.to), ('Zeynep', 'Selin'));
    });

    test('eski oyuncu geri getirilirse not silinir', () {
      final seating = start()
          .replace(2, 'Deniz', roundsPlayed: 3)
          .replace(2, 'Zeynep', roundsPlayed: 3);
      expect(seating.changes(), isEmpty);
      expect(seating.nameAt(2, 4), 'Zeynep');
    });

    test('ismi düzenlemek yazım hatasını düzeltir, not bırakmaz', () {
      final seating = start()
          .replace(3, 'Burak', roundsPlayed: 2)
          .rename(3, 'Burak K.', roundsPlayed: 5);
      expect(seating.nameAt(3, 6), 'Burak K.');
      expect(seating.nameAt(3, 1), 'Can');
      expect(seating.changes().single.to, 'Burak K.');
    });

    test('iki farklı elde iki değişiklik sırayla listelenir', () {
      final seating = start()
          .replace(0, 'Elif', roundsPlayed: 1)
          .replace(0, 'Kaan', roundsPlayed: 4);
      expect(seating.changes().map((c) => (c.fromRound, c.from, c.to)), [
        (2, 'Ayşe', 'Elif'),
        (5, 'Elif', 'Kaan'),
      ]);
    });
  });
}
