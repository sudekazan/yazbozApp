import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

/// Ayarlarda "Titreşim" açıksa hafif dokunuş geri bildirimi verir.
extension Haptics on WidgetRef {
  /// Tuş ve seçim dokunuşları için hafif titreşim.
  void lightHaptic() {
    if (_enabled) HapticFeedback.selectionClick();
  }

  /// El kaydı gibi tamamlanan işler için biraz belirgin titreşim.
  void confirmHaptic() {
    if (_enabled) HapticFeedback.mediumImpact();
  }

  bool get _enabled => read(appSettingsProvider).value?.haptics ?? true;
}
