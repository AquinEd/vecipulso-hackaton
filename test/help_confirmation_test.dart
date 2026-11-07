import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackaton_veci_pulso/features/emergency/data/demo_emergency_actions.dart';
import 'package:hackaton_veci_pulso/features/emergency/models/emergency_action_type.dart';

import 'emergency_actions_test.dart' show start, tap;

void main() {
  const path = '/sos/confirmacion';
  final support = demoEmergencyActions.firstWhere(
    (a) => a.type == EmergencyActionType.criticalSupport,
  );
  for (final option in support.options) {
    testWidgets('Solicitar ayuda conserva ${option.label}', (t) async {
      final (router, mode) = await start(t, '/sos/tablero');
      await tap(t, find.text('Solicitar ayuda'));
      await tap(t, find.byKey(ValueKey(option.category)));
      await tap(t, find.text('Ver resumen de demostración'));
      await tap(t, find.text('Ver confirmación visual (demo)'));
      expect(find.byType(BottomSheet), findsNothing);
      expect(router.state.uri.path, path);
      expect(
        find.text('Necesidad seleccionada: ${option.label}'),
        findsOneWidget,
      );
      await tap(t, find.text('Ver detalles de la ayuda'));
      final details = t
          .widget<Text>(
            find.textContaining('Demostración — solicitud no enviada'),
          )
          .data!;
      expect(details, contains(option.label));
      expect(details, contains(emergencyDemoLocation));
      expect(details, contains(support.title));
      await tap(t, find.text('Cerrar'));
      expect(find.byType(AlertDialog), findsNothing);
      await tap(t, find.text('Regresar al inicio'));
      expect(router.state.uri.path, '/sos/tablero');
      expect(mode.isSos, isTrue);
    });
  }

  testWidgets('Entrada tras otro módulo, Atrás y salida explícita', (t) async {
    final (router, mode) = await start(t, '/servicios');
    router.go(path);
    await t.pumpAndSettle();
    expect(mode.isSos, isTrue);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(router.state.uri.path, '/sos/tablero');
    router.go(path);
    await t.pumpAndSettle();
    await tap(t, find.byType(BackButton));
    expect(router.state.uri.path, '/sos/tablero');
    expect(mode.isSos, isTrue);
    await tap(t, find.text('Salir del Modo SOS'));
    expect(mode.isSos, isFalse);
    expect(router.state.uri.path, '/inicio');
  });

  for (final width in [320.0, 412.0]) {
    for (final scale in [1.5, 2.0]) {
      testWidgets('Entrada directa y controles a $width px, escala $scale', (
        t,
      ) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 740);
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final (router, mode) = await start(t, path);
        expect(mode.isSos, isTrue);
        expect(find.text('Vista previa de ayuda'), findsOneWidget);
        expect(find.text('DEMOSTRACIÓN'), findsOneWidget);
        expect(find.textContaining('Necesidad de ejemplo:'), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(
          t.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
          hasLength(5),
        );
        for (final label in ['Llamar', 'Chat', 'Ubicar']) {
          await tap(t, find.text(label));
          expect(
            find.text(
              '$label todavía no está disponible en esta demostración.',
            ),
            findsOneWidget,
          );
          await tap(t, find.text('Cerrar'));
          expect(router.state.uri.path, path);
        }
        await tap(t, find.text('Ver detalles de la ayuda'));
        await tap(t, find.text('Cerrar'));
        expect(t.takeException(), isNull);
      });
    }
  }
}
