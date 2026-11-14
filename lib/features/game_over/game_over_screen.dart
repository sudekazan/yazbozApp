import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/game_models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/bottom_action_bar.dart';
import '../common/game_problem.dart';
import '../common/score_format.dart';
import '../common/template_labels.dart';
import '../scoreboard/scoreboard_logic.dart';
import 'share_table.dart';

/// Final sıralamasındaki bir satır.
class FinalRank {
  const FinalRank({
    required this.rank,
    required this.names,
    required this.total,
    required this.isWinner,
    required this.notes,
  });

  final int rank;
  final List<String> names;
  final int total;
  final bool isWinner;

  /// Oyuncu değişiklikleri: (el, önceki oyuncu).
  final List<(int, String)> notes;
}

/// Oyunun final sıralaması; kazananlar en üstte. Saf hesap.
List<FinalRank> finalRanking(GameSnapshot game) {
  final engine = game.engine;
  final units = engine.units(game.config);
  final contenders = engine.contenders(game.config);
  final names = game.currentNames;
  final winners = game.winners.toSet();
  final changes = game.seating.changes();
  return [
    for (final standing in game.status.standings)
      () {
        final seats = [
          for (final unit in contenders[standing.contender])
            ...units[unit].seats,
        ];
        return FinalRank(
          rank: standing.rank,
          names: [for (final seat in seats) names[seat]],
          total: standing.total,
          isWinner: winners.contains(standing.contender),
          notes: [
            for (final change in changes)
              if (seats.contains(change.seat)) (change.fromRound, change.from),
          ],
        );
      }(),
  ];
}

/// Oyun sonu: kazanan, final sıralaması, rövanş ve ana sayfa.
class GameOverScreen extends ConsumerWidget {
  const GameOverScreen({required this.gameId, super.key});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return switch (ref.watch(gameByIdProvider(gameId))) {
      AsyncData(value: GameLoaded(:final snapshot))
          when snapshot.winners.isEmpty =>
        GameProblem(
          title: l10n.gameOverTitle,
          message: l10n.gameNotOverMessage,
          actionLabel: l10n.backToTableButton,
          location: AppRoutes.game(gameId),
        ),
      AsyncData(value: GameLoaded(:final snapshot)) => _GameOver(snapshot),
      AsyncData(value: GameNotFound()) => GameProblem(
        title: l10n.gameOverTitle,
        message: l10n.gameNotFoundMessage,
      ),
      AsyncData(value: GameUnreadable()) || AsyncError() => GameProblem(
        title: l10n.gameOverTitle,
        message: l10n.gameUnreadableMessage,
      ),
      // 100 ms'den kısa sürdüğü için yükleme göstergesi yok.
      _ => Scaffold(appBar: AppBar()),
    };
  }
}

class _GameOver extends ConsumerStatefulWidget {
  const _GameOver(this.game);

  final GameSnapshot game;

  @override
  ConsumerState<_GameOver> createState() => _GameOverState();
}

class _GameOverState extends ConsumerState<_GameOver> {
  /// Çift dokunuşta iki rövanş açılmasın.
  bool _busy = false;

  GameSnapshot get _game => widget.game;

  /// Rövanş: oyun kesin biter, aynı ayarlarla yeni oyun açılır.
  Future<void> _rematch() async {
    if (_busy) return;
    setState(() => _busy = true);
    final id = await ref.read(gameRepositoryProvider).rematch(_game.id);
    if (mounted) context.go(AppRoutes.game(id));
  }

  final _shareKey = GlobalKey();

  /// Tablonun tamamını görsel olarak paylaşır.
  Future<void> _share() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final sharer = ref.read(tableSharerProvider);
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      final png = await renderTableImage(context, buildScoreboard(_game));
      if (png == null) throw StateError('Görsel çizilemedi');
      await sharer(png, 'yazboz-tablo-${_game.id}.png', origin);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.shareTableError)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Ana sayfaya dönünce oyun kesin biter.
  Future<void> _goHome() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(gameRepositoryProvider).finishGame(_game.id);
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ranking = finalRanking(_game);
    final winners = ranking.where((r) => r.isWinner).toList();
    final winnerNames = [for (final w in winners) columnName(l10n, w.names)]
        .join(', ');
    final summary = [
      l10n.pointsCount(formatPoints(winners.first.total)),
      gameTitle(l10n, _game.config.template, _game.config.playMode),
      l10n.homeRoundCount(_game.rounds.length),
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.gameOverTitle)),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.xs,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          children: [
            Semantics(
              container: true,
              child: Column(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: AppSizes.winnerBadge,
                      height: AppSizes.winnerBadge,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.emoji_events_outlined,
                        size: AppSizes.winnerIcon,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    winners.length > 1
                        ? l10n.gameOverWinners
                        : l10n.gameOverWinner,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    winnerNames,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall,
                  ),
                  Text(
                    summary,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.finalRankingTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Card(
              // Her sıra ekran okuyucuda ayrı okunsun.
              semanticContainer: false,
              child: Column(
                children: [
                  for (var i = 0; i < ranking.length; i++) ...[
                    if (i > 0) const Divider(),
                    _RankTile(ranking[i]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _rematch,
              icon: const Icon(Icons.replay),
              label: Text(l10n.rematchButton),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              key: _shareKey,
              onPressed: _busy ? null : _share,
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.shareTableButton),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: _busy ? null : _goHome,
              child: Text(l10n.goHomeButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile(this.rank);

  final FinalRank rank;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = columnName(l10n, rank.names);
    final total = formatPoints(rank.total);
    final weight = rank.isWinner
        ? AppTypography.semibold
        : AppTypography.regular;
    final notes = [
      for (final (round, from) in rank.notes) l10n.replacedNote(round, from),
    ];

    return Semantics(
      label: [l10n.rankSemantics(rank.rank, name, total), ...notes].join(', '),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSizes.scoreRowMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              SizedBox(
                width: AppSpacing.lg,
                child: Text(
                  '${rank.rank}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: weight,
                      ),
                    ),
                    for (final note in notes)
                      Text(
                        note,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                total,
                style: theme.extension<ScoreTextTheme>()!.cell.copyWith(
                  fontWeight: weight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
