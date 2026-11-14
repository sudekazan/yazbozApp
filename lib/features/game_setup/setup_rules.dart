import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../domain/models/game_config.dart';
import '../../domain/models/rule_set.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/number_stepper.dart';
import 'game_setup_screen.dart' show numberFormatters, rulesChanged;
import 'setup_logic.dart';

/// Şablona göre ana seçenekler: kazanma yönü, hedef, el sayısı, Batak modu.
class SetupTemplateOptions extends StatelessWidget {
  const SetupTemplateOptions({
    required this.template,
    required this.rules,
    required this.target,
    required this.targetFocus,
    required this.targetError,
    required this.customTarget,
    required this.onCustomTarget,
    required this.onRule,
    super.key,
  });

  final GameTemplate template;
  final Map<String, Object?> rules;
  final TextEditingController target;
  final FocusNode targetFocus;
  final String? targetError;
  final bool customTarget;
  final ValueChanged<bool> onCustomTarget;
  final void Function(String key, Object? value) onRule;

  static const _tavlaTargets = [3, 5, 7, 11];
  static const _pistiTargets = [101, 151, 201];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (template) {
      GameTemplate.free => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(l10n.winDirectionLabel),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'highest', label: Text(l10n.winHighest)),
              ButtonSegment(value: 'lowest', label: Text(l10n.winLowest)),
            ],
            selected: {rules['winDirection']! as String},
            onSelectionChanged: (s) => onRule('winDirection', s.single),
          ),
          const SizedBox(height: AppSpacing.lg),
          _targetField(l10n, helper: l10n.freeTargetHelper),
        ],
      ),
      GameTemplate.okey101 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [FieldLabel(l10n.roundsLabel), _roundsStepper(l10n)],
      ),
      GameTemplate.tavla => _targetChoices(l10n, _tavlaTargets),
      GameTemplate.pisti => _targetChoices(l10n, _pistiTargets),
      GameTemplate.batak => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(l10n.batakModeLabel),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'plain', label: Text(l10n.batakPlain)),
              ButtonSegment(value: 'bidding', label: Text(l10n.batakBidding)),
            ],
            selected: {rules['mode']! as String},
            onSelectionChanged: (s) => onRule('mode', s.single),
          ),
          const SizedBox(height: AppSpacing.lg),
          FieldLabel(l10n.gameLengthLabel),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'rounds', label: Text(l10n.roundsLabel)),
              ButtonSegment(value: 'target', label: Text(l10n.targetLabel)),
            ],
            selected: {rules['length']! as String},
            onSelectionChanged: (s) => onRule('length', s.single),
          ),
          const SizedBox(height: AppSpacing.md),
          if (rules['length'] == 'target')
            _targetField(l10n)
          else
            _roundsStepper(l10n),
        ],
      ),
      GameTemplate.okey => const SizedBox.shrink(),
    };
  }

  Widget _roundsStepper(AppLocalizations l10n) => NumberStepper(
    value: rules['rounds']! as int,
    min: 1,
    decreaseLabel: l10n.decreaseRounds,
    increaseLabel: l10n.increaseRounds,
    onChanged: (n) => onRule('rounds', n),
  );

  Widget _targetField(AppLocalizations l10n, {String? helper}) => TextField(
    key: const ValueKey('target'),
    controller: target,
    focusNode: targetFocus,
    keyboardType: TextInputType.number,
    inputFormatters: numberFormatters(),
    decoration: InputDecoration(
      labelText: l10n.targetLabel,
      helperText: helper,
      helperMaxLines: 2,
      errorText: targetError,
    ),
  );

  Widget _targetChoices(AppLocalizations l10n, List<int> options) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldLabel(l10n.targetLabel),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final option in options)
            ChoiceChip(
              label: Text('$option'),
              selected: !customTarget && rules['target'] == option,
              onSelected: (_) {
                onCustomTarget(false);
                onRule('target', option);
              },
            ),
          ChoiceChip(
            label: Text(l10n.targetCustom),
            selected: customTarget,
            onSelected: (_) => onCustomTarget(true),
          ),
        ],
      ),
      if (customTarget) ...[
        const SizedBox(height: AppSpacing.md),
        _targetField(l10n),
      ],
    ],
  );
}

