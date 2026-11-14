import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/db/app_database.dart';
import '../data/repositories/game_models.dart';
import '../data/repositories/game_repository.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/settings_repository.dart';

part 'providers.g.dart';

/// Uygulama boyunca tek veritabanı bağlantısı. Testlerde bellekte bir
/// veritabanıyla değiştirilir.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
GameRepository gameRepository(Ref ref) =>
    GameRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
GroupRepository groupRepository(Ref ref) =>
    GroupRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(appDatabaseProvider));

@riverpod
Stream<AppSettingsData> appSettings(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watch();

/// Ana sayfadaki oyunlar (devam eden ve biten).
@riverpod
Stream<List<GameSummary>> gameSummaries(Ref ref) =>
    ref.watch(gameRepositoryProvider).watchGames();

@riverpod
Stream<GameLoad> gameById(Ref ref, int id) =>
    ref.watch(gameRepositoryProvider).watchGame(id);

@riverpod
Stream<List<PlayerGroup>> playerGroups(Ref ref) =>
    ref.watch(groupRepositoryProvider).watchGroups();

@riverpod
Future<List<String>> nameSuggestions(Ref ref) =>
    ref.watch(gameRepositoryProvider).nameSuggestions();
