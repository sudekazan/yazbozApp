import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_dimensions.dart';
import '../../l10n/generated/app_localizations.dart';

/// Oyun açılamadığında: kullanıcıyı suçlamayan açıklama ve çıkış yolu.
/// [actionLabel] ve [location] verilmezse ana sayfaya döner.
class GameProblem extends StatelessWidget {
  const GameProblem({
    required this.title,
    required this.message,
    this.actionLabel,
    this.location,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final String? location;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text(message, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => context.go(location ?? AppRoutes.home),
              child: Text(actionLabel ?? l10n.goHomeButton),
            ),
          ],
        ),
      ),
    );
  }
}
