import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Oyun seçimi. Şablon kartları 5. aşamada eklenecek.
class GameSelectScreen extends StatelessWidget {
  const GameSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(appBar: AppBar(title: Text(l10n.gameSelectTitle)));
  }
}
