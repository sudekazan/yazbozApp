import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';

/// Uygulamanın kökü: tema, yerelleştirme ve yönlendirme.
class YazbozApp extends StatefulWidget {
  const YazbozApp({super.key, this.router});

  /// Testlerde başlangıç adresini değiştirmek için verilebilir.
  final GoRouter? router;

  @override
  State<YazbozApp> createState() => _YazbozAppState();
}

class _YazbozAppState extends State<YazbozApp> {
  late final GoRouter _router = widget.router ?? createAppRouter();

  @override
  void dispose() {
    if (widget.router == null) _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
