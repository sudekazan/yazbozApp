import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/features/round_entry/number_entry.dart';

NumberEntry type(String keys) {
  var entry = const NumberEntry();
  for (final key in keys.split('')) {
    entry = switch (key) {
      '-' => entry.toggleSign(),
      '<' => entry.backspace(),
      _ => entry.addDigit(int.parse(key)),
    };
  }
  return entry;
}

void main() {
  test('boş alan 0 sayılır ve boş görünür', () {
    expect(type('').value, 0);
    expect(type('').display, '');
  });

  test('rakamlar sırayla eklenir', () {
    expect(type('125').value, 125);
    expect(type('125').display, '125');
  });

  test('eksi işareti önce ya da sonra basılabilir', () {
    expect(type('-12').value, -12);
    expect(type('12-').value, -12);
    expect(type('12--').value, 12);
    expect(type('-').display, '−');
    expect(type('-12').display, '−12');
  });

  test('baştaki sıfır yerini yeni rakama bırakır', () {
    expect(type('07').digits, '7');
    expect(type('00').digits, '0');
  });

  test('en fazla 5 basamak yazılır (±99.999)', () {
    expect(type('1234567').value, 12345);
    expect(type('-999999').value, -99999);
  });

  test('silme son rakamı, rakam kalmazsa eksiyi kaldırır', () {
    expect(type('123<').value, 12);
    expect(type('-1<').display, '−');
    expect(type('-1<<').negative, isFalse);
    expect(type('<').isEmpty, isTrue);
  });

  test('kayıtlı değerden geri yüklenir', () {
    expect(NumberEntry.fromValue(-40).display, '−40');
    expect(NumberEntry.fromValue(0).value, 0);
  });
}
