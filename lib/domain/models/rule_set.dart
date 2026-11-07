import 'game_config.dart';

/// Kural ayarında bir hata (ör. hedef puan sıfır).
class RuleError {
  const RuleError(this.field);

  /// Hatalı alanın JSON adı (ör. `target`).
  final String field;

  @override
  String toString() => 'RuleError($field)';
}

/// Bir şablonun düzenlenebilir puan değerleri. Değerler koda gömülmez;
/// her oyun kendi kural setini saklar.
abstract class RuleSet {
  const RuleSet();

  /// JSON biçiminin sürümü; alan eklendikçe artar.
  static const int jsonVersion = 1;

  GameTemplate get template;

  Map<String, Object?> toJson();

  /// Kullanıcının düzenlediği değerlerin denetimi.
  List<RuleError> validate();
}
