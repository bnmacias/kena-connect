import 'package:flutter_test/flutter_test.dart';

import 'package:kena/main.dart';

void main() {
  testWidgets('Muestra la pantalla de selección de modo Host/Cliente',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KenaApp());

    expect(find.text('Modo Host'), findsOneWidget);
    expect(find.text('Modo Cliente'), findsOneWidget);
  });
}
