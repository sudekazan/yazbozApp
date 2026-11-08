import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_dimensions.dart';
import '../../data/repositories/game_models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/bottom_action_bar.dart';
import '../common/game_problem.dart';
import '../common/template_labels.dart';
import '../round_entry/round_entry_sheet.dart';
import 'scoreboard_dialogs.dart';
import 'scoreboard_logic.dart';
import 'scoreboard_table.dart';

/// Skor tablosu: oyunun ana ekranı.
class ScoreboardScreen extends ConsumerWidget {
  const ScoreboardScreen({required this.gameId, super.key});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return switch (ref.watch(gameByIdProvider(gameId))) {
      AsyncData(value: GameLoaded(:final snapshot)) => _Scoreboard(snapshot),
      AsyncData(value: GameNotFound()) => GameProblem(
        title: l10n.scoreboardTitle,
        message: l10n.gameNotFoundMessage,
      ),
      AsyncData(value: GameUnreadable()) || AsyncError() => GameProblem(
        title: l10n.scoreboardTitle,
        message: l10n.gameUnreadableMessage,
      ),
      // 100 ms'den kısa sürdüğü için yükleme göstergesi yok.
      _ => Scaffold(appBar: AppBar()),
    };
  }
}

enum _MenuItem { rules, dealerIndicator, restart, finish }

class _Scoreboard extends ConsumerStatefulWidget {
  const _Scoreboard(this.game);

  final GameSnapshot game;

  @override
  ConsumerState<_Scoreboard> createState() => _ScoreboardState();
}

class _ScoreboardState extends ConsumerState<_Scoreboard> {
  final _scroll = ScrollController();

  /// Yeni el eklenince tablo en alta kaysın diye son görülen el sayısı.
  int? _shownRounds;

