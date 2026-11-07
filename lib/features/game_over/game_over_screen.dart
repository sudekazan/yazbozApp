import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Oyun sonu. İçerik 5. aşamada eklenecek.
class GameOverScreen extends StatelessWidget {
  const GameOverScreen({required this.gameId, super.key});

  final int gameId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(appBar: AppBar(title: Text(l10n.gameOverTitle)));
  }
}
