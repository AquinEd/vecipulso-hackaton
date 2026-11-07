import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_mode_navigation_test.dart' show start, tap, tab;

void main() {
  testWidgets('Los avisos leídos se conservan al volver desde Perfil', (
    t,
  ) async {
    final (router, _) = await start(t);
    await tab(t, 'Perfil');
    await tap(t, find.text('Notificaciones'));
    expect(find.text('Notificaciones de ejemplo'), findsOneWidget);
    await tap(t, find.text('No leídas'));
    await tap(t, find.text('Taller comunitario'));
    expect(find.text('No leídas: 4'), findsOneWidget);
    await tap(t, find.text('Marcar todas como leídas'));
    expect(find.text('Sin notificaciones no leídas'), findsOneWidget);
    await tap(t, find.text('Todas'));
    expect(find.text('Taller comunitario'), findsOneWidget);
    await tap(t, find.byType(BackButton));
    expect(router.state.uri.path, '/perfil');
    await tap(t, find.text('Notificaciones'));
    expect(find.text('No leídas: 0'), findsOneWidget);
  });
}