  GameSnapshot get _game => widget.game;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final view = buildScoreboard(_game);
    _followNewRounds(view.roundsPlayed);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: _toolbarHeight(context),
        title: _Title(game: _game, view: view),
        actions: [
          if (!view.isReadOnly)
            IconButton(
              tooltip: l10n.undoTooltip,
              icon: const Icon(Icons.undo),
              onPressed: _game.canUndo ? _undo : null,
            ),
          _menu(view),
          const SizedBox(width: AppSpacing.xxs),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScoreHeader(
            view: view,
            onColumnTap: view.isReadOnly
                ? null
                : (column) => _openPlayer(view, column),
          ),
          Expanded(child: _rows(view)),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: view.isOver
            ? FilledButton(
                onPressed: () => context.go(AppRoutes.gameOver(_game.id)),
                child: Text(l10n.showResultButton),
              )
            : FilledButton.icon(
                onPressed: _openEntry,
                icon: const Icon(Icons.add),
                label: Text(l10n.addRoundButton),
              ),
      ),
    );
  }

  /// Başlık iki satır; büyük yazı boyutunda taşmasın diye yükseklik
  /// yazı ölçeğiyle büyür.
  double _toolbarHeight(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle? style) =>
        scaler.scale((style?.fontSize ?? 0) * (style?.height ?? 1));
    return math.max(
      kToolbarHeight,
      line(text.titleLarge) + line(text.bodySmall) + AppSpacing.xs,
    );
  }

  Widget _rows(ScoreboardView view) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (view.rows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Text(
            l10n.emptyRoundsMessage,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        AppSpacing.lg,
      ),
      itemCount: view.rows.length,
      itemBuilder: (context, index) => switch (view.rows[index]) {
        final RoundScoreRow row => RoundTile(
          key: ValueKey('round-${row.roundId}'),
          row: row,
          onTap: view.isReadOnly
              ? null
              : () => _openEntry(roundId: row.roundId),
          onDelete: view.isReadOnly ? null : () => _deleteRound(row),
        ),
        final SeatChangeRow row => SeatChangeNote(row: row),
      },
    );
  }

  Widget _menu(ScoreboardView view) {
    final l10n = AppLocalizations.of(context);
    final editable = !view.isReadOnly;
    return PopupMenuButton<_MenuItem>(
      tooltip: l10n.gameMenuTooltip,
      icon: const Icon(Icons.more_vert),
      onSelected: (item) => switch (item) {
        _MenuItem.rules => showRulesSheet(
          context,
          template: _game.config.template,
          rules: _game.rules,
        ),
        _MenuItem.dealerIndicator =>
          ref
              .read(gameRepositoryProvider)
              .setDealerIndicator(_game.id, enabled: !_game.dealerIndicator),
        _MenuItem.restart => _restart(),
        _MenuItem.finish => _finish(),
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: _MenuItem.rules, child: Text(l10n.menuShowRules)),
        if (editable && view.showsDealer)
          CheckedPopupMenuItem(
            value: _MenuItem.dealerIndicator,
            checked: _game.dealerIndicator,
            child: Text(l10n.menuDealerIndicator),
          ),
        if (editable && view.roundsPlayed > 0)
          PopupMenuItem(
            value: _MenuItem.restart,
            child: Text(l10n.menuRestart),
          ),
        if (editable && !view.isOver && view.roundsPlayed > 0)
          PopupMenuItem(
            value: _MenuItem.finish,
            child: Text(l10n.menuFinishGame),
          ),
      ],
    );
  }

  /// Yeni el eklenince listeyi en alta kaydırır; açılışta da son eller
  /// görünsün diye en alttan başlar.
  void _followNewRounds(int rounds) {
    final previous = _shownRounds;
    _shownRounds = rounds;
    if (previous != null && rounds <= previous) return;
    final animate = previous != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      final duration = AppDurations.resolve(context, AppDurations.long);
      if (animate && duration > Duration.zero) {
        _scroll.animateTo(end, duration: duration, curve: Curves.easeOut);
      } else {
        _scroll.jumpTo(end);
      }
    });
  }

  // --------------------------------------------------------------- eylemler

  /// El girişini açar; [roundId] verilirse o eli düzenler. Kayıt oyunu
  /// bitirdiyse sonuç ekranına geçer.
  Future<void> _openEntry({int? roundId}) async {
    final repo = ref.read(gameRepositoryProvider);
    final wasOver = _game.status.isFinished;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final saved = await showRoundEntrySheet(
      context,
      game: _game,
      editing: roundId == null
          ? null
          : _game.rounds.firstWhere((r) => r.id == roundId),
    );
    if (!saved || wasOver) return;
    final load = await repo.loadGame(_game.id);
    if (!mounted) return;
    if (load is GameLoaded && load.snapshot.status.isFinished) {
      context.go(AppRoutes.gameOver(_game.id));
    }
  }

  Future<void> _undo() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await ref.read(gameRepositoryProvider).undo(_game.id);
  }

  Future<void> _deleteRound(RoundScoreRow row) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(gameRepositoryProvider);
    final confirmed = await confirmAction(
      context,
      title: l10n.deleteRoundTitle(row.number),
      message: l10n.deleteRoundMessage,
      confirmLabel: l10n.deleteRoundButton,
    );
    if (!confirmed) return;
    await repo.deleteRound(row.roundId);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.roundDeletedMessage(row.number)),
          persist: false,
          action: SnackBarAction(
            label: l10n.undoButton,
            onPressed: () => repo.undo(_game.id),
          ),
        ),
      );
  }

  Future<void> _openPlayer(ScoreboardView view, ScoreColumn column) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(gameRepositoryProvider);
    final choice = await showPlayerSheet(
      context,
      column: column,
      canMakeDealer: view.showsDealer && _game.dealerIndicator,
    );
    if (choice == null || !mounted) return;
    final (action, seat) = choice;
    final current = column.names[column.seats.indexOf(seat)];
    switch (action) {
      case PlayerAction.makeDealer:
        await repo.setDealer(_game.id, seat);
      case PlayerAction.replace:
        final name = await showDialog<String>(
          context: context,
          builder: (context) => PlayerNameDialog(
            title: l10n.replacePlayerButton,
            label: l10n.newPlayerNameLabel,
            helper: l10n.replacePlayerHelper(view.roundsPlayed + 1),
          ),
        );
        if (name != null) await repo.replacePlayer(_game.id, seat, name);
      case PlayerAction.rename:
        final name = await showDialog<String>(
          context: context,
          builder: (context) => PlayerNameDialog(
            title: l10n.renamePlayerButton,
            label: l10n.playerNameLabel,
            helper: l10n.renamePlayerHelper,
            initialName: current,
          ),
        );
        if (name != null && name != current) {
          await repo.renamePlayer(_game.id, seat, name);
        }
    }
  }

  Future<void> _restart() async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(gameRepositoryProvider);
    final confirmed = await confirmAction(
      context,
      title: l10n.restartTitle(_game.rounds.length),
      message: l10n.restartMessage,
      confirmLabel: l10n.restartButton,
    );
    if (!confirmed) return;
    if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await repo.restartGame(_game.id);
  }

  Future<void> _finish() async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(gameRepositoryProvider);
    final confirmed = await confirmAction(
      context,
      title: l10n.finishTitle,
      message: l10n.finishMessage,
      confirmLabel: l10n.menuFinishGame,
    );
    if (!confirmed) return;
    await repo.finishGame(_game.id);
    if (mounted) context.go(AppRoutes.gameOver(_game.id));
  }
}

/// Başlık ve altında el/hedef bilgisi ("4/9 el · 5 el kaldı").
class _Title extends StatelessWidget {
  const _Title({required this.game, required this.view});

  final GameSnapshot game;
  final ScoreboardView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final played = view.roundsPlayed;
    final roundsLeft = view.roundsLeft;
    final target = view.target;
    final info = view.isReadOnly
        ? l10n.scoreboardInfo(
            l10n.scoreboardFinished,
            l10n.homeRoundCount(played),
          )
        : roundsLeft != null
        ? l10n.scoreboardInfo(
            l10n.homeRoundsOfTotal(played, played + roundsLeft),
            l10n.scoreboardRoundsLeft(roundsLeft),
          )
        : target != null
        ? l10n.scoreboardInfo(
            l10n.homeRoundCount(played),
            l10n.scoreboardTarget(target),
          )
        : l10n.homeRoundCount(played);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          gameTitle(l10n, game.config.template, game.config.playMode),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          info,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
