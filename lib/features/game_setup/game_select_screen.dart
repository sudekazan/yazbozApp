import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_dimensions.dart';
import '../../domain/models/game_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/template_labels.dart';

/// Oyun seçimi: altı şablon, iki sütunlu büyük kartlar.
class GameSelectScreen extends StatelessWidget {
  const GameSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const templates = GameTemplate.values;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.gameSelectTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            // Satırlar kendi içeriği kadar uzar; büyük yazıda kart taşmaz.
            for (var i = 0; i < templates.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _TemplateCard(templates[i])),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: i + 1 < templates.length
                            ? _TemplateCard(templates[i + 1])
                            : const SizedBox(),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard(this.template);

  final GameTemplate template;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AppRoutes.setup(template.name)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.templateCardMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: AppSizes.templateIconBox,
                  height: AppSizes.templateIconBox,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(template.icon, color: scheme.onSurface),
                ),
                const SizedBox(height: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.title(l10n),
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      template.description(l10n),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
