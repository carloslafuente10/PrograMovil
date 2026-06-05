
import 'package:flutter/material.dart';// Librería principal de Flutter para la construcción de interfaces.
import 'package:flutter_test/flutter_test.dart';// Proporciona herramientas para realizar pruebas automatizadas en Flutter.

import 'package:programovil/main.dart';// Importa la aplicación principal que será evaluada durante las pruebas.
// Punto de entrada para la ejecución de pruebas automatizadas.
void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
