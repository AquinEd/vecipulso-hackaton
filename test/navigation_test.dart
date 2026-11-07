import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackaton_veci_pulso/app/app.dart';

void main() {
  testWidgets('Inicio presenta cinco pestañas y el acceso SOS', (tester) async {
    await tester.pumpWidget(const VeciPulsoApp());
    await tester.pumpAndSettle();
    expect(find.text('Ubicación por configurar'), findsOneWidget);
    for (final title in ['Inicio', 'Mapa', 'Publicar', 'Mensajes', 'Perfil']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(title),
        ),
        findsOneWidget,
      );
    }
    await tester.scrollUntilVisible(
      find.text('Modo SOS'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Modo SOS')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modo SOS'));
    await tester.pumpAndSettle();
    expect(find.text('Modo Emergencia'), findsOneWidget);
  });
  testWidgets('El menú abre SOS y permite volver a Inicio', (tester) async {
    await tester.pumpWidget(const VeciPulsoApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
    final sos = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Modo SOS'),
    );
    await tester.ensureVisible(sos);
    await tester.tap(sos);
    await tester.pumpAndSettle();
    expect(find.text('Modo Emergencia'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('¡Hola, vecino!'), findsOneWidget);
  });
  testWidgets('Cambiar de pestaña mantiene una sola barra', (tester) async {
    await tester.pumpWidget(const VeciPulsoApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mensajes'));
    await tester.pumpAndSettle();
    expect(find.text('Conversaciones de demostración'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('¡Hola, vecino!'), findsOneWidget);
  });
}
