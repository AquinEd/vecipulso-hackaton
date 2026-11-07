import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hackaton_veci_pulso/app/accessibility_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/app/app_mode_controller.dart';
import 'package:hackaton_veci_pulso/app/app_router.dart';
import 'package:hackaton_veci_pulso/core/theme/app_theme.dart';

Future<void> tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

Future<void> drawer(WidgetTester t, String label) async {
  await tap(t, find.byTooltip('Abrir menú'));
  await tap(t, find.widgetWithText(ListTile, label));
  expect(
    t.state<ScaffoldState>(find.byType(Scaffold).first).isDrawerOpen,
    isFalse,
  );
}

Future<void> tab(WidgetTester t, String label) => tap(
  t,
  find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
);

Future<(GoRouter, AppModeController)> start(WidgetTester t) async {
  final mode = AppModeController();
  final router = createRouter(modeController: mode);
  addTearDown(() {
    router.dispose();
    mode.dispose();
  });
  await t.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AccessibilityController(),
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await t.pumpAndSettle();
  return (router, mode);
}

void main() {
  for (final sections in [
    ['Servicios del Barrio'],
    ['Servicios del Barrio', 'Cadena de Favores'],
    ['Servicios del Barrio', 'Modo SOS'],
    ['Servicios del Barrio', 'Servicios del Barrio', 'Servicios del Barrio'],
  ]) {
    for (final systemBack in [false, true]) {
      testWidgets(
        'Drawer $sections: ${systemBack ? 'Android' : 'botón'} vuelve directamente al Dashboard',
        (t) async {
          final (router, mode) = await start(t);
          for (final section in sections) {
            await drawer(t, section);
          }
          expect(router.canPop(), isFalse);
          expect(find.byType(NavigationBar), findsOneWidget);
          if (systemBack) {
            await t.binding.handlePopRoute();
            await t.pumpAndSettle();
          } else {
            await tap(t, find.byType(BackButton));
          }
          expect(router.state.uri.path, '/inicio');
          expect(mode.mode, AppMode.normal);
          expect(find.text('¡Hola, vecino!'), findsOneWidget);
          expect(router.canPop(), isFalse);
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'SOS cambia contenido y rutas, conserva el modo y restaura el mapa normal',
    (t) async {
      final (router, mode) = await start(t);
      await tab(t, 'Mapa');
      await t.enterText(find.byType(TextField), 'ropa');
      await t.pumpAndSettle();
      await drawer(t, 'Modo SOS');
      expect(mode.mode, AppMode.sos);
      expect(router.state.uri.path, '/sos/tablero');
      expect(find.text('Modo Emergencia'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tab(t, 'Mapa');
        expect(router.state.uri.path, '/sos/mapa');
        expect(find.text('Mapa de Emergencia'), findsOneWidget);
        expect(find.text('Modo Emergencia'), findsNothing);
        expect(find.text('Mapa de recursos'), findsNothing);
        expect(
          t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          1,
        );
        expect(router.canPop(), isFalse);
        await tab(t, 'Inicio');
        expect(router.state.uri.path, '/sos/tablero');
        expect(find.text('Modo Emergencia'), findsOneWidget);
        expect(find.text('Mapa de Emergencia'), findsNothing);
        expect(mode.mode, AppMode.sos);
      }
      for (final (label, content) in [
        ('Publicar', '¿Qué quieres publicar?'),
        ('Mensajes', 'Conversaciones de demostración'),
        ('Perfil', 'Mi perfil'),
      ]) {
        await tab(t, label);
        expect(find.text(content), findsOneWidget);
        expect(find.text('Modo Emergencia'), findsNothing);
        expect(mode.isSos, isTrue);
        expect(find.byType(NavigationBar), findsOneWidget);
      }
      await tab(t, 'Inicio');
      await tap(t, find.text('Ver mapa de reportes'));
      expect(router.state.uri.path, '/sos/mapa');
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(router.state.uri.path, '/sos/tablero');
      expect(mode.isSos, isTrue);
      await tab(t, 'Mapa');
      await tap(t, find.text('Salir del Modo SOS'));
      expect(router.state.uri.path, '/inicio');
      expect(mode.isSos, isFalse);
      expect(find.text('¡Hola, vecino!'), findsOneWidget);
      await tab(t, 'Mapa');
      expect(router.state.uri.path, '/mapa');
      expect(find.text('Mapa de recursos'), findsOneWidget);
      expect(find.text('ropa'), findsOneWidget);
      await tab(t, 'Inicio');
      expect(find.text('¡Hola, vecino!'), findsOneWidget);
      expect(mode.isSos, isFalse);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Entrada directa al mapa SOS, regreso al tablero y salida explícita',
    (t) async {
      final (router, mode) = await start(t);
      router.go('/sos/mapa');
      await t.pumpAndSettle();
      expect(mode.isSos, isTrue);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tap(t, find.text('Volver al Tablero SOS'));
      expect(router.state.uri.path, '/sos/tablero');
      await tap(t, find.text('Salir del Modo SOS'));
      expect(mode.mode, AppMode.normal);
      expect(router.state.uri.path, '/inicio');
    },
  );

  testWidgets('Perfil secundario conserva origen y Atrás Android lo recupera', (
    t,
  ) async {
    final (router, _) = await start(t);
    await drawer(t, 'Servicios del Barrio');
    await t.enterText(find.byType(TextField), 'carpinteria');
    await t.pumpAndSettle();
    await tap(t, find.text('Carpintería Vecinal'));
    expect(find.text('Perfil del proveedor'), findsOneWidget);
    expect(router.canPop(), isTrue);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Servicios de Proximidad'), findsOneWidget);
    expect(find.text('carpinteria'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(router.state.uri.path, '/inicio');
    expect(t.takeException(), isNull);
  });
}
