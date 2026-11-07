import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_dimensions.dart';
import '../../data/repositories/group_repository.dart';
import '../../domain/models/game_config.dart';
import '../../domain/models/rule_set.dart';
import '../../domain/rules/rules_registry.dart';
import '../../domain/validation.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/number_stepper.dart';
import '../common/template_labels.dart';
import 'setup_logic.dart';
import 'setup_players.dart';
import 'setup_rules.dart';

/// Oyun kurulumu: oyuncular, oynanış, hedef ve kurallar.
class GameSetupScreen extends ConsumerStatefulWidget {
  const GameSetupScreen({required this.template, super.key});

  final GameTemplate template;

  @override
  ConsumerState<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends ConsumerState<GameSetupScreen> {
  GameTemplate get _template => widget.template;

  PlayMode _mode = PlayMode.individual;
  final List<PlayerEntry> _players = [];
  int _nextEntryId = 0;
  int? _dealerId;
  PlayerEntry? _lastFocused;

  late Map<String, Object?> _rules;
  final _target = TextEditingController();
  final _targetFocus = FocusNode();
  String? _targetError;
  final Map<String, String?> _ruleErrors = {};
  bool _submitted = false;
  int? _usedGroupId;

  /// Çift dokunuşta iki oyun açılmasın.
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _resize(defaultSeatCount(_template, _mode));
    _rules = rulesFor(_template).defaultRules(_config).toJson();
  }

  @override
  void dispose() {
    for (final p in _players) {
      p.dispose();
    }
    _target.dispose();
    _targetFocus.dispose();
    super.dispose();
  }

  GameConfig get _config => GameConfig(
    template: _template,
    seatCount: _players.length,
    playMode: _mode,
  );

  // -------------------------------------------------------------- oyuncular

  /// Yerelleştirme ilk karede hazır olur; o ana kadar varsayılan isim boş.
  bool _localized = false;

  String _defaultName(int number) =>
      _localized ? AppLocalizations.of(context).defaultPlayerName(number) : '';