/// Kapalı gelen "Kurallar" bölümü: şablonun puan değerleri.
class SetupRules extends StatelessWidget {
  const SetupRules({
    required this.template,
    required this.rules,
    required this.defaults,
    required this.errors,
    required this.onRule,
    super.key,
  });

  final GameTemplate template;
  final Map<String, Object?> rules;
  final RuleSet defaults;
  final Map<String, String?> errors;
  final void Function(String key, Object? value, String? error) onRule;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final changed =
        rulesChanged(rules, defaults) || errors.values.any((e) => e != null);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // Kapatılıp açılınca yazılan değer kaybolmasın.
        maintainState: true,
        expansionAnimationStyle: AnimationStyle(
          duration: AppDurations.resolve(context, AppDurations.medium),
          reverseDuration: AppDurations.resolve(context, AppDurations.medium),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(l10n.rulesTitle),
        subtitle: Text(
          changed ? l10n.rulesChangedSubtitle : l10n.rulesDefaultSubtitle,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          for (final field in ruleFields(template))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: TextFormField(
                key: ValueKey('rule-${field.key}'),
                initialValue: '${rules[field.key]}',
                keyboardType: TextInputType.numberWithOptions(
                  signed: field.allowsNegative,
                ),
                inputFormatters: numberFormatters(
                  allowNegative: field.allowsNegative,
                ),
                decoration: InputDecoration(
                  labelText: ruleLabel(l10n, field.key),
                  errorText: errors[field.key],
                ),
                onChanged: (text) {
                  final value = int.tryParse(text);
                  final error = value == null
                      ? l10n.ruleNumberError
                      : field.accepts(value)
                      ? null
                      : l10n.ruleRangeError(field.min, field.max);
                  onRule(field.key, value, error);
                },
              ),
            ),
          if (template == GameTemplate.tavla)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.ruleDoublingCube),
              value: rules['doublingCube'] == true,
              onChanged: (v) => onRule('doublingCube', v, null),
            ),
        ],
      ),
    );
  }
}

String ruleLabel(AppLocalizations l10n, String key) => switch (key) {
  'startingPoints' => l10n.ruleStartingPoints,
  'normalFinish' => l10n.ruleNormalFinish,
  'okeyFinish' => l10n.ruleOkeyFinish,
  'pairsFinish' => l10n.rulePairsFinish,
  'okeyPairsFinish' => l10n.ruleOkeyPairsFinish,
  'indicator' => l10n.ruleIndicator,
  'finishPoints' => l10n.ruleFinishPoints,
  'notOpenedPoints' => l10n.ruleNotOpenedPoints,
  'okeyMultiplier' => l10n.ruleOkeyMultiplier,
  'handFinishMultiplier' => l10n.ruleHandFinishMultiplier,
  'pairsFinishMultiplier' => l10n.rulePairsFinishMultiplier,
  'pairsRemainingMultiplier' => l10n.rulePairsRemainingMultiplier,
  'penaltyTileToMeld' => l10n.rulePenaltyTileToMeld,
  'penaltyDiscardOkey' => l10n.rulePenaltyDiscardOkey,
  'penaltyWrongOpen' => l10n.rulePenaltyWrongOpen,
  'normalPoints' => l10n.ruleNormalPoints,
  'marsPoints' => l10n.ruleMarsPoints,
  'pisti' => l10n.rulePisti,
  'jackPisti' => l10n.ruleJackPisti,
  'majority' => l10n.ruleMajority,
  'clubTwo' => l10n.ruleClubTwo,
  'diamondTen' => l10n.ruleDiamondTen,
  'ace' => l10n.ruleAce,
  'jack' => l10n.ruleJack,
  'minBid' => l10n.ruleMinBid,
  'zeroTricksPoints' => l10n.ruleZeroTricksPoints,
  _ => key,
};
