import 'package:characters/characters.dart';

/// Kullanıcı girdisi sınırları.
abstract final class Limits {
  static const int maxPlayerNameLength = 20;
  static const int maxGroupNameLength = 30;

  /// Bir puanın mutlak değeri bunu geçemez.
  static const int maxAbsPoints = 99999;
}

enum NameError { empty, tooLong }

/// Görünmez kontrol karakterleri. Birleşik emojilerin parçası olan
/// sıfır genişlikli birleştirici (U+200D) bilerek dışarıda bırakıldı.
final _invisible = RegExp(
  '[\u0000-\u0008\u000E-\u001F\u007F\u200B\u2060\uFEFF]',
);
final _whitespace = RegExp(r'\s+');

/// İsmi kaydetmeye hazır hale getirir: kontrol karakterlerini siler,
/// satır sonu ve sekmeleri boşluğa çevirir, fazla boşlukları tekilleştirir.
String normalizeName(String raw) =>
    raw.replaceAll(_invisible, '').replaceAll(_whitespace, ' ').trim();

NameError? validatePlayerName(String raw) =>
    _validateName(raw, Limits.maxPlayerNameLength);

NameError? validateGroupName(String raw) =>
    _validateName(raw, Limits.maxGroupNameLength);

NameError? _validateName(String raw, int maxLength) {
  final name = normalizeName(raw);
  if (name.isEmpty) return NameError.empty;
  // Emoji ve birleşik harfler tek karakter sayılır.
  if (name.characters.length > maxLength) return NameError.tooLong;
  return null;
}

bool isPointsInRange(int value) => value.abs() <= Limits.maxAbsPoints;
