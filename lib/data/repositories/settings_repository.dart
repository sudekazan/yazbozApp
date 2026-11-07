import 'package:drift/drift.dart';

import '../db/app_database.dart';

enum AppThemeMode { system, light, dark }

/// Uygulama ayarları. Varsayılanlar talimattaki gibi: tema sistemden,
/// ekran açık, titreşim ve dağıtıcı göstergesi açık.
class AppSettingsData {
  const AppSettingsData({
    this.themeMode = AppThemeMode.system,
    this.keepScreenOn = true,
    this.haptics = true,
    this.dealerIndicatorDefault = true,
  });

  final AppThemeMode themeMode;
  final bool keepScreenOn;
  final bool haptics;

  /// Yeni oyunlarda dağıtıcı göstergesi açık mı (oyun bazında değiştirilir).
  final bool dealerIndicatorDefault;

  AppSettingsData copyWith({
    AppThemeMode? themeMode,
    bool? keepScreenOn,
    bool? haptics,
    bool? dealerIndicatorDefault,
  }) => AppSettingsData(
    themeMode: themeMode ?? this.themeMode,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    haptics: haptics ?? this.haptics,
    dealerIndicatorDefault:
        dealerIndicatorDefault ?? this.dealerIndicatorDefault,
  );
}

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  /// Ayarlar tek satırda tutulur.
  static const int _rowId = 1;

  SimpleSelectStatement<$AppSettingsTable, AppSettingsRow> get _query =>
      _db.select(_db.appSettings)..where((s) => s.id.equals(_rowId));

  Future<AppSettingsData> load() async =>
      _fromRow(await _query.getSingleOrNull());

  /// Satır yoksa varsayılanları yayınlar.
  Stream<AppSettingsData> watch() => _query.watchSingleOrNull().map(_fromRow);

  Future<void> save(AppSettingsData settings) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          id: const Value(_rowId),
          themeMode: Value(settings.themeMode.name),
          keepScreenOn: Value(settings.keepScreenOn),
          haptics: Value(settings.haptics),
          dealerIndicatorDefault: Value(settings.dealerIndicatorDefault),
        ),
      );

  AppSettingsData _fromRow(AppSettingsRow? row) {
    if (row == null) return const AppSettingsData();
    return AppSettingsData(
      themeMode: AppThemeMode.values.firstWhere(
        (m) => m.name == row.themeMode,
        orElse: () => AppThemeMode.system,
      ),
      keepScreenOn: row.keepScreenOn,
      haptics: row.haptics,
      dealerIndicatorDefault: row.dealerIndicatorDefault,
    );
  }
}
