import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Skor tablosu. İçerik 5. aşamada eklenecek.
class ScoreboardScreen extends StatelessWidget {
  const ScoreboardScreen({required this.gameId, super.key});

  final int gameId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(appBar: AppBar(title: Text(l10n.scoreboardTitle)));
  }
}
