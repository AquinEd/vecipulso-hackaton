import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_fixture.dart';

import 'package:hackaton_veci_pulso/features/maps/data/demo_map_markers.dart';
import 'package:hackaton_veci_pulso/features/maps/models/community_map_marker.dart';
import 'package:hackaton_veci_pulso/features/maps/models/map_point.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/widgets/map_filters_panel.dart';

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
      await t.pumpWidget(signedInApp());
      await t.pumpAndSettle();
      await tap(t, find.text('Mapa'));
      expect(
        t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(
        find.text('Cartografía real · puntos públicos sujetos a permisos'),
        findsOneWidget,
      );
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      for (final c in MapPointLayer.values) {
        expect(find.text(mapFilterLabel(c)), findsOneWidget);
      }
      final field = find.byType(TextField);
      await t.enterText(field, 'inexistente');
      t.view.viewInsets = const FakeViewPadding(bottom: 240);
      await t.pumpAndSettle();
      expect(find.text('inexistente'), findsOneWidget);
      await t.enterText(field, 'COMERCIOS');
      await t.pumpAndSettle();
      expect(find.byType(FlutterMap), findsOneWidget);
      t.view.resetViewInsets();
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      final shops = find.text('Servicios');
      await tap(t, shops);
      expect(
        t
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Servicios'),
            )
            .value,
        isFalse,
      );
      await tap(t, shops);
      expect(find.byType(FlutterMap), findsOneWidget);
      await tap(t, find.byTooltip('Borrar búsqueda'));
      await tap(t, shops);
      await tap(t, find.text('Restaurar filtros'));
      expect(
        t
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Servicios'),
            )
            .value,
        isTrue,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Regreso del detalle existente conserva búsqueda y cámara del mapa',
    (t) async {
      await t.pumpWidget(signedInApp());
      await t.pumpAndSettle();
      await tap(t, find.text('Mapa'));
      await t.enterText(find.byType(TextField), 'GASFITERIA');
      await t.pumpAndSettle();
      final camera = t
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      await tap(t, find.byTooltip('Acercar mapa'));
      final zoom = camera.camera.zoom;
      final router = GoRouter.of(t.element(find.text('Mapa de recursos')));
      router.push('/servicios/demo-gasfiteria');
      await t.pumpAndSettle();
      expect(find.text('Perfil del proveedor'), findsOneWidget);

      await tap(t, find.byType(BackButton));
      expect(find.text('Mapa de recursos'), findsOneWidget);
      expect(find.text('GASFITERIA'), findsOneWidget);
      expect(
        t
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!
            .camera
            .zoom,
        zoom,
      );
    },
  );
}
