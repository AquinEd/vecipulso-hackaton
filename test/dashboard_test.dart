import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackaton_veci_pulso/app/app.dart';

void main() {
  testWidgets(
    'El Dashboard presenta la marca, el banner y ambas categorías navegables',
    (tester) async {
      await tester.pumpWidget(const VeciPulsoApp());
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('VeciPulso'), findsOneWidget);
      expect(find.text('¡Juntos hacemos un mejor barrio!'), findsOneWidget);
      for (final title in ['Servicios del Barrio', 'Cadena de Favores']) {
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(find.text('Funcionalidad en preparación.'), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Mapa'));
      await tester.pumpAndSettle();
      expect(find.text('Funcionalidad en preparación.'), findsOneWidget);
    },
  );
  testWidgets(
    'El buscador filtra, conserva la consulta al volver del detalle y permite borrarla',
    (tester) async {
      await tester.pumpWidget(const VeciPulsoApp());
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      await tester.enterText(field, 'muebles');
      await tester.pumpAndSettle();
      expect(find.text('Gasfitería del Barrio'), findsNothing);
      final card = find.text('Carpintería Vecinal');
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('Perfil de proveedor'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'muebles');
      await tester.scrollUntilVisible(
        field,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(field, 'xyz');
      await tester.pumpAndSettle();
      expect(
        find.text('No se encontraron servicios para esta búsqueda.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Borrar búsqueda'));
      await tester.pumpAndSettle();
      expect(find.text('Gasfitería del Barrio'), findsOneWidget);
    },
  );
  testWidgets(
    'Pantalla estrecha con teclado y texto ampliado permite recorrer resultados',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const VeciPulsoApp());
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      await tester.scrollUntilVisible(
        field,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(field, 'matematicas');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      final result = find.text('Clases de Matemáticas');
      await tester.scrollUntilVisible(
        result,
        110,
        scrollable: find.byType(Scrollable).first,
      );
      expect(result, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
