import 'game_config.dart';

/// Bir elin ham girdisi (Pişti'de sayaçlar, Batak'ta ihale gibi).
///
/// Ham girdi saklanır; el düzenlenince puan bundan yeniden hesaplanır.
/// Her şablon kendi alt sınıfını tanımlar.
abstract class RoundInput {
  const RoundInput();

  GameTemplate get template;

  /// JSON'daki `type` alanı; şablonun girdi türünü ayırt eder.
  String get type;

  Map<String, Object?> toJson();
}

/// Bir elin hesaplanmış sonucu: her sütun için bir puan.
class RoundResult {
  const RoundResult(this.points, {this.multiplier = 1});

  final List<int> points;

  /// Tabloda gösterilecek el çarpanı (101'de x2, x4). Çarpan yoksa 1.
  final int multiplier;
}

/// Kayıtlı bir el: ham girdi ve hesaplanmış sonuç.
class Round {
  const Round({required this.input, required this.result});

  final RoundInput input;
  final RoundResult result;
}

enum RoundErrorCode {
  /// Girdideki sütun/oyuncu sayısı oyunla uyuşmuyor.
  wrongUnitCount,

  /// Puan ±99.999 dışında.
  pointsOutOfRange,

  /// Seçilen koltuk oyunda yok.
  seatOutOfRange,

  /// Seçilen sütun (oyuncu/takım) oyunda yok.
  unitOutOfRange,

  /// Bitiş biçimi seçildi ama bitiren seçilmedi.
  finishWithoutFinisher,

  /// 101: kalan taş toplamı geçersiz.
  remainingOutOfRange,

  /// Ceza tutarı geçersiz.
  penaltyAmountOutOfRange,

  /// Sayaç negatif ya da çok büyük.
  countOutOfRange,

  /// Pişti: As toplamı 4'ü geçiyor.
  acesOverLimit,

  /// Pişti: Vale toplamı 4'ü geçiyor.
  jacksOverLimit,

  /// Pişti: Sinek 2'yi alan seçilmedi.
  clubTwoOwnerRequired,

  /// Pişti: Karo 10'u alan seçilmedi.
  diamondTenOwnerRequired,

  /// Tavla: katlama küpü değeri geçersiz.
  cubeInvalid,

  /// Batak: ihaleyi alan seçilmedi.
  bidderRequired,

  /// Batak: ihale miktarı aralık dışında.
  bidOutOfRange,

  /// Batak: bir oyuncunun el sayısı aralık dışında.
  tricksOutOfRange,

  /// Batak: el sayılarının toplamı dağıtımdaki el sayısına eşit değil.
  tricksTotalMismatch,
}

/// El girişindeki bir hata. Arayüz mesajı bu bilgilerden kurar
/// ("Toplam el sayısı 13 olmalı, şu an 12").
class RoundError {
  const RoundError(
    this.code, {
    this.unit,
    this.seat,
    this.expected,
    this.actual,
  });

  final RoundErrorCode code;
  final int? unit;
  final int? seat;
  final int? expected;
  final int? actual;

  @override
  String toString() =>
      'RoundError($code, unit: $unit, seat: $seat, '
      'expected: $expected, actual: $actual)';
}

/// Geçersiz girdi hesaplanmak istendiğinde fırlatılır.
class InvalidRoundException implements Exception {
  const InvalidRoundException(this.errors);

  final List<RoundError> errors;

  @override
  String toString() => 'InvalidRoundException($errors)';
}
