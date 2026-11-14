import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_dimensions.dart';
import '../../data/repositories/group_repository.dart';
import '../../domain/models/game_config.dart';
import '../../domain/validation.dart';
import '../../l10n/generated/app_localizations.dart';

/// Kayıtlı grubu düzenleme ekranını açar: ad, isim ekle/çıkar, sırala.
Future<void> showGroupEditor(
  BuildContext context,
  WidgetRef ref,
  PlayerGroup group,
) => showDialog<void>(
  context: context,
  useSafeArea: false,
  builder: (context) => Dialog.fullscreen(child: _GroupEditor(group: group)),
);

class _Member {
  _Member(String text) : controller = TextEditingController(text: text);

  /// Sürükleme sırasında alanların karışmaması için kalıcı anahtar.
  final Key key = UniqueKey();
  final TextEditingController controller;
}

class _GroupEditor extends ConsumerStatefulWidget {
  const _GroupEditor({required this.group});

  final PlayerGroup group;

  @override
  ConsumerState<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends ConsumerState<_GroupEditor> {
  late final _name = TextEditingController(text: widget.group.name);
  late final List<_Member> _members = [
    for (final m in widget.group.members) _Member(m),
  ];
  bool _attempted = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    for (final m in _members) {
      m.controller.dispose();
    }
    super.dispose();
  }

  String? _nameError(AppLocalizations l10n, String text, int max) =>
      switch (validatePlayerName(text)) {
        NameError.empty => l10n.nameErrorEmpty,
        NameError.tooLong => l10n.nameErrorTooLong(max),
        null => null,
      };

  String? _groupNameError(AppLocalizations l10n) =>
      switch (validateGroupName(_name.text)) {
        NameError.empty => l10n.nameErrorEmpty,
        NameError.tooLong => l10n.nameErrorTooLong(Limits.maxGroupNameLength),
        null => null,
      };

  bool get _countOk =>
      _members.length >= GameConfig.minSeats &&
      _members.length <= GameConfig.maxSeats;

  bool get _valid =>
      _groupNameError(AppLocalizations.of(context)) == null &&
      _countOk &&
      _members.every((m) => validatePlayerName(m.controller.text) == null);

  Future<void> _save() async {
    if (_saving) return;
    if (!_valid) {
      setState(() => _attempted = true);
      return;
    }
    setState(() => _saving = true);
    await ref
        .read(groupRepositoryProvider)
        .updateGroup(
          widget.group.id,
          name: _name.text,
          members: [for (final m in _members) m.controller.text],
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.closeTooltip,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.editGroupTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ReorderableListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                buildDefaultDragHandles: false,
                header: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const ValueKey('group-name'),
                        controller: _name,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: l10n.groupNameLabel,
                          errorText: _attempted ? _groupNameError(l10n) : null,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.setupPlayersHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                footer: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_attempted && !_countOk)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: AppSizes.iconSmall,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  l10n.groupMemberCountError(
                                    GameConfig.minSeats,
                                    GameConfig.maxSeats,
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_members.length < GameConfig.maxSeats)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: () => setState(
                              () => _members.add(
                                _Member(
                                  l10n.defaultPlayerName(_members.length + 1),
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: Text(l10n.addPlayerButton),
                          ),
                        ),
                    ],
                  ),
                ),
                onReorderItem: (from, to) => setState(
                  () => _members.insert(to, _members.removeAt(from)),
                ),
                children: [
                  for (var i = 0; i < _members.length; i++)
                    Padding(
                      key: _members[i].key,
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _members[i].controller,
                              onChanged: (_) => setState(() {}),
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: l10n.playerFieldLabel(i + 1),
                                errorText: _attempted
                                    ? _nameError(
                                        l10n,
                                        _members[i].controller.text,
                                        Limits.maxPlayerNameLength,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: SizedBox(
                              width: AppSizes.minTouchTarget,
                              height: AppSizes.minTouchTarget,
                              child: Tooltip(
                                message: l10n.movePlayer(
                                  _members[i].controller.text,
                                ),
                                child: const Icon(Icons.drag_handle),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.removePlayerTooltip(
                              _members[i].controller.text,
                            ),
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _members.length > GameConfig.minSeats
                                ? () => setState(() {
                                    _members.removeAt(i).controller.dispose();
                                  })
                                : null,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.saveButton),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
