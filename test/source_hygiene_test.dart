import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kaynak kodda görünmez ya da yön değiştiren karakter olmamalı
/// ("trojan source"): okunanla çalışan kod farklı olabilir. Gerekirse
/// kaçış dizisiyle (ters bölü, u ve kod) yazılır.
void main() {
  const forbidden = <int>{
    0x200B, // sıfır genişlikli boşluk
    0x2060, // kelime birleştirici
    0xFEFF, // BOM
    0x202A, 0x202B, 0x202C, 0x202D, 0x202E, // yön gömme/geçersiz kılma
    0x2066, 0x2067, 0x2068, 0x2069, // yön ayırma
  };

  test('lib ve test altındaki Dart dosyalarında görünmez karakter yok', () {
    final offenders = <String>[];
    for (final root in ['lib', 'test']) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.contains('${Platform.pathSeparator}generated')) {
          continue;
        }
        if (entity.readAsStringSync().runes.any(forbidden.contains)) {
          offenders.add(entity.path);
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
