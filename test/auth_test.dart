import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackaton_veci_pulso/app/app.dart';
import 'package:hackaton_veci_pulso/features/auth/utils/auth_validators.dart';
import 'package:hackaton_veci_pulso/features/auth/presentation/widgets/pin_keypad.dart';
import 'package:hackaton_veci_pulso/features/auth/presentation/widgets/pin_dots_indicator.dart';

Future<void> tapLabel(WidgetTester tester, String text) async {
  final item = find.text(text);
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}

Future<void> openDemo(WidgetTester tester, String label) async {
  await tester.pumpWidget(const VeciPulsoApp());
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Pruebas de desarrollo'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tapLabel(tester, 'Pruebas de desarrollo');
  await tester.drag(find.byType(ListView).first, const Offset(0, -300));
  await tester.pumpAndSettle();
  await tapLabel(tester, label);
}

Future<void> digits(WidgetTester tester, String value) async {
  for (final digit in value.split('')) {
    final key = find.descendant(
      of: find.byType(PinKeypad),
      matching: find.text(digit),
    );
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pump();
  }
}

void main() {
  test('DNI de ocho dígitos y normalización del nombre', () {
    expect(AuthValidators.dni('01234567'), isNull);
    for (final value in ['123', '1234567a', '123456789']) {
      expect(AuthValidators.dni(value), isNotNull);
    }
    for (final value in ['', '  ']) {
      expect(AuthValidators.name(value), isNotNull);
    }
    expect(AuthValidators.name('María Peña'), isNull);
    expect(AuthValidators.normalizeName(' María   Peña '), 'María Peña');
  });
  testWidgets('Registro permite corregir datos, volver y confirmar el PIN', (
    tester,
  ) async {
    await openDemo(tester, 'Probar registro');
    await tapLabel(tester, 'Continuar');
    expect(find.text('Ingresa tu nombre completo.'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'a123456789');
    await tester.enterText(fields.last, '  María   Peña ');
    await tapLabel(tester, 'Continuar');
    expect(find.text('Crea tu PIN'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('María Peña'), findsOneWidget);
    expect(find.text('12345678'), findsOneWidget);
    await tapLabel(tester, 'Continuar');
    await digits(tester, '1234567');
    expect(
      tester.widget<PinDotsIndicator>(find.byType(PinDotsIndicator)).count,
      6,
    );
    expect(find.textContaining('123456'), findsNothing);
    final erase = find.byTooltip('Borrar último dígito');
    await tester.ensureVisible(erase);
    await tester.tap(erase);
    await tester.pump();
    expect(
      tester.widget<PinDotsIndicator>(find.byType(PinDotsIndicator)).count,
      5,
    );
    await digits(tester, '6');
    await tapLabel(tester, 'Continuar');
    await digits(tester, '000000');
    await tapLabel(tester, 'Confirmar PIN');
    expect(find.textContaining('Los PIN no coinciden'), findsOneWidget);
    await digits(tester, '123456');
    await tapLabel(tester, 'Confirmar PIN');
    expect(find.text('Registro de demostración completado'), findsOneWidget);
    await tapLabel(tester, 'Ir al inicio');
    expect(find.byType(NavigationBar), findsOneWidget);
  });
  testWidgets(
    'Login mantiene el teclado por apertura y solo informa al continuar',
    (tester) async {
      await openDemo(tester, 'Probar inicio con PIN');
      List<String> order() => tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(PinKeypad),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data!)
          .toList();
      final initial = order();
      expect(initial.toSet(), {for (var i = 0; i < 10; i++) '$i'});
      expect(initial.length, 10);
      expect(find.text('Continuar'), findsNothing);
      await digits(tester, '123456');
      expect(order(), initial);
      await tapLabel(tester, 'Continuar');
      expect(find.textContaining('requiere el servidor'), findsOneWidget);
      await tapLabel(tester, 'Entendido');
      await tapLabel(tester, '¿Olvidaste tu PIN?');
      expect(find.textContaining('La recuperación'), findsOneWidget);
      await tapLabel(tester, 'Entendido');
      expect(find.text('Iniciar sesión'), findsOneWidget);
      await tapLabel(tester, 'Volver al inicio de demostración');
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );
}
