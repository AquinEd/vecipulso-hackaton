import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/app/app_mode_controller.dart';
import 'package:hackaton_veci_pulso/app/app_router.dart';
import 'package:hackaton_veci_pulso/core/theme/app_theme.dart';
import 'package:hackaton_veci_pulso/features/emergency/data/demo_emergency_actions.dart';
import 'package:hackaton_veci_pulso/features/emergency/data/demo_emergency_reports.dart';
import 'package:hackaton_veci_pulso/features/emergency/models/emergency_action_type.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/widgets/emergency_action_card.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/widgets/emergency_action_selector.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/widgets/emergency_action_summary.dart';

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

Finder select(EmergencyActionType type) => find.descendant(
  of: find.byKey(ValueKey(type)),
  matching: find.text('Seleccionar'),
);

void main() {
  testWidgets(
    'Entrada directa, tres tarjetas, ubicación y parámetro desconocido',
    (t) async {
      final (router, mode) = await start(t, '/sos/acciones?action=desconocida');
      expect(mode.isSos, isTrue);
      for (final label in [
        'VeciPulso SOS',
        'Centro de ayuda vecinal',
        emergencyDemoNotice,
        emergencyDemoLocation,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(EmergencyActionCard), findsNWidgets(3));
      expect(find.byType(EmergencyActionSelector), findsNothing);
      await tap(t, find.byType(BackButton));
      expect(router.state.uri.path, '/sos/tablero');
      expect(mode.isSos, isTrue);
    },
  );

  for (final width in [412.0, 320.0]) {
    for (final action in demoEmergencyActions) {
      testWidgets(
        '${action.type.name}: todas las categorías y resumen a $width px',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = Size(width, 850);
          t.platformDispatcher.textScaleFactorTestValue = 1.5;
          addTearDown(t.view.reset);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          final (router, _) = await start(t, '/sos/acciones');
          final reports = List.of(demoEmergencyReports);
          await tap(t, select(action.type));
          final continueButton = find.widgetWithText(
            FilledButton,
            'Ver resumen de demostración',
          );
          expect(t.widget<FilledButton>(continueButton).onPressed, isNull);
          for (final option in action.options) {
            expect(find.text(option.label), findsOneWidget);
            await tap(t, find.byKey(ValueKey(option.category)));
            final semantics = t.getSemantics(
              find.byKey(ValueKey(option.category)),
            );
            expect(semantics, isNotNull);
            expect(t.widget<FilledButton>(continueButton).onPressed, isNotNull);
            await tap(t, continueButton);
            expect(find.byType(EmergencyActionSummary), findsOneWidget);
            expect(
              find.text('${action.summaryLabel}: ${option.label}'),
              findsOneWidget,
            );
            expect(
              find.text(
                'Estado: ${action.type == EmergencyActionType.offerResources ? 'No registrado' : 'No enviada'}',
              ),
              findsOneWidget,
            );
            expect(find.text(action.notice), findsOneWidget);
            expect(find.text(emergencyDemoLocation), findsNWidgets(2));
            await tap(t, find.text('Cambiar selección'));
            final tile = t.widget<ListTile>(
              find.byKey(ValueKey(option.category)),
            );
            expect((tile.trailing as Icon).icon, Icons.radio_button_checked);
            expect(t.takeException(), isNull);
          }
          await tap(t, continueButton);
          await tap(t, find.text('Cerrar demostración'));
          expect(find.byType(EmergencyActionSelector), findsNothing);
          await tap(t, select(action.type));
          expect(t.widget<FilledButton>(continueButton).onPressed, isNull);
          await tap(t, find.text('Cancelar'));
          expect(demoEmergencyReports, orderedEquals(reports));
          expect(router.state.uri.path, '/sos/acciones');
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  for (final (label, type) in [
    ('Centro de ayuda vecinal', null),
    ('Solicitar ayuda', EmergencyActionType.criticalSupport),
    ('Ofrecer ayuda', EmergencyActionType.offerResources),
  ]) {
    testWidgets('Tablero → $label, Atrás Android y restauración del modo', (
      t,
    ) async {
      final (router, mode) = await start(t, '/mapa');
      await t.enterText(find.byType(TextField), 'ropa');
      router.go('/servicios');
      await t.pumpAndSettle();
      router.go('/favores');
      await t.pumpAndSettle();
      router.go('/sos/tablero');
      await t.pumpAndSettle();
      await tap(t, find.text(label));
      expect(router.state.uri.path, '/sos/acciones');
      expect(mode.isSos, isTrue);
      if (type != null) {
        expect(
          find.text(
            demoEmergencyActions
                .firstWhere((a) => a.type == type)
                .selectorTitle,
          ),
          findsOneWidget,
        );
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
        expect(find.byType(EmergencyActionSelector), findsNothing);
        expect(router.state.uri.path, '/sos/acciones');
      }
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(router.state.uri.path, '/sos/tablero');
      expect(router.canPop(), isFalse);
      for (final (tab, path) in [
        ('Mapa', '/sos/mapa'),
        ('Inicio', '/sos/tablero'),
      ]) {
        await tap(
          t,
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(tab),
          ),
        );
        expect(router.state.uri.path, path);
      }
      await tap(t, find.text('Centro de ayuda vecinal'));
      await tap(t, find.text('Salir del Modo SOS'));
      expect(mode.isSos, isFalse);
      expect(router.state.uri.path, '/inicio');
      expect(find.text('¡Hola, vecino!'), findsOneWidget);
      await tap(
        t,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Mapa'),
        ),
      );
      expect(find.text('Mapa de recursos'), findsOneWidget);
      expect(find.text('ropa'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
    'Pulsaciones repetidas abren un solo panel y cancelar lo descarta',
    (t) async {
      await start(t, '/sos/acciones');
      final button = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Seleccionar').first,
      );
      button.onPressed!();
      button.onPressed!();
      await t.pumpAndSettle();
      expect(find.byType(EmergencyActionSelector), findsOneWidget);
      await tap(t, find.text('Cancelar'));
      expect(find.byType(EmergencyActionSelector), findsNothing);
    },
  );
}
