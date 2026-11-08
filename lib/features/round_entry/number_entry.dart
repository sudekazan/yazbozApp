import '../common/score_format.dart';

/// Tuş takımıyla yazılan tek bir sayı alanı. Saf hesap; widget'tan
/// bağımsız test edilir.
class NumberEntry {
  const NumberEntry({this.negative = false, this.digits = ''});

  factory NumberEntry.fromValue(int value) =>
      NumberEntry(negative: value < 0, digits: '${value.abs()}');

  /// 5 basamak: puan sınırı ±99.999 kendiliğinden korunur.
  static const int maxDigits = 5;

  final bool negative;
  final String digits;

  bool get isEmpty => digits.isEmpty;

  /// Boş alan 0 sayılır.
  int get value {
    if (digits.isEmpty) return 0;
    final number = int.parse(digits);
    return negative ? -number : number;
  }

  /// Ekranda görünen hali: "−12", sadece eksi yazıldıysa "−".
  String get display =>
      digits.isEmpty ? (negative ? '−' : '') : formatPoints(value);

  NumberEntry addDigit(int digit) {
    assert(digit >= 0 && digit <= 9, 'Rakam 0-9 olmalı');
    if (digits == '0') return NumberEntry(negative: negative, digits: '$digit');
    if (digits.length >= maxDigits) return this;
    return NumberEntry(negative: negative, digits: '$digits$digit');
  }

  NumberEntry toggleSign() => NumberEntry(negative: !negative, digits: digits);

  /// Son rakamı siler; rakam kalmadıysa eksi işaretini kaldırır.
  NumberEntry backspace() => digits.isEmpty
      ? const NumberEntry()
      : NumberEntry(
          negative: negative,
          digits: digits.substring(0, digits.length - 1),
        );
}
