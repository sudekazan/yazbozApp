import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/domain/validation.dart';

void main() {
  group('Oyuncu ismi', () {
    test('boş isim reddedilir', () {
      expect(validatePlayerName(''), NameError.empty);
    });

    test('sadece boşluktan oluşan isim reddedilir', () {
      expect(validatePlayerName('   '), NameError.empty);
    });

    test('normal isim kabul edilir', () {
      expect(validatePlayerName('Ayşe'), isNull);
    });

    test('20 karakter kabul edilir, 21 reddedilir', () {
      expect(validatePlayerName('a' * 20), isNull);
      expect(validatePlayerName('a' * 21), NameError.tooLong);
    });

    test('baştaki ve sondaki boşluklar uzunluğa sayılmaz', () {
      expect(validatePlayerName('  ${'a' * 20}  '), isNull);
    });

    test('birleşik emoji tek karakter sayılır', () {
      const family = '👨‍👩‍👧‍👦';
      expect(validatePlayerName(family * 20), isNull);
      expect(validatePlayerName(family * 21), NameError.tooLong);
    });

    test('özel karakterli isim kabul edilir', () {
      expect(validatePlayerName("O'Neil & Çağrı-Ünal"), isNull);
    });

    test('satır sonu ve sekme boşluğa çevrilir, fazla boşluk tekilleşir', () {
      expect(normalizeName('  Ali\n\tVeli   Can '), 'Ali Veli Can');
    });

    test('görünmez kontrol karakterleri silinir', () {
      expect(normalizeName('Ay\u0000şe\u200B'), 'Ayşe');
    });
  });

  group('Grup ismi', () {
    test('30 karakter kabul edilir, 31 reddedilir', () {
      expect(validateGroupName('g' * 30), isNull);
      expect(validateGroupName('g' * 31), NameError.tooLong);
    });

    test('boş grup ismi reddedilir', () {
      expect(validateGroupName(' '), NameError.empty);
    });
  });

  group('Puan aralığı', () {
    test('±99.999 sınırı dahil kabul edilir', () {
      expect(isPointsInRange(99999), isTrue);
      expect(isPointsInRange(-99999), isTrue);
      expect(isPointsInRange(0), isTrue);
    });

    test('sınır dışı reddedilir', () {
      expect(isPointsInRange(100000), isFalse);
      expect(isPointsInRange(-100000), isFalse);
    });
  });
}
