import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/score_format.dart';

/// Seçilebilir düğme: seçiliyken vurgu zemini ve tik ikonu. Tek seçimli
/// gruplarda [exclusive] açık olur (ekran okuyucu "radyo düğmesi" der).
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.value,
    this.exclusive = true,
    super.key,
  });

  final String label;

  /// Sağda gösterilen değer ("−2", "×2" gibi).
  final String? value;
  final bool selected;
  final bool exclusive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: ink,
      fontWeight: selected ? AppTypography.semibold : AppTypography.regular,
    );
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: exclusive,
      button: true,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: selected ? scheme.primary : scheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisAlignment: value == null
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.spaceBetween,
                children: [
                  if (selected) ...[
                    Icon(Icons.check, size: AppSizes.iconSmall, color: ink),
                    const SizedBox(width: AppSpacing.xxs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: value == null
                          ? TextAlign.center
                          : TextAlign.start,
                      style: style,
                    ),
                  ),
                  if (value != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      value!,
                      style: style?.copyWith(
                        fontWeight: AppTypography.semibold,
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Düğmeleri [columns] sütunlu ızgaraya dizer; satırdaki düğmeler eşit
/// genişlikte ve eşit yükseklikte olur.
class ChoiceGrid extends StatelessWidget {
  const ChoiceGrid({required this.columns, required this.children, super.key});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += columns) {
      final row = children.skip(start).take(columns).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(child: i < row.length ? row[i] : const SizedBox()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          rows[i],
        ],
      ],
    );
  }
}

/// Başlık ve altında içerik; bölümler arası boşluk tek yerden gelir.
class EntrySection extends StatelessWidget {
  const EntrySection({
    required this.label,
    required this.child,
    this.hint,
    this.trailing,
    super.key,
  });

  final String label;

  /// Başlığın yanındaki soluk açıklama ("isteğe bağlı" gibi).
  final String? hint;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text.rich(
                      TextSpan(
                        text: label,
                        children: [
                          if (hint != null)
                            TextSpan(
                              text: ' · $hint',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// "Bu elin puanları": her sütunun bu eldeki puanı. Girdi eksikse "–".
class PointsPreview extends StatelessWidget {
  const PointsPreview({required this.names, required this.points, super.key});

  final List<String> names;
  final List<int>? points;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final score = theme.extension<ScoreTextTheme>()!;
    final values = points;
    return Semantics(
      container: true,
      label: values == null
          ? l10n.previewIncomplete
          : [
              for (var i = 0; i < names.length; i++)
                l10n.nameAndPoints(names[i], formatPoints(values[i])),
            ].join(', '),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.previewTitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < names.length; i++)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            names[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              values == null ? '–' : formatPoints(values[i]),
                              style: score.entry,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hata satırı: ikon ve çözüm söyleyen metin; renge dayanmaz.
class EntryErrors extends StatelessWidget {
  const EntryErrors(this.messages, {super.key});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final message in messages)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: color,
                    size: AppSizes.iconSmall,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
