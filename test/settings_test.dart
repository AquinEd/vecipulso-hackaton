import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_mode_navigation_test.dart' show start, tap, tab;

void main() {
  for (final label in ['Configuración', 'Notificaciones']) {
    for (final android in [true, false]) {
      testWidgets('Drawer abre $label y recupera origen (Android $android)', (
        t,
      ) async {
        final (router, _) = await start(t);
        await tab(t, 'Perfil');
        await tap(t, find.byTooltip('Abrir menú'));
        await tap(
          t,
          find.descendant(of: find.byType(Drawer), matching: find.text(label)),
        );
        expect(find.byType(NavigationBar), findsNothing);
        if (android) {
          await t.binding.handlePopRoute();
          await t.pumpAndSettle();
        } else {
          await tap(t, find.byType(BackButton));
        }
        expect(router.state.uri.path, '/perfil');
        expect(router.canPop(), false);
      });
    }
  }
  testWidgets('Configuración reutiliza destinos existentes', (t) async {
    final (router, _) = await start(t);
    router.go('/configuracion');
    await t.pumpAndSettle();
    for (final (label, path) in [
      ('Accesibilidad', '/configuracion/accesibilidad'),
      ('Tutorial de uso', '/tutorial'),
      ('Estados offline (demo)', '/offline/pendiente'),
      ('Notificaciones', '/notificaciones'),
    ]) {
      await tap(t, find.text(label));
      expect(router.state.uri.path, path);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
    }
    await tap(t, find.text('Cuenta y privacidad'));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tap(t, find.text('Entendido'));
    await tap(t, find.byType(BackButton));
    expect(router.state.uri.path, '/inicio');
  });
}
