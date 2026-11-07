import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackaton_veci_pulso/features/emergency/models/emergency_action_option.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/widgets/help_route_preview.dart';

import 'emergency_actions_test.dart' show start, tap;

void main() {
  const path = '/sos/seguimiento';
  for (final android in [false, true]) {
    testWidgets('Regreso según origen (Android: $android)', (t) async {
      final (router, mode) = await start(t, path);
      Future<void> back() async {
        if (android) {
          await t.binding.handlePopRoute();
          await t.pumpAndSettle();
        } else {
          await tap(t, find.byType(BackButton));
        }
      }

      expect(mode.isSos, isTrue);
      await back();
      expect(router.state.uri.path, '/sos/tablero');
      for (final category in [null, EmergencyActionCategory.medicalHelp]) {
        router.go('/sos/confirmacion', extra: category);
        await t.pumpAndSettle();
        final need = find.text(
          category == null
              ? 'Necesidad de ejemplo: Persona atrapada'
              : 'Necesidad seleccionada: Ayuda médica',
        );
        await tap(t, find.text('Ver simulación de seguimiento'));
        expect(router.state.uri.path, path);
        expect(need, findsOneWidget);
        await back();
        expect(router.state.uri.path, '/sos/confirmacion');
        expect(need, findsOneWidget);
        expect(mode.isSos, isTrue);
      }
      await tap(t, find.text('Ver simulación de seguimiento'));
      await tap(t, find.text('Salir del Modo SOS'));
      expect(router.state.uri.path, '/inicio');
      expect(mode.isSos, isFalse);
      expect(
        t.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
        hasLength(5),
      );
      expect(router.canPop(), isFalse);
    });
  }
  for (final width in [320.0, 412.0]) {
    for (final scale in [1.5, 2.0]) {
      testWidgets('Mapa y controles locales a $width px y escala $scale', (
        t,
      ) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 740);
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final (router, mode) = await start(t, path);
        expect(mode.isSos, isTrue);
        for (final label in [
          'Coordinación de ayuda · Demo',
          'Demostración: ninguna solicitud fue enviada ni aceptada.',
          'Vecina que necesitaría ayuda · Perfil ficticio',
          'Necesidad de ejemplo: Persona atrapada',
          'Ruta ilustrativa. No representa ubicación en tiempo real ni garantiza condiciones seguras de tránsito.',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.byType(HelpRoutePreview), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        for (final label in ['Origen de ejemplo', 'Destino de ejemplo']) {
          await tap(t, find.byTooltip(label));
          expect(find.text(label), findsOneWidget);
          await tap(t, find.text('Cerrar'));
        }
        await tap(t, find.text('Llamar'));
        expect(
          find.textContaining('Las llamadas estarán disponibles'),
          findsOneWidget,
        );
        await tap(t, find.text('Cerrar'));
        await tap(t, find.text('Chat'));
        expect(find.text('Conversación de demostración'), findsOneWidget);
        expect(
          find.text(
            'Estos mensajes son ejemplos. No se enviará ningún mensaje.',
          ),
          findsOneWidget,
        );
        expect(find.text('¿Dónde podríamos encontrarnos?'), findsOneWidget);
        expect(find.byType(EditableText), findsNothing);
        await tap(t, find.text('Cerrar'));
        expect(find.byType(BottomSheet), findsNothing);
        expect(router.state.uri.path, path);
        expect(t.takeException(), isNull);
      });
    }
  }
}
