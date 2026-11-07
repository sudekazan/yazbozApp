/// JSON okuma yardımcıları.
///
/// Kural setleri hoşgörülü okunur (eksik/bozuk alan varsayılana düşer);
/// el girdileri katı okunur (bozuksa [FormatException]).
library;

int readInt(Map<String, Object?> json, String key, int fallback) {
  final value = json[key];
  return value is int ? value : fallback;
}

int? readIntOrNull(Map<String, Object?> json, String key, int? fallback) {
  if (!json.containsKey(key)) return fallback;
  final value = json[key];
  return value is int ? value : fallback;
}

bool readBool(Map<String, Object?> json, String key, bool fallback) {
  final value = json[key];
  return value is bool ? value : fallback;
}

T readEnum<T extends Enum>(
  Map<String, Object?> json,
  String key,
  List<T> values,
  T fallback,
) {
  final value = json[key];
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  return fallback;
}

int requireInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('"$key" tam sayı olmalı', value);
}

int? requireIntOrNull(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is int) return value as int?;
  throw FormatException('"$key" tam sayı ya da boş olmalı', value);
}

bool requireBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('"$key" doğru/yanlış olmalı', value);
}

List<int> requireIntList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is List && value.every((e) => e is int)) {
    return List<int>.unmodifiable(value.cast<int>());
  }
  throw FormatException('"$key" tam sayı listesi olmalı', value);
}

List<Map<String, Object?>> requireObjectList(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value is List && value.every((e) => e is Map<String, Object?>)) {
    return value.cast<Map<String, Object?>>();
  }
  throw FormatException('"$key" nesne listesi olmalı', value);
}

T requireEnum<T extends Enum>(
  Map<String, Object?> json,
  String key,
  List<T> values,
) {
  final value = json[key];
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  throw FormatException('"$key" geçersiz', value);
}

void requireType(Map<String, Object?> json, String type) {
  if (json['type'] != type) {
    throw FormatException('Beklenen tür "$type"', json['type']);
  }
}
