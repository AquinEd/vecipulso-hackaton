import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackaton_veci_pulso/app/app.dart';
import 'package:hackaton_veci_pulso/features/maps/data/demo_map_markers.dart';
import 'package:hackaton_veci_pulso/features/maps/models/community_map_marker.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/widgets/neighborhood_map_canvas.dart';

void main() {
  test(
    'Catálogo ilustrativo con posiciones válidas y categorías completas',
    () {
      expect(
        demoMapMarkers.map((m) => m.id).toSet(),
        hasLength(demoMapMarkers.length),
      );
      expect(
        demoMapMarkers.map((m) => m.category).toSet(),
        MapCategory.values.toSet(),
      );
      for (final m in demoMapMarkers) {
        expect(m.relativeX, inInclusiveRange(0, 1));
        expect(m.relativeY, inInclusiveRange(0, 1));
        expect(m.matches(m.description), isTrue);
      }
    },
  );

  Future<void> tap(WidgetTester t, Finder finder) async {
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  testWidgets(
    'La leyenda combina categorías y búsqueda con teclado y texto ampliado',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 720);
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpWidget(const VeciPulsoApp());
      await t.pumpAndSettle();
      await tap(t, find.text('Mapa'));
      expect(
        t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(
        find.text('Mapa ilustrativo · Ubicaciones de ejemplo'),
        findsOneWidget,
      );
      int count() => t
          .widget<NeighborhoodMapCanvas>(find.byType(NeighborhoodMapCanvas))
          .markers
          .length;
      expect(count(), demoMapMarkers.length);
      for (final c in MapCategory.values) {
        expect(find.text(c.label), findsOneWidget);
      }
      final field = find.byType(TextField);
      await t.enterText(field, 'inexistente');
      t.view.viewInsets = const FakeViewPadding(bottom: 240);
      await t.pumpAndSettle();
      expect(find.textContaining('No hay coincidencias'), findsOneWidget);
      await t.enterText(field, 'COMERCIOS');
      await t.pumpAndSettle();
      expect(count(), 2);
      t.view.resetViewInsets();
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      final shops = find.text('Comercios locales');
      await tap(t, shops);
      expect(count(), 0);
      await tap(t, shops);
      expect(count(), 2);
      await tap(t, find.byTooltip('Borrar búsqueda'));
      await tap(t, shops);
      await tap(t, find.text('Restablecer categorías'));
      expect(count(), demoMapMarkers.length);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('Detalle de comercio y regreso desde su perfil', (t) async {
    await t.pumpWidget(const VeciPulsoApp());
    await t.pumpAndSettle();
    await tap(t, find.text('Mapa'));
    await t.enterText(find.byType(TextField), 'GASFITERIA');
    await t.pumpAndSettle();
    final marker = demoMapMarkers.firstWhere(
      (m) => m.serviceId == 'demo-gasfiteria',
    );
    final pin = find.byTooltip('${marker.title} · ${marker.category.label}');
    await tap(t, pin);
    expect(find.text(marker.title), findsOneWidget);
    expect(find.text(marker.description), findsOneWidget);
    expect(find.text('Dato de demostración'), findsOneWidget);
    await tap(t, find.text('Cerrar'));
    expect(find.text('Dato de demostración'), findsNothing);
    await tap(t, pin);
    await tap(t, find.text('Ver proveedor'));
    expect(find.text('Perfil del proveedor'), findsOneWidget);
    expect(find.text('Servicio: ${marker.title}'), findsOneWidget);
    await tap(t, find.byType(BackButton));
    expect(find.text('Mapa de recursos'), findsOneWidget);
    expect(find.text('GASFITERIA'), findsOneWidget);
    expect(pin, findsOneWidget);
  });
}
