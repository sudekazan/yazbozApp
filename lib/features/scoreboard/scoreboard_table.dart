import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/score_format.dart';
import 'scoreboard_logic.dart';

/// Sütun başlığındaki isim: tek oyuncu ya da "Ayşe & Zeynep".
String columnName(AppLocalizations l10n, List<String> names) =>
    names.length == 2 ? l10n.teamNames(names[0], names[1]) : names.join(', ');

/// Üstte sabit duran başlık: isimler, büyük toplamlar, lider ve dağıtıcı.
class ScoreHeader extends StatelessWidget {
  const ScoreHeader({required this.view, this.onColumnTap, super.key});

  final ScoreboardView view;

  /// Sütuna dokunulunca (ya da uzun basılınca); salt okunur tabloda `null`.
  final ValueChanged<ScoreColumn>? onColumnTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.xxs,
          AppSpacing.screen,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: AppSizes.roundNumberColumn),
                for (final column in view.columns)
                  Expanded(
                    child: _ColumnHeader(
                      column: column,
                      onTap: onColumnTap == null
                          ? null
                          : () => onColumnTap!(column),
                    ),
                  ),
              ],
            ),
            if (view.teamTotals.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const SizedBox(width: AppSizes.roundNumberColumn),
                  for (final team in view.teamTotals)
                    Expanded(child: _TeamTotal(team)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.column, required this.onTap});

  final ScoreColumn column;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final score = theme.extension<ScoreTextTheme>()!;

    final label = [
      l10n.columnSemantics(
        columnName(l10n, column.names),
        formatPoints(column.total),
      ),
      if (column.isLeader) l10n.leaderSemantics,
      if (column.dealerSeat != null)
        l10n.dealerSemantics(
          column.names[column.seats.indexOf(column.dealerSeat!)],
        ),
    ].join(', ');

    return Semantics(
      button: onTap != null,
      label: label,
      // Alt öğeler dışlandığı için dokunma eylemi burada da verilir.
      onTap: onTap,
      onTapHint: onTap == null ? null : l10n.playerOptionsHint,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: column.isLeader
              ? BorderSide(
                  color: scheme.onSurface,
                  width: AppSizes.leaderOutline,
                )
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxs,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < column.seats.length; i++)
                    _NameLine(
                      name: column.names[i],
                      isLeader: column.isLeader && i == 0,
                      isDealer: column.dealerSeat == column.seats[i],
                    ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatPoints(column.total),
                      maxLines: 1,
                      style: score.total,
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
}

/// İsim satırı: lider tacı, isim (sığmazsa kısalır), dağıtıcı kartı.
class _NameLine extends StatelessWidget {
  const _NameLine({
    required this.name,
    required this.isLeader,
    required this.isDealer,
  });

  final String name;
  final bool isLeader;
  final bool isDealer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLeader) ...[
          Icon(
            Icons.emoji_events_outlined,
            size: AppSizes.iconSmall,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xxs),
        ],
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
        ),
        if (isDealer) ...[
          const SizedBox(width: AppSpacing.xxs),
          Icon(Icons.style_outlined, size: AppSizes.iconSmall, color: color),
        ],
      ],
    );
  }
}

/// Eşli 101'de takım toplamı; sütunların altında ince bir satır.
class _TeamTotal extends StatelessWidget {
  const _TeamTotal(this.team);

  final TeamTotal team;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final names = columnName(l10n, team.names);
    final total = formatPoints(team.total);
    return Semantics(
      label: [
        l10n.teamTotalSemantics(names, total),
        if (team.isLeader) l10n.leaderSemantics,
      ].join(', '),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (team.isLeader) ...[
            Icon(
              Icons.emoji_events_outlined,
              size: AppSizes.iconSmall,
              color: scheme.onSurface,
            ),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Flexible(
            child: Text(
              names,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            total,
            style: theme.textTheme.titleSmall?.copyWith(
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bir elin satırı: el numarası, varsa çarpan rozeti ve puanlar.
class RoundTile extends StatelessWidget {
  const RoundTile({required this.row, this.onTap, this.onDelete, super.key});

  final RoundScoreRow row;
  final VoidCallback? onTap;

  /// Uzun basınca; salt okunur tabloda `null`.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final score = theme.extension<ScoreTextTheme>()!;

    final scores = [
      for (var unit = 0; unit < row.points.length; unit++)
        l10n.nameAndPoints(
          columnName(l10n, row.names[unit]),
          formatPoints(row.points[unit]),
        ),
    ].join(', ');
    final label = row.multiplier > 1
        ? l10n.roundMultiplierSemantics(row.number, row.multiplier, scores)
        : l10n.roundSemantics(row.number, scores);

    return Semantics(
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.deleteRoundButton): ?onDelete,
      },
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.scoreRowMinHeight,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: AppSizes.roundNumberColumn,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${row.number}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: AppTypography.tabularFigures,
                          ),
                        ),
                        if (row.multiplier > 1)
                          _MultiplierBadge(row.multiplier),
                      ],
                    ),
                  ),
                ),
                for (final points in row.points)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxs,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatPoints(points),
                          maxLines: 1,
                          style: score.cell,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiplierBadge extends StatelessWidget {
  const _MultiplierBadge(this.multiplier);

  final int multiplier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
        child: Text(
          AppLocalizations.of(context).multiplierBadge(multiplier),
          style: theme.textTheme.labelSmall?.copyWith(
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      ),
    );
  }
}

/// "5. elden itibaren: Ayşe → Mehmet" notu.
class SeatChangeNote extends StatelessWidget {
  const SeatChangeNote({required this.row, super.key});

  final SeatChangeRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final change = row.change;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSizes.seatNoteMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.swap_horiz,
                  size: AppSizes.iconSmall,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)
                      .seatChangeNote(change.fromRound, change.from, change.to),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
