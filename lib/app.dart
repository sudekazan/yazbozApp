import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/settings_repository.dart';
import 'l10n/generated/app_localizations.dart';

/// Uygulamanın kökü: tema (ayarlardan), yerelleştirme ve yönlendirme.
class YazbozApp extends ConsumerStatefulWidget {
  const YazbozApp({super.key, this.router});

  /// Testlerde başlangıç adresini değiştirmek için verilebilir.
  final GoRouter? router;

  @override
  ConsumerState<YazbozApp> createState() => _YazbozAppState();
}

class _YazbozAppState extends ConsumerState<YazbozApp> {
  late final GoRouter _router = widget.router ?? createAppRouter();

  @override
  void initState() {
    super.initState();
    // Önceki oturumda silinip "Geri Al" beklenen oyunlar kalıcı silinir.
    unawaited(ref.read(gameRepositoryProvider).purgeDeletedGames());
  }

  @override
  void dispose() {
    if (widget.router == null) _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = switch (ref.watch(appSettingsProvider).value?.themeMode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system || null => ThemeMode.system,
    };
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
