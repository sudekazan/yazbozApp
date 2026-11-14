import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/data/db/app_database.dart';
import 'package:yazboz/data/repositories/game_models.dart';
import 'package:yazboz/data/repositories/game_repository.dart';
import 'package:yazboz/domain/models/game_config.dart';
import 'package:yazboz/domain/models/rule_set.dart';
import 'package:yazboz/domain/rules/free_rules.dart';
import 'package:yazboz/domain/rules/okey101_rules.dart';
import 'package:yazboz/domain/rules/okey_rules.dart';
import 'package:yazboz/domain/rules/tavla_rules.dart';
import 'package:yazboz/features/scoreboard/scoreboard_logic.dart';

void main() {
  late AppDatabase db;
  late GameRepository repo;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    repo = GameRepository(db);
  });
  tearDown(() => db.close());

  Future<int> create(
    GameConfig config,
    RuleSet rules,
    List<String> names, {
    int firstDealerSeat = 0,
  }) => repo.createGame(
    config: config,
    rules: rules,
    playerNames: names,
    firstDealerSeat: firstDealerSeat,
  );

  Future<int> free(List<String> names, {int? target}) => create(
    GameConfig(template: GameTemplate.free, seatCount: names.length),
    FreeRuleSet(target: target),
    names,
  );

  Future<ScoreboardView> view(int id) async {
    final load = await repo.loadGame(id);
    return buildScoreboard((load as GameLoaded).snapshot);
  }

  group('Sütunlar', () {
    test('hiç el yokken lider gösterilmez', () async {
      final id = await free(['Ayşe', 'Mehmet']);
      final v = await view(id);
      expect(v.columns.map((c) => c.isLeader), [false, false]);
      expect(v.columns.map((c) => c.total), [0, 0]);
    });

    test('en iyi toplam lider olur', () async {
      final id = await free(['Ayşe', 'Mehmet', 'Can']);
      await repo.addRound(id, const FreeRoundInput([5, 9, 1]));
      final v = await view(id);
      expect(v.columns.map((c) => c.isLeader), [false, true, false]);
      expect(v.columns.map((c) => c.total), [5, 9, 1]);
    });

    test(
      'herkes eşitse lider gösterilmez, iki kişi eşitse ikisi lider',
      () async {
        final id = await free(['Ayşe', 'Mehmet', 'Can']);
        await repo.addRound(id, const FreeRoundInput([3, 3, 3]));
        expect((await view(id)).columns.where((c) => c.isLeader), isEmpty);

        await repo.addRound(id, const FreeRoundInput([2, 2, 0]));
        expect((await view(id)).columns.map((c) => c.isLeader), [
          true,
          true,
          false,
        ]);
      },
    );

    test('Okey toplamı başlangıç puanını içerir', () async {
      final id = await create(
        const GameConfig(template: GameTemplate.okey, seatCount: 4),
        const OkeyRuleSet(),
        ['A', 'B', 'C', 'D'],
      );
      await repo.addRound(id, const OkeyRoundInput(finisherSeat: 2));
      final v = await view(id);
      expect(v.columns.map((c) => c.total), [18, 18, 20, 18]);
    });

    test('dağıtıcı sıradaki eli dağıtacak koltuğun sütununda', () async {
      final id = await create(
        const GameConfig(template: GameTemplate.free, seatCount: 3),
        const FreeRuleSet(),
        ['Ayşe', 'Mehmet', 'Can'],
        firstDealerSeat: 1,
      );
      expect((await view(id)).columns.map((c) => c.dealerSeat), [
        null,
        1,
        null,
      ]);

      await repo.addRound(id, const FreeRoundInput([1, 1, 1]));
      expect((await view(id)).columns.map((c) => c.dealerSeat), [
        null,
        null,
        2,
      ]);

      await repo.setDealerIndicator(id, enabled: false);
      expect((await view(id)).columns.map((c) => c.dealerSeat), [
        null,
        null,
        null,
      ]);
    });

    test('Tavla\'da dağıtıcı gösterilmez', () async {
      final id = await create(
        const GameConfig(template: GameTemplate.tavla, seatCount: 2),
        const TavlaRuleSet(),
        ['Ayşe', 'Mehmet'],
      );
      final v = await view(id);
      expect(v.showsDealer, isFalse);
      expect(v.columns.map((c) => c.dealerSeat), [null, null]);
    });
  });

  group('Eşli 101', () {
    test('koltuk sütunları ve ayrıca takım toplamları var', () async {
      final id = await create(
        const GameConfig(
          template: GameTemplate.okey101,
          seatCount: 4,
          playMode: PlayMode.pairs,
        ),
        const Okey101RuleSet(),
        ['Ayşe', 'Mehmet', 'Zeynep', 'Can'],
      );
      await repo.addRound(
        id,
        const Okey101RoundInput(
          finisherSeat: 1,
          players: [
            Okey101Player(state: Okey101PlayerState.opened, remaining: 38),
            Okey101Player(state: Okey101PlayerState.opened),
            Okey101Player(state: Okey101PlayerState.opened, remaining: 24),
            Okey101Player(state: Okey101PlayerState.notOpened),
          ],
        ),
      );
      final v = await view(id);
      expect(v.columns, hasLength(4));
      expect(v.columns.map((c) => c.total), [38, -101, 24, 0]);
      // Lider takımdır; tek koltuk sütunu lider sayılmaz.
      expect(v.columns.where((c) => c.isLeader), isEmpty);
      expect(
        v.teamTotals.map((t) => (t.names.join(' & '), t.total, t.isLeader)),
        [('Ayşe & Zeynep', 62, false), ('Mehmet & Can', -101, true)],
      );
    });

    test('bireysel oyunda takım toplamı yok', () async {
      final id = await free(['Ayşe', 'Mehmet']);
      expect((await view(id)).teamTotals, isEmpty);
    });
  });

  group('Satırlar', () {
    test('oyuncu değişikliği notu geçerli olduğu elin üstünde', () async {
      final id = await free(['Ayşe', 'Mehmet']);
      await repo.addRound(id, const FreeRoundInput([1, 2]));
      await repo.replacePlayer(id, 0, 'Elif');
      // Sıradaki elden geçerli değişiklik en altta.
      var rows = (await view(id)).rows;
      expect(rows, hasLength(2));
      expect(rows.last, isA<SeatChangeRow>());

      await repo.addRound(id, const FreeRoundInput([3, 4]));
      rows = (await view(id)).rows;
      expect(rows.map((r) => r.runtimeType), [
        RoundScoreRow,
        SeatChangeRow,
        RoundScoreRow,
      ]);
      final note = (rows[1] as SeatChangeRow).change;
      expect((note.fromRound, note.from, note.to), (2, 'Ayşe', 'Elif'));
      // Her el o elde oturanın ismiyle okunur.
      expect((rows[0] as RoundScoreRow).names.first, ['Ayşe']);
      expect((rows[2] as RoundScoreRow).names.first, ['Elif']);
      expect((await view(id)).columns.first.names, ['Elif']);
    });

    test('el numaraları sırayla, silinen el boşluk bırakmaz', () async {
      final id = await free(['Ayşe', 'Mehmet']);
      final first = await repo.addRound(id, const FreeRoundInput([1, 2]));
      await repo.addRound(id, const FreeRoundInput([3, 4]));
      await repo.deleteRound(first);
      final rows = (await view(id)).rows.cast<RoundScoreRow>();
      expect(rows.map((r) => (r.number, r.points.join(' '))), [(1, '3 4')]);
    });
  });

  group('Oyun durumu', () {
    test(
      'hedefe ulaşınca "Sonucu Gör" durumuna geçer ama düzenlenebilir',
      () async {
        final id = await free(['Ayşe', 'Mehmet'], target: 10);
        await repo.addRound(id, const FreeRoundInput([12, 3]));
        final v = await view(id);
        expect(v.isOver, isTrue);
        expect(v.isReadOnly, isFalse);
        expect(v.target, 10);
      },
    );

    test('kesin biten oyun salt okunur, dağıtıcı gösterilmez', () async {
      final id = await free(['Ayşe', 'Mehmet']);
      await repo.addRound(id, const FreeRoundInput([1, 2]));
      await repo.finishGame(id);
      final v = await view(id);
      expect(v.isReadOnly, isTrue);
      expect(v.isOver, isTrue);
      expect(v.columns.map((c) => c.dealerSeat), [null, null]);
    });

    test('101\'de kalan el sayısı bilinir', () async {
      final id = await create(
        const GameConfig(template: GameTemplate.okey101, seatCount: 4),
        const Okey101RuleSet(),
        ['A', 'B', 'C', 'D'],
      );
      final v = await view(id);
      expect(v.roundsLeft, 9);
      expect(v.target, isNull);
    });
  });
}
