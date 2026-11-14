import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_dimensions.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../scoreboard/scoreboard_dialogs.dart' show confirmAction;
import 'group_editor.dart';

/// Ayarlar: tema, ekran, titreşim, dağıtıcı göstergesi, kayıtlı gruplar.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettingsData();
    final groups = ref.watch(playerGroupsProvider).value ?? const [];

    void save(AppSettingsData next) =>
        ref.read(settingsRepositoryProvider).save(next);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.xs,
            AppSpacing.screen,
            AppSpacing.xl,
          ),
          children: [
            _Heading(l10n.settingsThemeTitle),
            SegmentedButton<AppThemeMode>(
              segments: [
                ButtonSegment(
                  value: AppThemeMode.system,
                  label: Text(l10n.themeSystem),
                ),
                ButtonSegment(
                  value: AppThemeMode.light,
                  label: Text(l10n.themeLight),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  label: Text(l10n.themeDark),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) =>
                  save(settings.copyWith(themeMode: s.single)),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Heading(l10n.settingsGameTitle),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(l10n.keepScreenOnTitle),
                    subtitle: Text(l10n.keepScreenOnHint),
                    value: settings.keepScreenOn,
                    onChanged: (v) => save(settings.copyWith(keepScreenOn: v)),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(l10n.hapticsTitle),
                    subtitle: Text(l10n.hapticsHint),
                    value: settings.haptics,
                    onChanged: (v) => save(settings.copyWith(haptics: v)),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(l10n.dealerDefaultTitle),
                    subtitle: Text(l10n.dealerDefaultHint),
                    value: settings.dealerIndicatorDefault,
                    onChanged: (v) =>
                        save(settings.copyWith(dealerIndicatorDefault: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Heading(l10n.setupGroupsTitle),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: Text(
                  l10n.groupsEmptyMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < groups.length; i++) ...[
                      if (i > 0) const Divider(),
                      _GroupTile(groups[i]),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                minVerticalPadding: AppSpacing.sm,
                title: Text(l10n.aboutTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.appTitle),
                    content: Text(l10n.aboutMessage),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.closeTooltip),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xxs,
      0,
      AppSpacing.xxs,
      AppSpacing.xs,
    ),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class _GroupTile extends ConsumerWidget {
  const _GroupTile(this.group);

  final PlayerGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListTile(
      minVerticalPadding: AppSpacing.sm,
      title: Text(group.name),
      subtitle: Text(
        group.members.join(', '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => showGroupEditor(context, ref, group),
      trailing: IconButton(
        tooltip: l10n.deleteGroupTooltip(group.name),
        icon: Icon(Icons.delete_outline, color: theme.colorScheme.onSurface),
        onPressed: () => _delete(context, ref),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(groupRepositoryProvider);
    final confirmed = await confirmAction(
      context,
      title: l10n.deleteGroupTitle(group.name),
      message: l10n.deleteGroupMessage(group.members.length),
      confirmLabel: l10n.deleteGroupButton,
    );
    if (!confirmed) return;
    await repo.deleteGroup(group.id);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.groupDeletedMessage(group.name)),
          persist: false,
          action: SnackBarAction(
            label: l10n.undoButton,
            onPressed: () => repo.createGroup(group.name, group.members),
          ),
        ),
      );
  }
}
