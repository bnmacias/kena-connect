import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kena/main.dart';

void main() {
  testWidgets('Arranca en Inicio con las dos acciones principales', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'kena.seenOnboarding': true});

    await tester.pumpWidget(const KenaApp());
    await tester.pumpAndSettle();

    expect(find.text('Kena Connect'), findsOneWidget);
    expect(find.text('Crear una sala'), findsOneWidget);
    expect(find.text('Unirme a una sala'), findsOneWidget);
  });
}
