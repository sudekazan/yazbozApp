import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';

/// Uygulamanın kökü: tema, yerelleştirme ve ana ekran.
class YazbozApp extends StatelessWidget {
  const YazbozApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _StartScreen(),
    );
  }
}

class _StartScreen extends StatelessWidget {
  const _StartScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(appBar: AppBar(title: Text(l10n.appTitle)));
  }
}