  void _resize(int count) {
    while (_players.length < count) {
      final entry = PlayerEntry(
        id: _nextEntryId++,
        defaultText: _defaultName(_players.length + 1),
      );
      entry.focus.addListener(() {
        if (entry.focus.hasFocus) _lastFocused = entry;
      });
      entry.controller.addListener(() => setState(() {}));
      _players.add(entry);
    }
    while (_players.length > count) {
      final removed = _players.removeLast();
      if (_lastFocused == removed) _lastFocused = null;
      removed.dispose();
    }
    if (!_players.any((p) => p.id == _dealerId)) _dealerId = _players.first.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_localized) return;
    _localized = true;
    for (var i = 0; i < _players.length; i++) {
      final name = _defaultName(i + 1);
      _players[i]
        ..defaultText = name
        ..controller.text = name;
    }
  }

  void _setMode(PlayMode mode) {
    setState(() {
      _mode = mode;
      if (!allowedSeatCounts(_template, mode).contains(_players.length)) {
        _resize(defaultSeatCount(_template, mode));
      }
    });
  }

  void _applyGroup(PlayerGroup group) {
    final l10n = AppLocalizations.of(context);
    final mode = fitGroup(_template, _mode, group.members.length);
    if (mode == null) {
      final counts = anySeatCounts(_template);
      final allowed = counts.length == 1
          ? '${counts.single}'
          : l10n.orList(
              counts.sublist(0, counts.length - 1).join(', '),
              '${counts.last}',
            );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.groupDoesNotFit(group.name, group.members.length, allowed),
          ),
        ),
      );
      return;
    }
    setState(() {
      _mode = mode;
      _resize(group.members.length);
      for (var i = 0; i < group.members.length; i++) {
        _players[i].controller.text = group.members[i];
      }
      _dealerId = _players.first.id;
      _usedGroupId = group.id;
    });
  }

  void _applySuggestion(String name) {
    final target =
        _lastFocused ??
        _players.firstWhere(
          (p) => p.isDefaultName,
          orElse: () => _players.last,
        );
    target.controller.text = name;
    _lastFocused = null;

    // Sıradaki öneri, hedeften sonraki ilk varsayılan isimli alana yazılsın;
    // odak da oraya geçsin ki aynı alanın üstüne yazılmasın.
    final start = _players.indexOf(target) + 1;
    final next = [
      ..._players.skip(start),
      ..._players.take(start),
    ].where((p) => p.isDefaultName).firstOrNull;
    if (next != null && target.focus.hasFocus) {
      next.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: next.controller.text.length,
      );
      next.focus.requestFocus();
    }
    setState(() {});
  }

  NameError? _nameError(PlayerEntry p) =>
      _submitted ? validatePlayerName(p.controller.text) : null;

  // --------------------------------------------------------------- başlatma

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _submitted = true);
    final l10n = AppLocalizations.of(context);
    final invalidName = _players
        .where((p) => validatePlayerName(p.controller.text) != null)
        .firstOrNull;
    _targetError = _validateTarget(l10n);
    if (invalidName != null ||
        _targetError != null ||
        _ruleErrors.values.any((e) => e != null)) {
      // Hatalı alan ekran dışında kalmasın: odaklanınca görünüre kayar.
      if (invalidName != null) {
        invalidName.focus.requestFocus();
      } else if (_targetError != null) {
        _targetFocus.requestFocus();
      }
      setState(() {});
      return;
    }

    final rules = rulesFor(_template).ruleSetFromJson(_rules);
    if (rules.validate().isNotEmpty) return;
    _starting = true;
    try {
      final settings = await ref.read(settingsRepositoryProvider).load();
      final id = await ref
          .read(gameRepositoryProvider)
          .createGame(
            config: _config,
            rules: rules,
            playerNames: [for (final p in _players) p.controller.text],
            firstDealerSeat: _players.indexWhere((p) => p.id == _dealerId),
            dealerIndicator: settings.dealerIndicatorDefault,
          );
      if (_usedGroupId != null) {
        await ref.read(groupRepositoryProvider).markUsed(_usedGroupId!);
      }
      if (mounted) context.go(AppRoutes.game(id));
    } finally {
      _starting = false;
    }
  }

  /// Hedef alanı: Serbest'te isteğe bağlı, Batak'ın hedef modunda ve Tavla/
  /// Pişti'nin "Özel" seçeneğinde zorunlu.
  String? _validateTarget(AppLocalizations l10n) {
    final usesField = switch (_template) {
      GameTemplate.free => true,
      GameTemplate.batak => _rules['length'] == 'target',
      GameTemplate.tavla || GameTemplate.pisti => _customTarget,
      _ => false,
    };
    if (!usesField) return null;
    final text = _target.text.trim();
    if (text.isEmpty) {
      if (_template == GameTemplate.free) {
        _rules['target'] = null;
        return null;
      }
      return l10n.targetRequired;
    }
    final value = int.tryParse(text);
    if (value == null || value < 1 || value > Limits.maxAbsPoints) {
      return l10n.ruleRangeError(1, Limits.maxAbsPoints);
    }
    _rules['target'] = value;
    return null;
  }

  bool _customTarget = false;

  // ----------------------------------------------------------------- arayüz

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = ref.watch(playerGroupsProvider).value ?? const [];
    final usedNames = {for (final p in _players) p.controller.text.trim()};
    final suggestions = (ref.watch(nameSuggestionsProvider).value ?? const [])
        .where((n) => !usedNames.contains(n))
        .take(6)
        .toList();
    final counts = allowedSeatCounts(_template, _mode);

    return Scaffold(
      appBar: AppBar(title: Text(_template.title(l10n))),
      body: Column(
        children: [
          Expanded(
            // Tüm alanlar hep kurulu kalsın: hatalı alana odaklanınca ekran
            // oraya kayabilsin. Liste kısa (en çok 8 oyuncu + kurallar).
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.xs,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (groups.isNotEmpty) ...[
                    FieldLabel(l10n.setupGroupsTitle),
                    SizedBox(
                      height: AppSizes.minTouchTarget,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: groups.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.xs),
                        itemBuilder: (context, i) => ActionChip(
                          label: Text(groups[i].name),
                          onPressed: () => _applyGroup(groups[i]),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (counts.length > 1 || supportsPairs(_template)) ...[
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        if (counts.length > 1)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FieldLabel(l10n.setupPlayerCount),
                              NumberStepper(
                                value: _players.length,
                                min: counts.first,
                                max: counts.last,
                                decreaseLabel: l10n.decreasePlayerCount,
                                increaseLabel: l10n.increasePlayerCount,
                                onChanged: (n) => setState(() => _resize(n)),
                              ),
                            ],
                          ),
                        if (supportsPairs(_template))
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FieldLabel(l10n.setupPlayMode),
                              SegmentedButton<PlayMode>(
                                segments: [
                                  ButtonSegment(
                                    value: PlayMode.individual,
                                    label: Text(l10n.playModeIndividual),
                                  ),
                                  ButtonSegment(
                                    value: PlayMode.pairs,
                                    label: Text(l10n.playModePairs),
                                  ),
                                ],
                                selected: {_mode},
                                onSelectionChanged: (s) => _setMode(s.single),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  SetupPlayers(
                    players: _players,
                    isPairs: _mode == PlayMode.pairs,
                    showDealer: showsDealer(_template),
                    dealerId: _dealerId,
                    errorOf: _nameError,
                    suggestions: suggestions,
                    canSaveGroup: _players.any((p) => !p.isDefaultName),
                    onReorder: (from, to) => setState(() {
                      final moved = _players.removeAt(from);
                      _players.insert(to, moved);
                    }),
                    onDealer: (id) => setState(() => _dealerId = id),
                    onSuggestion: _applySuggestion,
                    onSaveGroup: _saveGroup,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SetupTemplateOptions(
                    template: _template,
                    rules: _rules,
                    target: _target,
                    targetFocus: _targetFocus,
                    targetError: _targetError,
                    customTarget: _customTarget,
                    onCustomTarget: (custom) =>
                        setState(() => _customTarget = custom),
                    onRule: (key, value) => setState(() => _rules[key] = value),
                  ),
                  if (ruleFields(_template).isNotEmpty ||
                      _template == GameTemplate.tavla) ...[
                    const SizedBox(height: AppSpacing.lg),
                    SetupRules(
                      template: _template,
                      rules: _rules,
                      defaults: rulesFor(_template).defaultRules(_config),
                      errors: _ruleErrors,
                      onRule: (key, value, error) => setState(() {
                        _ruleErrors[key] = error;
                        if (error == null) _rules[key] = value;
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _BottomBar(
            child: FilledButton(
              onPressed: _start,
              child: Text(l10n.startGameButton),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveGroup() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const GroupNameDialog(),
    );
    if (name == null) return;
    try {
      await ref.read(groupRepositoryProvider).createGroup(name, [
        for (final p in _players) p.controller.text,
      ]);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.groupSavedMessage(normalizeName(name)))),
      );
    } on InvalidGroupException {
      // İsimlerden biri geçersiz: hatalar alanların altında görünsün.
      setState(() => _submitted = true);
    }
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.sm,
            AppSpacing.screen,
            AppSpacing.sm,
          ),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

/// Grup adı sorulan diyalog; "Kaydet" geçerli adı döner.
class GroupNameDialog extends StatefulWidget {
  const GroupNameDialog({super.key});

  @override
  State<GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<GroupNameDialog> {
  final _controller = TextEditingController();
  NameError? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final error = validateGroupName(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.saveAsGroupButton),
      content: TextField(
        key: const ValueKey('group-name'),
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: l10n.groupNameLabel,
          errorText: switch (_error) {
            NameError.empty => l10n.nameErrorEmpty,
            NameError.tooLong => l10n.nameErrorTooLong(
              Limits.maxGroupNameLength,
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

/// Sayı alanları için: rakam ve isteğe bağlı başta eksi.
List<TextInputFormatter> numberFormatters({bool allowNegative = false}) => [
  FilteringTextInputFormatter.allow(
    allowNegative ? RegExp(r'^-?\d*') : RegExp(r'\d*'),
  ),
  LengthLimitingTextInputFormatter(6),
];

/// Kural setinin varsayılandan farklı olup olmadığı.
bool rulesChanged(Map<String, Object?> rules, RuleSet defaults) {
  final base = defaults.toJson();
  return rules.entries.any((e) => base[e.key] != e.value);
}
