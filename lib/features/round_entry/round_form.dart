import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_dimensions.dart';
import '../../data/repositories/game_models.dart';
import '../../domain/models/round.dart';
import '../../domain/validation.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/template_labels.dart';
import 'entry_widgets.dart';

/// Bir şablonun el girişi formu. Ortak iskeleti (başlık, kaydırılan içerik,
/// hata, önizleme, tuş takımı, Kaydet) [RoundFormState] kurar.
abstract class RoundForm extends ConsumerStatefulWidget {
  const RoundForm({required this.game, this.editing, super.key});

  final GameSnapshot game;

  /// Düzenlenen el; yeni elde `null`.
  final StoredRound? editing;
}

abstract class RoundFormState<W extends RoundForm> extends ConsumerState<W> {
  bool _saving = false;

  /// Kaydet'e bir kez basıldıktan sonra hatalar canlı gösterilir.
  bool _attempted = false;
  bool _failed = false;

  GameSnapshot get game => widget.game;

  /// Tabloda görünen el numarası.
  late final int roundNumber = widget.editing == null
      ? game.rounds.length + 1
      : game.rounds.indexWhere((r) => r.id == widget.editing!.id) + 1;

  /// Düzenlenen elin girdisi, beklenen türdeyse.
  T? editingInput<T extends RoundInput>() {
    final input = widget.editing?.round.input;
    return input is T ? input : null;
  }

  /// Bu elde oturanlar, koltuk sırasıyla.
  late final List<String> seatNames = game.seating.namesForRound(roundNumber);

  /// Bu elde her sütunun adı (takımsa "Ayşe & Zeynep").
  late final List<String> unitNames = [
    for (final unit in game.engine.units(game.config))
      columnName(AppLocalizations.of(context), [
        for (final seat in unit.seats) seatNames[seat],
      ]),
  ];

  /// Formun kendi eksikleri (kazanan seçilmedi gibi). Boşsa [buildInput]
  /// çağrılabilir.
  List<String> formErrors(AppLocalizations l10n) => const [];

  RoundInput buildInput();

  Widget buildBody(BuildContext context);

  /// Sayı girilen formlarda tuş takımı.
  Widget? buildKeypad(BuildContext context) => null;

  /// "Bu elin puanları" kutusu gösterilsin mi.
  bool get showsPreview => true;

  /// Girdi tamam ve geçerliyse bu elin puanları; değilse `null`.
  List<int>? get previewPoints {
    if (formErrors(AppLocalizations.of(context)).isNotEmpty) return null;
    final input = buildInput();
    final engine = game.engine;
    if (engine.validate(input, game.rules, game.config).isNotEmpty) {
      return null;
    }
    return engine.scoreValidRound(input, game.rules, game.config).points;
  }

  List<String> _errors(AppLocalizations l10n) {
    final own = formErrors(l10n);
    if (own.isNotEmpty) return own;
    final errors = game.engine.validate(buildInput(), game.rules, game.config);
    return {for (final e in errors) roundErrorText(l10n, e)}.toList();
  }

  /// Girdiyi değiştirir; eski "kaydedilemedi" uyarısı kalkar.
  void change(VoidCallback fn) => setState(() {
    fn();
    _failed = false;
  });

  Future<void> _save() async {
    if (_saving) return;
    if (_errors(AppLocalizations.of(context)).isNotEmpty) {
      setState(() => _attempted = true);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(gameRepositoryProvider);
    final editing = widget.editing;
    final input = buildInput();
    try {
      if (editing == null) {
        await repo.addRound(game.id, input);
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
    final errors = [
      if (_attempted) ..._errors(l10n),
      if (_failed) l10n.roundSaveError,
    ];
    final keypad = buildKeypad(context);

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
                      l10n.roundEntryTitle(roundNumber),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                0,
                AppSpacing.screen,
                AppSpacing.md,
              ),
              child: buildBody(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.xs,
              AppSpacing.screen,
              AppSpacing.screen,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (errors.isNotEmpty) ...[
                  EntryErrors(errors),
                  const SizedBox(height: AppSpacing.xs),
                ],
                if (showsPreview) ...[
                  PointsPreview(names: unitNames, points: previewPoints),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (keypad != null) ...[
                  keypad,
                  const SizedBox(height: AppSpacing.xxs),
                ],
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

/// Motorun hatasını kullanıcıyı suçlamayan, çözüm söyleyen metne çevirir.
String roundErrorText(
  AppLocalizations l10n,
  RoundError error,
) => switch (error.code) {
  RoundErrorCode.tricksTotalMismatch => l10n.errorTricksTotal(
    error.expected ?? 0,
    error.actual ?? 0,
  ),
  RoundErrorCode.bidderRequired => l10n.errorBidderRequired,
  RoundErrorCode.clubTwoOwnerRequired => l10n.errorClubTwoRequired,
  RoundErrorCode.diamondTenOwnerRequired => l10n.errorDiamondTenRequired,
  RoundErrorCode.acesOverLimit => l10n.errorAcesOverLimit(error.actual ?? 0),
  RoundErrorCode.jacksOverLimit => l10n.errorJacksOverLimit(error.actual ?? 0),
  RoundErrorCode.finishWithoutFinisher => l10n.errorFinisherRequired,
  RoundErrorCode.pointsOutOfRange ||
  RoundErrorCode.remainingOutOfRange ||
  RoundErrorCode.penaltyAmountOutOfRange => l10n.errorPointsTooLarge(
    Limits.maxAbsPoints,
  ),
  _ => l10n.roundSaveError,
};
