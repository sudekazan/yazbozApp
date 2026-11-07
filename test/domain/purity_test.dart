import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Puan motoru ve modeller saf Dart kalmalı: Flutter'a ya da veritabanına
/// bağlanırlarsa tek başına test edilemezler.
void main() {
  test('lib/domain Flutter, dart:ui ya da veri katmanını import etmez', () {
    final forbidden = RegExp(
      r'''^import\s+['"](package:flutter/|dart:ui|package:drift|package:yazboz/(data|features|core)/)''',
      multiLine: true,
    );
    final offenders = <String>[
      for (final file in Directory('lib/domain').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            forbidden.hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty);
  });
}
