import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/main.dart';

void main() {
  testWidgets('Uygulama açılır', (tester) async {
    await tester.pumpWidget(const MainApp());
    expect(find.byType(MainApp), findsOneWidget);
  });
}
