import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../domain/validation.dart';
import '../../l10n/generated/app_localizations.dart';

/// Kurulumdaki bir oyuncu satırının durumu. Sıralama değişse de denetleyici
/// aynı kalsın diye kimlikle tutulur.
class PlayerEntry {
  PlayerEntry({required this.id, required this.defaultText})
    : controller = TextEditingController(text: defaultText);

  final int id;

  /// "Oyuncu 3" gibi dolu gelen isim; dokununca tamamı seçilir.
  String defaultText;
  final TextEditingController controller;
  final FocusNode focus = FocusNode();

  bool get isDefaultName => controller.text == defaultText;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

/// Oyuncu listesi: sürükleyerek sıralama, isim, takım ve ilk dağıtıcı.
class SetupPlayers extends StatelessWidget {
  const SetupPlayers({
    required this.players,
    required this.isPairs,
    required this.showDealer,
    required this.dealerId,
    required this.errorOf,
    required this.suggestions,
    required this.canSaveGroup,
    required this.onReorder,
    required this.onDealer,
    required this.onSuggestion,
    required this.onSaveGroup,
    super.key,
  });

  final List<PlayerEntry> players;
  final bool isPairs;
  final bool showDealer;
  final int? dealerId;
  final NameError? Function(PlayerEntry) errorOf;
  final List<String> suggestions;

  /// "Grup Olarak Kaydet" isimler girildikten sonra çıkar.
  final bool canSaveGroup;

  /// Hedef sıra, taşınan öğe çıkarılmış listeye göredir.
  final void Function(int from, int to) onReorder;
  final ValueChanged<int> onDealer;
  final ValueChanged<String> onSuggestion;
  final VoidCallback onSaveGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final dealer = players.where((p) => p.id == dealerId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupPlayersTitle, style: theme.textTheme.titleSmall),
        Text(l10n.setupPlayersHint, style: muted),
        if (isPairs) Text(l10n.setupPairsHint, style: muted),
        const SizedBox(height: AppSpacing.xs),
        Card(
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: players.length,
            onReorderItem: onReorder,
            proxyDecorator: (child, index, animation) => Material(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: child,
            ),
            itemBuilder: (context, index) => _PlayerRow(
              key: ValueKey(players[index].id),
              entry: players[index],
              index: index,
              isPairs: isPairs,
              showDealer: showDealer,
              isDealer: players[index].id == dealerId,
              error: errorOf(players[index]),
              onDealer: () => onDealer(players[index].id),
            ),
          ),
        ),
        if (suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.suggestionsLabel, style: muted),
                for (final name in suggestions)
                  ActionChip(
                    label: Text(name),
                    onPressed: () => onSuggestion(name),
                  ),
              ],
            ),
          ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (showDealer && dealer != null)
              Text(l10n.firstDealerIs(dealer.controller.text), style: muted),
            // Buton yokken de satır aynı yükseklikte kalsın; çıkınca kayma olmaz.
            SizedBox(
              height: AppSizes.minTouchTarget,
              child: canSaveGroup
                  ? TextButton(
                      onPressed: onSaveGroup,
                      child: Text(l10n.saveAsGroupButton),
                    )
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.entry,
    required this.index,
    required this.isPairs,
    required this.showDealer,
    required this.isDealer,
    required this.error,
    required this.onDealer,
    super.key,
  });

  final PlayerEntry entry;
  final int index;
  final bool isPairs;
  final bool showDealer;
  final bool isDealer;
  final NameError? error;
  final VoidCallback onDealer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final name = entry.controller.text;
    final team = index.isEven ? l10n.teamLetterA : l10n.teamLetterB;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxs,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          // Odaktaki alanın imleç katmanı sürüklenen kopyayla çakışmasın.
          Listener(
            onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            child: ReorderableDragStartListener(
              index: index,
              child: Semantics(
                label: l10n.movePlayer(name),
                child: SizedBox(
                  key: ValueKey('player-handle-$index'),
                  width: AppSizes.minTouchTarget,
                  height: AppSizes.minTouchTarget,
                  child: Icon(
                    Icons.drag_indicator,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              key: ValueKey('player-name-$index'),
              controller: entry.controller,
              focusNode: entry.focus,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              onTap: () {
                if (entry.isDefaultName) {
                  entry.controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: entry.controller.text.length,
                  );
                }
              },
              decoration: InputDecoration(
                labelText: l10n.playerFieldLabel(index + 1),
                errorText: switch (error) {
                  NameError.empty => l10n.nameErrorEmpty,
                  NameError.tooLong => l10n.nameErrorTooLong(
                    Limits.maxPlayerNameLength,
                  ),
                  null => null,
                },
              ),
            ),
          ),
          if (isPairs)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Tooltip(
                message: l10n.teamLabel(team),
                child: CircleAvatar(
                  radius: AppSpacing.md,
                  backgroundColor: scheme.surfaceContainerHigh,
                  foregroundColor: scheme.onSurface,
                  child: Text(
                    team,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ),
          if (showDealer)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xxs),
              child: IconButton(
                tooltip: isDealer
                    ? l10n.firstDealerIs(name)
                    : l10n.makeFirstDealer(name),
                isSelected: isDealer,
                icon: const Icon(Icons.style_outlined),
                selectedIcon: const Icon(Icons.style),
                style: IconButton.styleFrom(
                  backgroundColor: isDealer ? scheme.primaryContainer : null,
                  foregroundColor: isDealer
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                onPressed: onDealer,
              ),
            ),
        ],
      ),
    );
  }
}
