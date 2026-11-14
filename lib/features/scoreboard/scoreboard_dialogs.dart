import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/game_config.dart';
import '../../domain/models/rule_set.dart';
import '../../domain/validation.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/score_format.dart';
import '../game_setup/setup_logic.dart' show ruleFields;
import '../game_setup/setup_rules.dart' show ruleLabel;
import 'scoreboard_logic.dart';

/// Ne yapılacağını söyleyen onay diyaloğu; onaylanırsa `true`.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelButton),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Oyuncu ismi sorulan diyalog; "Kaydet" geçerli ismi döner.
class PlayerNameDialog extends StatefulWidget {
  const PlayerNameDialog({
    required this.title,
    required this.label,
    required this.helper,
    this.initialName = '',
    super.key,
  });

  final String title;
  final String label;
  final String helper;
  final String initialName;

  @override
  State<PlayerNameDialog> createState() => _PlayerNameDialogState();
}

class _PlayerNameDialogState extends State<PlayerNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialName.length,
    );
  NameError? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final error = validatePlayerName(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(normalizeName(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('player-name'),
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helper,
          helperMaxLines: 3,
          errorMaxLines: 3,
          errorText: switch (_error) {
            NameError.empty => l10n.nameErrorEmpty,
            NameError.tooLong => l10n.nameErrorTooLong(
              Limits.maxPlayerNameLength,
            ),
            null => null,
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        TextButton(onPressed: _save, child: Text(l10n.saveButton)),
      ],
    );
  }
}

enum PlayerAction { replace, rename, makeDealer }

/// Sütuna dokununca açılan seçenekler. Takım sütununda her oyuncu için
/// ayrı seçenekler çıkar. Seçilen eylem ve koltuk döner.
Future<(PlayerAction, int)?> showPlayerSheet(
  BuildContext context, {
  required ScoreColumn column,
  required bool canMakeDealer,
}) => showModalBottomSheet<(PlayerAction, int)>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < column.seats.length; i++) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                i == 0 ? 0 : AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(column.names[i], style: theme.textTheme.titleMedium),
            ),
            _ActionTile(
              icon: Icons.swap_horiz,
              label: l10n.replacePlayerButton,
              result: (PlayerAction.replace, column.seats[i]),
            ),
            _ActionTile(
              icon: Icons.edit_outlined,
              label: l10n.renamePlayerButton,
              result: (PlayerAction.rename, column.seats[i]),
            ),
            if (canMakeDealer && column.dealerSeat != column.seats[i])
              _ActionTile(
                icon: Icons.style_outlined,
                label: l10n.makeDealerButton,
                result: (PlayerAction.makeDealer, column.seats[i]),
              ),
          ],
        ],
      ),
    );
  },
);

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.result,
  });

  final IconData icon;
  final String label;
  final (PlayerAction, int) result;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    leading: Icon(icon),
    title: Text(label),
    onTap: () => Navigator.of(context).pop(result),
  );
}

/// Oyunun kuralları, salt okunur. Kurallar sadece kurulumda değişir.
Future<void> showRulesSheet(
  BuildContext context, {
  required GameTemplate template,
  required RuleSet rules,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = _ruleItems(l10n, template, rules.toJson());
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.rulesTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: MergeSemantics(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        items[i].$1,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      items[i].$2,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  },
);

/// Kural setini "etiket – değer" satırlarına çevirir.
List<(String, String)> _ruleItems(
  AppLocalizations l10n,
  GameTemplate template,
  Map<String, Object?> json,
) {
  String number(String key) {
    final value = json[key];
    return value is int ? formatPoints(value) : l10n.ruleNone;
  }

  return [
    ...switch (template) {
      GameTemplate.free => [
        (
          l10n.winDirectionLabel,
          json['winDirection'] == 'lowest' ? l10n.winLowest : l10n.winHighest,
        ),
        (l10n.targetLabel, number('target')),
      ],
      GameTemplate.okey => const <(String, String)>[],
      GameTemplate.okey101 => [(l10n.roundsLabel, number('rounds'))],
      GameTemplate.tavla => [
        (l10n.targetLabel, number('target')),
        (
          l10n.ruleDoublingCube,
          json['doublingCube'] == true ? l10n.ruleOn : l10n.ruleOff,
        ),
      ],
      GameTemplate.pisti => [(l10n.targetLabel, number('target'))],
      GameTemplate.batak => [
        (
          l10n.batakModeLabel,
          json['mode'] == 'bidding' ? l10n.batakBidding : l10n.batakPlain,
        ),
        if (json['length'] == 'target')
          (l10n.targetLabel, number('target'))
        else
          (l10n.roundsLabel, number('rounds')),
      ],
    },
    for (final field in ruleFields(template))
      (ruleLabel(l10n, field.key), number(field.key)),
  ];
}
