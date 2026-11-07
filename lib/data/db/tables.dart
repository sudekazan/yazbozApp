import 'package:drift/drift.dart';

/// Oyunlar. Şablon, oynanış ve durum metin olarak saklanır; bilinmeyen bir
/// değer okunursa oyun "açılamadı" sayılır, uygulama çökmez.
@DataClassName('GameRow')
class Games extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `GameTemplate.name` (ör. `okey101`).
  TextColumn get template => text()();

  /// `PlayMode.name`: `individual` ya da `pairs`.
  TextColumn get playMode => text()();
  IntColumn get seatCount => integer()();

  /// Kural seti (`RuleSet.toJson`).
  TextColumn get rulesJson => text()();

  /// `active` ya da `finished`.
  TextColumn get status => text()();
  IntColumn get firstDealerSeat => integer().withDefault(const Constant(0))();

  /// Dağıtıcı elle değiştirildiyse kaydırma; dağıtıcı bundan türetilir.
  IntColumn get dealerOffset => integer().withDefault(const Constant(0))();
  BoolColumn get dealerIndicator =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  /// Kaydırarak silinip "Geri Al" beklenen oyunlar; sonra kalıcı silinir.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Koltukta hangi oyuncunun hangi elden itibaren oturduğu. Puanlar koltuğa
/// bağlıdır. İsim uzunluğu domain katmanında (emoji dahil) denetlenir.
@DataClassName('SeatOccupantRow')
class SeatOccupants extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get gameId =>
      integer().references(Games, #id, onDelete: KeyAction.cascade)();
  IntColumn get seat => integer()();
  TextColumn get playerName => text()();

  /// 1'den başlar.
  IntColumn get fromRound => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {gameId, seat, fromRound},
  ];
}

/// Eller: ham girdi ve hesaplanmış puanlar birlikte saklanır.
@DataClassName('RoundRow')
class Rounds extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get gameId =>
      integer().references(Games, #id, onDelete: KeyAction.cascade)();

  /// Oynanma sırası. Silinen el geri alınınca aynı numarayla döner.
  IntColumn get sequence => integer()();

  /// `RoundInput.toJson`.
  TextColumn get inputJson => text()();

  /// Her sütunun puanı (JSON liste).
  TextColumn get pointsJson => text()();
  IntColumn get multiplier => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {gameId, sequence},
  ];
}

/// Geri alınabilir son işlemler (oyun başına sınırlı sayıda).
@DataClassName('UndoActionRow')
@TableIndex(name: 'undo_actions_game', columns: {#gameId})
class UndoActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get gameId =>
      integer().references(Games, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Kayıtlı oyuncu grupları ("Ailem" gibi).
@DataClassName('PlayerGroupRow')
class PlayerGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Oturma sırasıyla isimler (JSON liste).
  TextColumn get membersJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Uygulama ayarları; tek satır (id = 1).
@DataClassName('AppSettingsRow')
class AppSettings extends Table {
  IntColumn get id => integer()();

  /// `system`, `light` ya da `dark`.
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  BoolColumn get keepScreenOn => boolean().withDefault(const Constant(true))();
  BoolColumn get haptics => boolean().withDefault(const Constant(true))();
  BoolColumn get dealerIndicatorDefault =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
