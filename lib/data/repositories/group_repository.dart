import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/game_config.dart';
import '../../domain/validation.dart';
import '../db/app_database.dart';

/// Kayıtlı oyuncu grubu ("Ailem" gibi); kurulumda tek dokunuşla isimleri
/// doldurur.
class PlayerGroup {
  const PlayerGroup({
    required this.id,
    required this.name,
    required this.members,
    required this.updatedAt,
  });

  final int id;
  final String name;

  /// Oturma sırasıyla isimler.
  final List<String> members;
  final DateTime updatedAt;
}

enum GroupProblem { name, member, memberCount }

/// Kaydedilemeyen grup: ismi, bir üyesi ya da üye sayısı geçersiz.
class InvalidGroupException implements Exception {
  const InvalidGroupException(this.problem, {this.memberIndex, this.nameError});

  final GroupProblem problem;
  final int? memberIndex;
  final NameError? nameError;

  @override
  String toString() =>
      'InvalidGroupException($problem, member: $memberIndex, $nameError)';
}

class GroupRepository {
  GroupRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Son kullanılan ya da düzenlenen önce. Bozuk kayıtlar atlanır.
  Stream<List<PlayerGroup>> watchGroups() =>
      (_db.select(_db.playerGroups)..orderBy([
            (g) => OrderingTerm.desc(g.updatedAt),
            (g) => OrderingTerm.desc(g.id),
          ]))
          .watch()
          .map(
            (rows) => [
              for (final row in rows)
                if (_members(row.membersJson) case final members?)
                  PlayerGroup(
                    id: row.id,
                    name: row.name,
                    members: members,
                    updatedAt: row.updatedAt,
                  ),
            ],
          );

  Future<int> createGroup(String name, List<String> members) async {
    final clean = _validate(name, members);
    final now = _clock();
    return _db
        .into(_db.playerGroups)
        .insert(
          PlayerGroupsCompanion.insert(
            name: clean.name,
            membersJson: jsonEncode(clean.members),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> updateGroup(
    int id, {
    required String name,
    required List<String> members,
  }) async {
    final clean = _validate(name, members);
    await (_db.update(_db.playerGroups)..where((g) => g.id.equals(id))).write(
      PlayerGroupsCompanion(
        name: Value(clean.name),
        membersJson: Value(jsonEncode(clean.members)),
        updatedAt: Value(_clock()),
      ),
    );
  }

  Future<void> deleteGroup(int id) =>
      (_db.delete(_db.playerGroups)..where((g) => g.id.equals(id))).go();

  /// Grup kurulumda kullanılınca listede öne çıkar.
  Future<void> markUsed(int id) =>
      (_db.update(_db.playerGroups)..where((g) => g.id.equals(id))).write(
        PlayerGroupsCompanion(updatedAt: Value(_clock())),
      );

  ({String name, List<String> members}) _validate(
    String name,
    List<String> members,
  ) {
    final nameError = validateGroupName(name);
    if (nameError != null) {
      throw InvalidGroupException(GroupProblem.name, nameError: nameError);
    }
    if (members.length < GameConfig.minSeats ||
        members.length > GameConfig.maxSeats) {
      throw const InvalidGroupException(GroupProblem.memberCount);
    }
    for (var i = 0; i < members.length; i++) {
      final error = validatePlayerName(members[i]);
      if (error != null) {
        throw InvalidGroupException(
          GroupProblem.member,
          memberIndex: i,
          nameError: error,
        );
      }
    }
    return (
      name: normalizeName(name),
      members: [for (final m in members) normalizeName(m)],
    );
  }

  List<String>? _members(String text) {
    try {
      final value = jsonDecode(text);
      if (value is List && value.every((e) => e is String)) {
        return List.unmodifiable(value.cast<String>());
      }
    } on FormatException {
      // Bozuk kayıt listede gösterilmez.
    }
    return null;
  }
}
