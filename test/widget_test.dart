import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/app.dart';

void main() {
  testWidgets('Uygulama Türkçe başlıkla açılır', (tester) async {
    await tester.pumpWidget(const YazbozApp());
    await tester.pumpAndSettle();

    expect(find.text('Yazboz'), findsOneWidget);
    final context = tester.element(find.byType(Scaffold));
    expect(Localizations.localeOf(context).languageCode, 'tr');
  });
}
