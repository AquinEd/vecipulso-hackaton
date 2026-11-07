import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/app/app_mode_controller.dart';
import 'package:hackaton_veci_pulso/app/app_router.dart';
import 'package:hackaton_veci_pulso/core/theme/app_theme.dart';
import 'package:hackaton_veci_pulso/features/emergency/data/demo_brigades.dart';
import 'package:hackaton_veci_pulso/features/emergency/models/community_brigade.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/screens/brigades_screen.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/widgets/brigade_card.dart';

Future<void> tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

Future<(GoRouter, AppModeController)> start(WidgetTester t, String path) async {
  final mode = AppModeController();
  final router = createRouter(modeController: mode);
  addTearDown(() {
    router.dispose();
    mode.dispose();
  });
  await t.pumpWidget(
    MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
  await t.pumpAndSettle();
  expect(router.state.uri.path, '/inicio');
  router.go(path);
  await t.pumpAndSettle();
  return (router, mode);
}

Finder chip(String label) => find.widgetWithText(ChoiceChip, label);
Finder tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  test('Catálogo estable, sectores, integrantes y búsqueda normalizada', () {
    expect(demoBrigades.map((g) => g.id).toSet(), hasLength(4));
    expect(demoBrigades.map((g) => g.memberCount), [12, 8, 6, 11]);
    expect(demoBrigades.map((g) => g.sectorLabel), [
      'Cuadras 1–5',
      'Cuadras 6–10',
      'Cuadras 11–15',
      'Cuadras 16–20',
    ]);
    for (final (query, id) in [
      ('ALAMOS', 'demo-alamos'),
      ('cuadra 6', 'demo-progreso'),
      ('sector 10', 'demo-progreso'),
      ('salud', 'demo-salud'),
      ('cuadra 1', 'demo-alamos'),
      ('cuadras 20', 'demo-movilidad'),
    ]) {
      expect(demoBrigades.where((g) => g.matches(query)).map((g) => g.id), [
        id,
      ]);
    }
    expect(demoBrigades.where((g) => g.matches('voluntarios')), hasLength(2));
    expect(
      demoBrigades.where((g) => g.type == BrigadeType.brigade),
      hasLength(2),
    );
  });

  testWidgets('Cuatro tarjetas, datos y aviso de demostración', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(900, 1800);
    addTearDown(t.view.reset);
    await start(t, '/sos/brigadas');
    expect(find.text('Grupos de Apoyo y Brigadas'), findsOneWidget);
    expect(
      find.text('Grupos de demostración · Contactos no disponibles'),
      findsOneWidget,
    );
    expect(find.byType(BrigadeCard), findsNWidgets(4));
    for (final group in demoBrigades) {
      expect(find.text(group.name), findsOneWidget);
      expect(
        find.text('${group.sectorLabel} · ${group.memberCount} integrantes'),
        findsOneWidget,
      );
    }
    expect(find.text('Contacto directo'), findsNWidgets(4));
    expect(t.widget<ChoiceChip>(chip('Todos')).selected, isTrue);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Búsqueda en vivo, filtros combinados y restablecimiento', (
    t,
  ) async {
    await start(t, '/sos/brigadas');
    for (final (query, name) in [
      ('alamos', 'Brigada Los Álamos'),
      ('cuadra 6', 'Grupo El Progreso'),
      ('SALUD', 'Equipo Salud Vecinal'),
    ]) {
      await t.enterText(find.byType(TextField), query);
      await t.pumpAndSettle();
      expect(find.byType(BrigadeCard), findsOneWidget);
      expect(find.text(name), findsOneWidget);
    }
    await tap(t, chip('Voluntarios'));
    expect(find.byType(BrigadeCard), findsNothing);
    expect(
      find.text('No encontramos grupos para esta búsqueda'),
      findsOneWidget,
    );
    await tap(t, find.text('Limpiar búsqueda y filtros'));
    expect(t.widget<ChoiceChip>(chip('Todos')).selected, isTrue);
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    for (final (label, type) in [
      ('Brigadas', BrigadeType.brigade),
      ('Voluntarios', BrigadeType.volunteers),
    ]) {
      await tap(t, chip(label));
      final screen = t.state(find.byType(BrigadesScreen));
      expect(screen.mounted, isTrue);
      for (final card in t.widgetList<BrigadeCard>(find.byType(BrigadeCard))) {
        expect(card.brigade.type, type);
      }
      expect(find.byType(BrigadeCard), findsNWidgets(2));
    }
    await t.enterText(find.byType(TextField), 'ninguno');
    await t.pumpAndSettle();
    expect(
      find.text('No encontramos grupos para esta búsqueda'),
      findsOneWidget,
    );
    await tap(t, find.byTooltip('Borrar búsqueda'));
    expect(find.byType(BrigadeCard), findsNWidgets(2));
    expect(t.widget<ChoiceChip>(chip('Voluntarios')).selected, isTrue);
  });

  testWidgets(
    'Contacto informa del grupo seleccionado y se cierra sin acciones',
    (t) async {
      await start(t, '/sos/brigadas');
      for (final group in demoBrigades) {
        await t.enterText(find.byType(TextField), group.name);
        await t.pumpAndSettle();
        await tap(t, find.text('Contacto directo'));
        expect(find.text('Contacto no disponible todavía'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(group.name),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Podrás comunicarte con este grupo cuando se implemente el sistema de mensajería y contactos verificados',
          ),
          findsOneWidget,
        );
        await tap(t, find.text('Entendido'));
        expect(find.byType(AlertDialog), findsNothing);
      }
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Tablero abre Brigadas, Atrás Android conserva SOS sin acumular secciones',
    (t) async {
      final (router, mode) = await start(t, '/servicios');
      router.go('/favores');
      await t.pumpAndSettle();
      router.go('/sos/tablero');
      await t.pumpAndSettle();
      await tap(t, find.text('Grupos y Brigadas'));
      expect(router.state.uri.path, '/sos/brigadas');
      expect(mode.isSos, isTrue);
      expect(find.byType(NavigationBar), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(router.state.uri.path, '/sos/tablero');
      expect(router.canPop(), isFalse);
      await tap(t, find.text('Grupos y Brigadas'));
      await tap(t, find.byType(BackButton));
      expect(router.state.uri.path, '/sos/tablero');
      for (final (label, path) in [
        ('Mapa', '/sos/mapa'),
        ('Inicio', '/sos/tablero'),
      ]) {
        await tap(t, tab(label));
        expect(router.state.uri.path, path);
        expect(mode.isSos, isTrue);
      }
      await tap(t, find.text('Salir del Modo SOS'));
      expect(router.state.uri.path, '/inicio');
      expect(mode.isSos, isFalse);
      await tap(t, tab('Mapa'));
      expect(find.text('Mapa de recursos'), findsOneWidget);
    },
  );

  testWidgets('Entrada directa tiene salida al tablero y pestañas SOS únicas', (
    t,
  ) async {
    final (router, mode) = await start(t, '/sos/brigadas');
    expect(mode.isSos, isTrue);
    await tap(t, find.byType(BackButton));
    expect(router.state.uri.path, '/sos/tablero');
    router.go('/sos/brigadas');
    await t.pumpAndSettle();
    await tap(t, tab('Inicio'));
    expect(router.state.uri.path, '/sos/tablero');
    router.go('/sos/brigadas');
    await t.pumpAndSettle();
    await tap(t, tab('Mapa'));
    expect(router.state.uri.path, '/sos/mapa');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final width in [320.0, 412.0]) {
    testWidgets('Texto 150 %, teclado, contacto y lista larga a $width px', (
      t,
    ) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = Size(width, 850);
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await start(t, '/sos/brigadas');
      await t.enterText(find.byType(TextField), 'movilidad');
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Contacto directo'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tap(t, find.text('Contacto directo'));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tap(t, find.text('Entendido'));
      expect(t.takeException(), isNull);
      t.view.viewInsets = const FakeViewPadding();
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SafeArea(
              child: BrigadesScreen(
                groups: [
                  for (var i = 0; i < 50; i++)
                    CommunityBrigade(
                      id: 'long-$i',
                      name: 'Grupo comunitario de demostración número $i',
                      startBlock: 1,
                      endBlock: 5,
                      memberCount: 12,
                      type: BrigadeType.brigade,
                      icon: BrigadeIcon.community,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('long-49')),
        500,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 200,
      );
      expect(find.byKey(const ValueKey('long-49')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
