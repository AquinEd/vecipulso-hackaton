import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackaton_veci_pulso/features/maps/models/map_point.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/widgets/map_filters_panel.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/screens/emergency_map_screen.dart';
import 'package:hackaton_veci_pulso/shared/widgets/common/illustrated_streets_painter.dart';

import 'app_mode_navigation_test.dart' show drawer, start, tab, tap;

void main() {
  testWidgets('Los filtros del mapa comunitario y SOS son independientes', (
    t,
  ) async {
    final (router, mode) = await start(t);
    await tab(t, 'Mapa');
    final shops = find.widgetWithText(CheckboxListTile, 'Servicios');
    await tap(t, shops);
    await drawer(t, 'Modo SOS');
    await tap(t, find.text('Ver mapa de reportes'));
    await tap(t, find.widgetWithText(FilterChip, 'Grupos de apoyo'));
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(
      t
          .widget<FilterChip>(
            find.widgetWithText(FilterChip, 'Grupos de apoyo'),
          )
          .selected,
      isTrue,
    );
    await tap(t, find.text('Salir del Modo SOS'));
    expect(router.state.uri.path, '/inicio');
    expect(mode.isSos, isFalse);
    await tab(t, 'Mapa');
    expect(router.state.uri.path, '/mapa');
    expect(t.widget<CheckboxListTile>(shops).value, isFalse);
  });
  for (final width in [320.0, 412.0]) {
    for (final scale in [1.5, 2.0]) {
      testWidgets('Mapa SOS a $width px con texto ×$scale', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 850);
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final (router, mode) = await start(t);
        router.go('/sos/mapa');
        await t.pumpAndSettle();
        expect(mode.isSos, isTrue);
        expect(find.byType(NavigationDestination), findsNWidgets(5));
        expect(find.text(emergencyMapNotice), findsOneWidget);
        expect(find.text('Reportes y recursos'), findsOneWidget);
        expect(find.text('Zona de riesgo ilustrativa'), findsNothing);
        expect(find.byKey(const ValueKey('risk-oval')), findsNothing);
        expect(find.byType(FlutterMap), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is IllustratedStreetsPainter,
          ),
          findsNothing,
        );
        for (final category in MapPointLayer.values) {
          expect(find.text(mapFilterLabel(category)), findsWidgets);
          final chip = find.widgetWithText(
            FilterChip,
            mapFilterLabel(category),
          );
          await tap(t, chip);
          expect(t.widget<FilterChip>(chip).selected, isTrue);
          expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
          await tap(t, chip);
          expect(t.widget<FilterChip>(chip).selected, isFalse);
          await tap(t, find.widgetWithText(FilterChip, 'Todos'));
          expect(
            t
                .widget<FilterChip>(find.widgetWithText(FilterChip, 'Todos'))
                .selected,
            isTrue,
          );
        }
        expect(t.takeException(), isNull);
      });
    }
  }
}
