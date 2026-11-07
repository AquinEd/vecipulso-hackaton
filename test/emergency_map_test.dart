import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackaton_veci_pulso/features/emergency/data/demo_emergency_map_markers.dart';
import 'package:hackaton_veci_pulso/features/emergency/models/emergency_map_marker.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/screens/emergency_map_screen.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/widgets/emergency_map_canvas.dart';
import 'package:hackaton_veci_pulso/shared/widgets/common/illustrated_streets_painter.dart';

import 'app_mode_navigation_test.dart' show drawer, start, tab, tap;

void main() {
  testWidgets('Los filtros del mapa comunitario y SOS son independientes', (
    t,
  ) async {
    final (router, mode) = await start(t);
    await tab(t, 'Mapa');
    final shops = find.widgetWithText(CheckboxListTile, 'Comercios locales');
    await tap(t, shops);
    await drawer(t, 'Modo SOS');
    await tap(t, find.text('Ver mapa de reportes'));
    await tap(t, find.widgetWithText(FilterChip, 'Brigadas'));
    expect(find.byType(EmergencyMapCanvas), findsOneWidget);
    expect(
      t
          .widget<EmergencyMapCanvas>(find.byType(EmergencyMapCanvas))
          .markers
          .every((m) => m.category == EmergencyMapCategory.brigade),
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
        expect(find.text('Zona de riesgo ilustrativa'), findsOneWidget);
        expect(find.byKey(const ValueKey('risk-oval')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(EmergencyMapCanvas),
            matching: find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is IllustratedStreetsPainter,
            ),
          ),
          findsOneWidget,
        );
        for (final category in EmergencyMapCategory.values) {
          expect(find.text(category.label), findsWidgets);
          final chip = find.widgetWithText(FilterChip, category.filter);
          await tap(t, chip);
          for (final marker in demoEmergencyMapMarkers) {
            expect(
              find.byKey(ValueKey(marker.id)),
              marker.category == category ? findsOneWidget : findsNothing,
            );
          }
          final marker = demoEmergencyMapMarkers.firstWhere(
            (m) => m.category == category,
          );
          await tap(t, find.byKey(ValueKey(marker.id)));
          final sheet = find.byType(BottomSheet);
          expect(
            find.descendant(of: sheet, matching: find.text(marker.title)),
            findsOneWidget,
          );
          if (marker.report case final report?) {
            expect(find.text(report.description), findsOneWidget);
            expect(
              find.text('Distancia: ${report.distanceLabel} (simulada)'),
              findsOneWidget,
            );
          } else if (marker.brigade case final brigade?) {
            expect(
              find.text('Sector de ejemplo: ${brigade.sectorLabel}'),
              findsOneWidget,
            );
          } else {
            expect(
              find.text('Disponibilidad ficticia para la demostración'),
              findsOneWidget,
            );
          }
          expect(
            find.descendant(
              of: sheet,
              matching: find.byWidgetPredicate(
                (w) => w is ButtonStyleButton || w is IconButton,
              ),
            ),
            findsOneWidget,
          );
          await tap(t, find.text('Cerrar'));
          expect(sheet, findsNothing);
          await tap(t, chip);
          expect(
            find.text('Selecciona una categoría o Todos para ver marcadores.'),
            findsOneWidget,
          );
          await tap(t, find.widgetWithText(FilterChip, 'Todos'));
          for (final marker in demoEmergencyMapMarkers) {
            expect(find.byKey(ValueKey(marker.id)), findsOneWidget);
          }
        }
        expect(t.takeException(), isNull);
      });
    }
  }
}
