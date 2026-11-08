import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_fixture.dart';

import 'package:hackaton_veci_pulso/app/accessibility_controller.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'Ajustes desde el Drawer SOS y pantallas de emergencia ampliadas',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 800);
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpWidget(signedInApp());
      await t.pumpAndSettle();
      final router = GoRouter.of(t.element(find.byType(AppBar)));
      router.go('/sos/tablero');
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Abrir menú'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Accesibilidad'),
        120,
        scrollable: find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(Scrollable),
        ),
      );
      await t.tap(find.text('Accesibilidad'));
      await t.pumpAndSettle();
      final settings = t
          .element(find.byType(AppBar))
          .read<AccessibilityController>();
      for (final option in AccessibilityPreference.values) {
        settings.update(option, true);
      }
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(router.state.uri.path, '/sos/tablero');
      for (final route in [
        '/sos/acciones',
        '/sos/mapa',
        '/sos/confirmacion',
        '/sos/seguimiento',
      ]) {
        router.go(route);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: route);
      }
      router.go('/configuracion/accesibilidad');
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(router.state.uri.path, '/sos/tablero');
    },
  );
  testWidgets('Cambiar ajustes conserva el comentario y las estrellas', (
    t,
  ) async {
    await t.pumpWidget(signedInApp());
    await t.pumpAndSettle();
    final router = GoRouter.of(t.element(find.byType(AppBar)));
    router.go('/resenas/nueva?providerId=demo-carpinteria');
    await t.pumpAndSettle();
    await t.ensureVisible(find.byTooltip('3 estrellas'));
    await t.tap(find.byTooltip('3 estrellas'));
    final field = find.byType(TextField);
    await t.ensureVisible(field);
    final comment = 'Experiencia vecinal de demostración. ' * 6;
    await t.enterText(field, comment);
    t.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(t.view.resetViewInsets);
    await t.pumpAndSettle();
    router.push<void>('/configuracion/accesibilidad');
    await t.pumpAndSettle();
    for (final label in ['Texto grande', 'Alto contraste']) {
      await t.ensureVisible(find.text(label));
      await t.tap(find.text(label));
      await t.pumpAndSettle();
    }
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(t.widget<TextField>(field).controller!.text, comment);
    expect(find.text('3 de 5 estrellas'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  for (final width in [320.0, 412.0]) {
    for (final scale in [1.5, 2.0]) {
      testWidgets('Preferencias globales a $width px y escala $scale', (
        t,
      ) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 800);
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await t.pumpWidget(signedInApp());
        await t.pumpAndSettle();
        final router = GoRouter.of(t.element(find.byType(AppBar)));
        final original = Theme.of(t.element(find.byType(AppBar))).colorScheme;
        router.push<void>('/configuracion/accesibilidad');
        await t.pumpAndSettle();
        final settings = t
            .element(find.byType(AppBar))
            .read<AccessibilityController>();
        expect(find.byType(SwitchListTile), findsNWidgets(4));
        Future<void> tap(String label) async {
          final target = find.text(label);
          await t.ensureVisible(target);
          await t.pumpAndSettle();
          await t.tap(target);
          await t.pumpAndSettle();
        }

        const labels = [
          'Texto grande',
          'Alto contraste',
          'Botones grandes',
          'Instrucciones claras',
        ];
        for (final (i, label) in labels.indexed) {
          final option = AccessibilityPreference.values[i];
          expect(settings.enabled(option), isFalse);
          final preview = find.ancestor(
            of: find.text('Pedir ayuda'),
            matching: find.byType(FilledButton),
          );
          final previousHeight = t.getSize(preview).height;
          await tap(label);
          expect(settings.enabled(option), isTrue);
          if (option == AccessibilityPreference.largeButtons) {
            expect(t.getSize(preview).height, greaterThan(previousHeight));
          }
          await tap(label);
          expect(settings.enabled(option), isFalse);
          await tap(label);
        }
        await tap('Pedir ayuda');
        expect(
          find.textContaining('No se enviará ninguna solicitud'),
          findsOneWidget,
        );
        expect(router.state.uri.path, '/configuracion/accesibilidad');
        await t.pump(const Duration(seconds: 5));
        router.pop();
        await t.pumpAndSettle();
        final home = t.element(find.byType(AppBar));
        expect(router.state.uri.path, '/inicio');
        expect(
          MediaQuery.textScalerOf(home).scale(10),
          closeTo(10 * scale * 1.2, 0.001),
        );
        expect(Theme.of(home).colorScheme.primary, isNot(original.primary));
        expect(
          Theme.of(home).filledButtonTheme.style!.minimumSize!
              .resolve({})!
              .height,
          56,
        );
        router.push<void>('/tutorial');
        await t.pumpAndSettle();
        expect(find.textContaining('Lee el paso seleccionado'), findsOneWidget);
        router.push<void>('/configuracion/accesibilidad');
        await t.pumpAndSettle();
        await tap('Restablecer ajustes');
        expect(AccessibilityPreference.values.any(settings.enabled), isFalse);
        router.pop();
        await t.pumpAndSettle();
        expect(find.textContaining('Lee el paso seleccionado'), findsNothing);
        settings.update(AccessibilityPreference.largeText, true);
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(signedInApp());
        await t.pumpAndSettle();
        expect(
          t
              .element(find.byType(AppBar))
              .read<AccessibilityController>()
              .largeText,
          isFalse,
        );
        expect(t.takeException(), isNull);
      });
    }
  }
}
