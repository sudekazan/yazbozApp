import 'package:flutter/material.dart';

import '../../domain/models/game_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/template_labels.dart';

/// Oyun kurulumu. Form bir sonraki adımda eklenecek.
class GameSetupScreen extends StatelessWidget {
  const GameSetupScreen({required this.template, super.key});

  final GameTemplate template;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(appBar: AppBar(title: Text(template.title(l10n))));
  }
}
