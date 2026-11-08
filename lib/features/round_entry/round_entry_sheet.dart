import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/game_models.dart';
import '../../domain/models/game_config.dart';
import '../../domain/rules/free_rules.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/score_format.dart';
import 'number_entry.dart';
import 'number_keypad.dart';

/// El girişi hazır olan şablonlar. Diğerlerinde "El Ekle" şimdilik pasif.
bool hasRoundEntry(GameTemplate template) => template == GameTemplate.free;

/// El girişi sayfasını açar. [editing] verilirse o el düzenlenir.
/// El kaydedilirse `true` döner.
Future<bool> showRoundEntrySheet(
  BuildContext context, {
  required GameSnapshot game,
  StoredRound? editing,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: AppSizes.entrySheetHeightFactor,
      child: _FreeRoundEntry(game: game, editing: editing),
    ),
  );
  return saved ?? false;
}

/// Serbest: her oyuncuya sayı girilir; boş alan 0 sayılır.
class _FreeRoundEntry extends ConsumerStatefulWidget {
  const _FreeRoundEntry({required this.game, this.editing});

  final GameSnapshot game;
  final StoredRound? editing;

  @override
  ConsumerState<_FreeRoundEntry> createState() => _FreeRoundEntryState();
}

class _FreeRoundEntryState extends ConsumerState<_FreeRoundEntry> {
  late final List<NumberEntry> _entries;
  late final List<GlobalKey> _rowKeys;
  int _focus = 0;
  bool _saving = false;
  bool _failed = false;

  GameSnapshot get _game => widget.game;

  /// Tabloda görünen el numarası.
  late final int _number = widget.editing == null
      ? _game.rounds.length + 1
      : _game.rounds.indexWhere((r) => r.id == widget.editing!.id) + 1;

  @override
  void initState() {
    super.initState();
    final count = _game.config.seatCount;
    final input = widget.editing?.round.input;
    _entries = [
      for (var seat = 0; seat < count; seat++)
        input is FreeRoundInput && seat < input.points.length
            ? NumberEntry.fromValue(input.points[seat])
            : const NumberEntry(),
    ];
    _rowKeys = List.generate(count, (_) => GlobalKey());
  }

  /// Bu el olmadan her sütunun toplamı; önizleme bunun üstüne eklenir.
  late final List<int> _baseTotals = () {
    final totals = [..._game.status.unitTotals];
    final old = widget.editing?.round.result.points;
    if (old != null) {
      for (var i = 0; i < totals.length && i < old.length; i++) {
        totals[i] -= old[i];
      }
    }
    return totals;
  }();

  void _edit(NumberEntry Function(NumberEntry) change) {
    setState(() {
      _entries[_focus] = change(_entries[_focus]);
      _failed = false;
    });
  }

  void _moveTo(int index) {
    final down = index > _focus;
    setState(() => _focus = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _rowKeys[index].currentContext;
      if (row == null || !mounted) return;
      Scrollable.ensureVisible(
        row,
        duration: AppDurations.resolve(context, AppDurations.medium),
        alignmentPolicy: down
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final input = FreeRoundInput([for (final e in _entries) e.value]);
    final errors = _game.engine.validate(input, _game.rules, _game.config);
    if (errors.isNotEmpty) {
      setState(() => _failed = true);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(gameRepositoryProvider);
    final editing = widget.editing;
    try {
      if (editing == null) {
        await repo.addRound(_game.id, input);
      } else {
        await repo.updateRound(editing.id, input);
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final names = _game.seating.namesForRound(_number);
    final last = _entries.length - 1;

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.screen,
              end: AppSpacing.xxs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.roundEntryTitle(_number),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.closeTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
          Expanded(
            // En fazla 8 satır; hepsi kurulur ki uzaktaki satıra geçilince
            // liste oraya kaydırılabilsin.
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screen,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var seat = 0; seat < _entries.length; seat++)
                    _EntryRow(
                      key: _rowKeys[seat],
                      name: names[seat],
                      entry: _entries[seat],
                      newTotal: _baseTotals[seat] + _entries[seat].value,
                      focused: seat == _focus,
                      onTap: () => _moveTo(seat),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.sm,
              AppSpacing.screen,
              AppSpacing.screen,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_failed) ...[
                  _ErrorLine(l10n.roundSaveError),
                  const SizedBox(height: AppSpacing.xs),
                ],
                NumberKeypad(
                  onDigit: (d) => _edit((e) => e.addDigit(d)),
                  onMinus: () => _edit((e) => e.toggleSign()),
                  onBackspace: () => _edit((e) => e.backspace()),
                  onClear: () => _edit((_) => const NumberEntry()),
                  onPrevious: _focus > 0 ? () => _moveTo(_focus - 1) : null,
                  onNext: _focus < last ? () => _moveTo(_focus + 1) : null,
                ),
                const SizedBox(height: AppSpacing.xxs),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.saveButton),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Oyuncu satırı: isim, yeni toplam önizlemesi ve puan alanı.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.name,
    required this.entry,
    required this.newTotal,
    required this.focused,
    required this.onTap,
    super.key,
  });

  final String name;
  final NumberEntry entry;
  final int newTotal;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final score = theme.extension<ScoreTextTheme>()!;
    final total = formatPoints(newTotal);

    return Semantics(
      button: true,
      selected: focused,
      label: l10n.pointsFieldSemantics(
        name,
        entry.isEmpty ? '0' : entry.display,
        total,
      ),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        l10n.newTotalPreview(total),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: AppTypography.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: AppSizes.entryFieldWidth,
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.minTouchTarget,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  alignment: AlignmentDirectional.centerEnd,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: focused
                        ? Border.all(
                            color: scheme.primary,
                            width: AppSizes.focusOutline,
                          )
                        : Border.all(color: scheme.outline),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      entry.isEmpty && !entry.negative ? '0' : entry.display,
                      maxLines: 1,
                      style: score.entry.copyWith(
                        color: entry.isEmpty ? scheme.onSurfaceVariant : null,
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

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(Icons.error_outline, color: color, size: AppSizes.iconSmall),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
