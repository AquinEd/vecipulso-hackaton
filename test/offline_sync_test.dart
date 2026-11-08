import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'support/auth_fixture.dart';

import 'package:hackaton_veci_pulso/app/accessibility_controller.dart';
import 'package:hackaton_veci_pulso/features/offline/presentation/controllers/offline_demo_controller.dart';
import 'package:hackaton_veci_pulso/features/solidarity/data/demo_solidarity_posts.dart';
import 'package:hackaton_veci_pulso/features/emergency/data/demo_emergency_reports.dart';

void main() {
  testWidgets('La simulación funciona sin archivos, HTTP ni canales nativos', (
    t,
  ) async {
    final messenger = t.binding.defaultBinaryMessenger;
    final previous = messenger.allMessagesHandler;
    messenger.allMessagesHandler = (channel, _, _) =>
        fail('Canal nativo inesperado: $channel');
    try {
      IOOverrides.runZoned(
        () {
          HttpOverrides.runZoned(() {
            final demo = OfflineDemoController();
            demo.createExample();
            demo.recoverConnection();
            demo.fail();
            demo.retry();
            expect(demo.succeed(), isTrue);
            demo.reset();
            demo.dispose();
          }, createHttpClient: (_) => fail('Cliente HTTP inesperado'));
        },
        createFile: (path) => fail('Archivo inesperado: $path'),
        createDirectory: (path) => fail('Directorio inesperado: $path'),
      );
    } finally {
      messenger.allMessagesHandler = previous;
    }
  });

  test('Solo se admiten transiciones explícitas válidas', () {
    final demo = OfflineDemoController();
    addTearDown(demo.dispose);
    var changes = 0;
    demo.addListener(() => changes++);
    demo.recoverConnection();
    demo.retry();
    demo.fail();
    expect(demo.succeed(), false);
    demo.reset();
    expect(changes, 0);
    expect(demo.status, OfflineDemoStatus.offline);
    demo.createExample();
    expect(demo.status, OfflineDemoStatus.pending);
    demo.recoverConnection();
    expect(demo.status, OfflineDemoStatus.sending);
    demo.fail();
    expect(demo.status, OfflineDemoStatus.error);
    demo.retry();
    expect(demo.status, OfflineDemoStatus.sending);
    expect(demo.succeed(), true);
    expect(demo.status, OfflineDemoStatus.synchronized);
    demo.reset();
    expect(demo.status, OfflineDemoStatus.offline);
    expect(changes, 6);
  });

  testWidgets('Drawer SOS, error, reintento, resultado y regreso', (t) async {
    final posts = [...demoSolidarityPosts];
    final reports = [...demoEmergencyReports];
    await t.pumpWidget(signedInApp());
    await t.pumpAndSettle();
    final router = GoRouter.of(t.element(find.byType(AppBar)));
    router.go('/sos/tablero');
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Abrir menú'));
    await t.pumpAndSettle();
    final entry = find.text('Estados offline (demo)');
    await t.scrollUntilVisible(
      entry,
      120,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    await t.tap(entry);
    await t.pumpAndSettle();
    for (final text in [
      'Modo sin conexión',
      'Sin conexión · Demo',
      'Funciones previstas sin conexión',
      'Solicitud pendiente · Demo',
      'Ejemplo ficticio: Necesito agua potable',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.textContaining('no se guardó'), findsOneWidget);
    Future<void> tap(String label) async {
      final target = find.text(label);
      await t.ensureVisible(target);
      await t.tap(target);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    }

    await tap('Consultar contactos útiles');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tap('Cerrar');
    await tap('Crear ejemplo pendiente');
    expect(
      find.text('Esta solicitud de ejemplo todavía no fue enviada.'),
      findsOneWidget,
    );
    await tap('Simular conexión recuperada');
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tap('Simular error');
    expect(find.text('Se produjo un error en la simulación.'), findsOneWidget);
    await tap('Simular reintento');
    await tap('Simular éxito');
    await t.pumpAndSettle();
    expect(router.state.uri.path, '/offline/sincronizado');
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('¡Simulación completada!'), findsOneWidget);
    expect(find.text('Estado: Sincronizado (simulado)'), findsOneWidget);
    expect(find.textContaining('Vista previa'), findsNothing);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await tap('Restablecer demostración');
    expect(find.text('Sin conexión · Demo'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(router.state.uri.path, '/sos/tablero');
    expect(
      t.widget<NavigationBar>(find.byType(NavigationBar)).destinations.length,
      5,
    );
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(router.state.uri.path, '/inicio');
    expect(demoSolidarityPosts, posts);
    expect(demoEmergencyReports, reports);
  });

  for (final width in [320.0, 412.0]) {
    for (final scale in [1.5, 2.0]) {
      testWidgets('Entradas directas accesibles a $width px y escala $scale', (
        t,
      ) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 800);
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await t.pumpWidget(signedInApp());
        await t.pumpAndSettle();
        final context = t.element(find.byType(AppBar));
        final router = GoRouter.of(context);
        for (final option in AccessibilityPreference.values) {
          context.read<AccessibilityController>().update(option, true);
        }
        for (final route in ['/offline/pendiente', '/offline/sincronizado']) {
          router.go(route);
          await t.pumpAndSettle();
          expect(find.byType(AppBar), findsOneWidget);
          expect(t.takeException(), isNull);
          if (route.endsWith('pendiente')) {
            expect(find.textContaining('Crea el ejemplo'), findsOneWidget);
          } else {
            expect(find.textContaining('Vista previa'), findsOneWidget);
            expect(find.textContaining('no se enviaron datos'), findsOneWidget);
            expect(find.textContaining('Usa Atrás'), findsOneWidget);
          }
          await t.binding.handlePopRoute();
          await t.pumpAndSettle();
          expect(router.state.uri.path, '/inicio');
        }
        router.go('/offline/sincronizado');
        await t.pumpAndSettle();
        final board = find.text('Ir al tablero de ayuda');
        await t.ensureVisible(board);
        await t.tap(board);
        await t.pumpAndSettle();
        expect(router.state.uri.path, '/sos/tablero');
        expect(t.takeException(), isNull);
      });
    }
  }
}
