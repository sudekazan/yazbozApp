import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';

/// Ekranı açık tutan ya da bırakan işlev. Testlerde değiştirilir.
final screenAwakeSwitchProvider = Provider<Future<void> Function(bool)>(
  (ref) =>
      (enable) => enable ? WakelockPlus.enable() : WakelockPlus.disable(),
);

/// Ayarlarda "Ekranı açık tut" açıkken, bu widget ekrandayken cihaz ekranı
/// kapanmaz. Ekrandan çıkınca ya da ayar kapanınca normale döner.
class KeepAwake extends ConsumerStatefulWidget {
  const KeepAwake({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<KeepAwake> createState() => _KeepAwakeState();
}

class _KeepAwakeState extends ConsumerState<KeepAwake> {
  bool _on = false;
  late final _switch = ref.read(screenAwakeSwitchProvider);

  Future<void> _apply(bool enable) async {
    if (enable == _on) return;
    _on = enable;
    try {
      await _switch(enable);
    } on Object {
      // Platform desteklemiyorsa (ya da testte) ekran yine çalışır.
    }
  }

  @override
  void initState() {
    super.initState();
    // Ayar henüz okunmadıysa varsayılan (açık) geçerli sayılır.
    final settings = ref.read(appSettingsProvider).value;
    _apply((settings ?? const AppSettingsData()).keepScreenOn);
  }

  @override
  void dispose() {
    if (_on) {
      _switch(false).catchError((Object _) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSettingsProvider, (_, next) {
      final settings = next.value;
      if (settings != null) _apply(settings.keepScreenOn);
    });
    return widget.child;
  }
}
