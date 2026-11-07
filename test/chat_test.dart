import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_mode_navigation_test.dart' show start, tap, tab;

void main() {
  testWidgets('El chat conserva la búsqueda y admite entradas directas', (
    t,
  ) async {
    final (router, _) = await start(t);
    await tab(t, 'Mensajes');
    await t.enterText(find.byType(TextField), 'carpinteria');
    await t.pump();
    await tap(t, find.text('Leo Ve'));
    expect(router.state.uri.path, '/mensajes/carpinteria');
    expect(find.text('Leo Ve'), findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField)).enabled, false);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('carpinteria'), findsOneWidget);
    for (final id in ['ayuda', 'inexistente']) {
      router.go('/mensajes/$id');
      await t.pumpAndSettle();
      expect(
        find.text(
          id == 'ayuda' ? 'Chat de demostración' : 'Conversación no encontrada',
        ),
        findsOneWidget,
      );
      await tap(t, find.byType(BackButton));
      expect(router.state.uri.path, '/mensajes');
    }
  });
}
