import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/relative_time.dart';
import '../../data/repositories/game_models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/template_labels.dart';

/// Ana sayfa: yeni oyun kurma, devam eden ve biten oyunlar.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final games = ref.watch(gameSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle, style: theme.textTheme.headlineSmall),
        actions: [
          IconButton(
            tooltip: l10n.settingsTooltip,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(AppRoutes.settings),
          ),
          const SizedBox(width: AppSpacing.xxs),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.xs,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          children: [
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.newGame),
              icon: const Icon(Icons.add),
              label: Text(l10n.newGameButton),
            ),
            ...switch (games) {
              AsyncData(:final value) => _sections(context, value),
              AsyncError() => [_Message(l10n.homeLoadError)],
              // 100 ms'den kısa sürdüğü için yükleme göstergesi yok.
              _ => const <Widget>[],
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _sections(BuildContext context, List<GameSummary> games) {
    final l10n = AppLocalizations.of(context);
    if (games.isEmpty) return [_Message(l10n.homeEmptyMessage)];
    final ongoing = games.where((g) => !g.isFinished).toList();
    final finished = games.where((g) => g.isFinished).toList();
    return [
      if (ongoing.isNotEmpty) _GameSection(l10n.homeOngoingTitle, ongoing),
      if (finished.isNotEmpty) _GameSection(l10n.homeFinishedTitle, finished),
    ];
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        left: AppSpacing.xxs,
        right: AppSpacing.xxs,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _GameSection extends StatelessWidget {
  const _GameSection(this.title, this.games);

  final String title;
  final List<GameSummary> games;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: AppSpacing.xs),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < games.length; i++) ...[
                  if (i > 0) const Divider(),
                  _GameTile(games[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameTile extends ConsumerWidget {
  const _GameTile(this.game);

  final GameSummary game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final template = game.template;
    final title = template == null
        ? l10n.homeUnreadableTitle
        : gameTitle(l10n, template, game.playMode);

    return Dismissible(
      key: ValueKey(game.id),
      direction: DismissDirection.endToStart,
      movementDuration: AppDurations.resolve(context, AppDurations.medium),
      resizeDuration: MediaQuery.disableAnimationsOf(context)
          ? null
          : AppDurations.long,
      onDismissed: (_) => _delete(context, ref, title),
      background: ColoredBox(
        color: scheme.errorContainer,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, color: scheme.onErrorContainer),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.deleteAction,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: l10n.deleteAction): () =>
              _delete(context, ref, title),
        },
        child: InkWell(
          onTap: game.isReadable
              ? () => context.go(AppRoutes.game(game.id))
              : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.listItemMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: AppSizes.listLeading,
                    height: AppSizes.listLeading,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      template?.icon ?? Icons.error_outline,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              relativeTime(l10n, game.updatedAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _subtitle(l10n),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(AppLocalizations l10n) {
    if (!game.isReadable) return l10n.homeUnreadableSubtitle;
    if (game.isFinished && game.winnerNames.isNotEmpty) {
      return l10n.homeWinner(game.winnerNames.join(', '));
    }
    final players = playersLine(l10n, game.playerNames, game.playMode);
    final roundsLeft = game.status?.roundsLeft;
    final rounds = roundsLeft == null
        ? l10n.homeRoundCount(game.roundsPlayed)
        : l10n.homeRoundsOfTotal(
            game.roundsPlayed,
            game.roundsPlayed + roundsLeft,
          );
    return '$players · $rounds';
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String title,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(gameRepositoryProvider);
    await repo.softDeleteGame(game.id);
    messenger.clearSnackBars();
    final closed = messenger
        .showSnackBar(
          SnackBar(
            content: Text(l10n.gameDeletedMessage(title)),
            // Aksiyonlu bildirim varsayılan olarak açık kalır; "Geri Al"
            // süresi dolunca kapanmalı ki oyun kalıcı silinsin.
            persist: false,
            action: SnackBarAction(
              label: l10n.undoButton,
              onPressed: () => repo.restoreGame(game.id),
            ),
          ),
        )
        .closed;
    if (await closed != SnackBarClosedReason.action) {
      await repo.purgeDeletedGame(game.id);
    }
  }
}
