import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Uygulamanın yerel SQLite veritabanı.
///
/// Şema değiştiğinde [schemaVersion] artırılır, `drift_schemas/` altına yeni
/// döküm alınır (`dart run drift_dev make-migrations`) ve geçiş testi yazılır.
@DriftDatabase(
  tables: [
    Games,
    SeatOccupants,
    Rounds,
    UndoActions,
    PlayerGroups,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDefault());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      // SQLite yabancı anahtarları varsayılan olarak denetlemez.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openDefault() => driftDatabase(name: 'yazboz');
}
