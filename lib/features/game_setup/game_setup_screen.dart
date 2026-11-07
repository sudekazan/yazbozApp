import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Oyun kurulumu. Form 5. aşamada eklenecek.
class GameSetupScreen extends StatelessWidget {
  const GameSetupScreen({required this.template, super.key});

  /// Adresten gelen şablon kimliği; 3. aşamada şablon listesine göre doğrulanacak.
  final String template;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(appBar: AppBar(title: Text(l10n.gameSetupTitle)));
  }
}
