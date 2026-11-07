import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Ayarlar. Seçenekler 5. aşamada eklenecek.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(appBar: AppBar(title: Text(l10n.settingsTitle)));
  }
}
