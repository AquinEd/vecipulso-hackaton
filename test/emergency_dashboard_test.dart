import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fixture.dart';

import 'package:hackaton_veci_pulso/core/theme/app_colors.dart';
import 'package:hackaton_veci_pulso/core/theme/app_theme.dart';
import 'package:hackaton_veci_pulso/features/emergency/data/demo_emergency_reports.dart';
import 'package:hackaton_veci_pulso/features/emergency/models/emergency_report.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/widgets/emergency_report_card.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/widgets/emergency_report_details.dart';

Future<void> tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

void main() {
  test('Catálogo inmutable, ficticio e independiente con IDs únicos', () {
    expect(demoEmergencyReports.map((r) => r.id).toSet(), hasLength(5));
    expect(demoEmergencyReports.every((r) => r.isDemo), isTrue);
    expect(
      demoEmergencyReports.take(3).map((r) => r.priority),
      EmergencyPriority.values,
    );
    expect(() => demoEmergencyReports.clear(), throwsUnsupportedError);
  });

  for (final path in ['/sos/tablero', '/sos']) {
    testWidgets('Entrada directa $path y salida al Dashboard', (t) async {
      final router = signedInRouter();
      addTearDown(router.dispose);
      await t.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await t.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/inicio');
      router.go(path);
      await t.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/sos/tablero');
      expect(find.text('Modo Emergencia'), findsOneWidget);
      expect(find.text('Zona de riesgo activa'), findsNothing);
      expect(
        find.text('MODO DEMOSTRACIÓN — No hay alertas reales verificadas'),
        findsOneWidget,
      );
      expect(
        find.text('Reportes de ejemplo · Distancias simuladas'),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        t.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        AppColors.sos,
      );
      for (final r in demoEmergencyReports.take(3)) {
        expect(find.text(r.title), findsOneWidget);
        expect(
          find.text('${r.priority.label} · ${r.distanceLabel}'),
          findsOneWidget,
        );
      }
      await tap(t, find.byType(BackButton));
      expect(find.text('¡Hola, vecino!'), findsOneWidget);
    });
  }

  testWidgets(
    'Cada tarjeta abre su propio detalle de solo lectura y se cierra',
    (t) async {
      final router = signedInRouter();
      addTearDown(router.dispose);
      await t.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      router.go('/sos/tablero');
      await t.pumpAndSettle();
      for (final r in demoEmergencyReports.take(3)) {
        await tap(t, find.byKey(ValueKey(r.id)));
        final sheet = find.byType(EmergencyReportDetails);
        for (final label in [
          r.title,
          r.description,
          'Reporte de demostración',
          'Categoría: ${r.category.label}',
          'Prioridad / estado: ${r.priority.label}',
          'Distancia: ${r.distanceLabel} (simulada)',
        ]) {
          expect(
            find.descendant(of: sheet, matching: find.text(label)),
            findsOneWidget,
          );
        }
        await tap(t, find.text('Cerrar'));
        expect(sheet, findsNothing);
      }
    },
  );

  testWidgets(
    '320 px y texto 150 %: avisos, mapa futuro, ampliar, detalles y contraer',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 780);
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final router = signedInRouter();
      addTearDown(router.dispose);
      await t.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      router.go('/sos/tablero');
      await t.pumpAndSettle();
      for (final (button, title) in [
        ('Solicitar ayuda', 'Tipo de necesidad'),
        ('Ofrecer ayuda', 'Tipo de recurso'),
      ]) {
        await tap(t, find.text(button));
        expect(find.text(title), findsOneWidget);
        await tap(t, find.text('Cancelar'));
        await tap(t, find.byType(BackButton));
        expect(find.byType(EmergencyReportCard), findsNWidgets(3));
      }
      await tap(t, find.text('Ver mapa de reportes'));
      expect(find.text('Mapa de Emergencia'), findsOneWidget);
      expect(
        find.text(
          'Cartografía real — Puntos autorizados de la comunidad. No indica zonas de peligro oficiales.',
        ),
        findsOneWidget,
      );
      await tap(t, find.byType(BackButton));
      await tap(t, find.text('Ver todos los reportes'));
      expect(find.byType(EmergencyReportCard), findsNWidgets(5));
      await tap(t, find.byKey(ValueKey(demoEmergencyReports.last.id)));
      expect(find.text(demoEmergencyReports.last.description), findsOneWidget);
      await tap(t, find.text('Cerrar'));
      await tap(t, find.text('Contraer reportes'));
      expect(find.byType(EmergencyReportCard), findsNWidgets(3));
      expect(demoEmergencyReports, hasLength(5));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'SOS vuelve al Dashboard y conserva el filtro de Mapa y las cinco pestañas',
    (t) async {
      final router = signedInRouter();
      addTearDown(router.dispose);
      await t.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await t.pumpAndSettle();
      router.go('/mapa');
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'ropa');
      await tap(t, find.byTooltip('Abrir menú'));
      await tap(
        t,
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Modo SOS'),
        ),
      );
      expect(find.text('Modo Emergencia'), findsOneWidget);
      await tap(t, find.byType(BackButton));
      expect(find.text('¡Hola, vecino!'), findsOneWidget);
      await tap(t, find.text('Mapa'));
      expect(find.text('ropa'), findsOneWidget);
      router.go('/sos/tablero');
      await t.pumpAndSettle();
      for (final label in [
        'Mapa',
        'Publicar',
        'Mensajes',
        'Perfil',
        'Inicio',
      ]) {
        await tap(
          t,
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(
          t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          ['Inicio', 'Mapa', 'Publicar', 'Mensajes', 'Perfil'].indexOf(label),
        );
      }
      expect(t.takeException(), isNull);
    },
  );
}
