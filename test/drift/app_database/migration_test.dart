import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/data/db/app_database.dart';

import 'generated/schema.dart';

/// Şema değiştiğinde: `schemaVersion` artırılır, yeni döküm alınır
/// (`dart run drift_dev make-migrations`) ve buraya eski sürümden yeniye
/// verinin korunduğunu gösteren bir test eklenir.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('güncel şema sürümünün dökümü repoda var', () {
    final version = AppDatabase(DatabaseConnection(_unusedExecutor))
        .schemaVersion;
    final dump = File('drift_schemas/app_database/drift_schema_v$version.json');
    expect(
      dump.existsSync(),
      isTrue,
      reason: 'Şema değişti ama döküm alınmadı: make-migrations çalıştır',
    );
  });

  test('koddaki şema son dökümle aynı', () async {
    final current = AppDatabase(DatabaseConnection(_unusedExecutor))
        .schemaVersion;
    final schema = await verifier.schemaAt(current);
    final db = AppDatabase(schema.newConnection());
    await db.validateDatabaseSchema();
    await db.close();
  });

  test('eski her sürümden güncel şemaya geçiş tanımlı', () async {
    final current = AppDatabase(DatabaseConnection(_unusedExecutor))
        .schemaVersion;
    for (var from = 1; from < current; from++) {
      final schema = await verifier.schemaAt(from);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, current);
      await db.close();
    }
  });
}

/// Sadece `schemaVersion` okumak için; hiçbir sorgu çalıştırmaz.
final _unusedExecutor = LazyDatabase(
  () => throw StateError('Bu bağlantı kullanılmamalı'),
);
