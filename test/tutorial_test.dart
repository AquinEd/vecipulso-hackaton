import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/app/app.dart';

void main() {
  for (final direct in [false, true]) {
    for (final sos in [false, true]) {
      testWidgets('Recorrer tutorial y volver (directa $direct, SOS $sos)', (
        t,
      ) async {
        await t.pumpWidget(const VeciPulsoApp());
        await t.pumpAndSettle();
        final router = GoRouter.of(t.element(find.byType(NavigationBar)));
        final origin = sos ? '/sos/tablero' : '/servicios';
        router.go(origin);
        await t.pumpAndSettle();
        if (direct) {
          router.go('/tutorial');
        } else {
          router.push<void>('/tutorial');
        }
        await t.pumpAndSettle();
        Future<void> tap(String label) async {
          final target = find.text(label);
          await t.ensureVisible(target);
          await t.tap(target);
          await t.pumpAndSettle();
        }

        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.text('Tutorial de uso'), findsOneWidget);
        expect(
          find.textContaining('proveedores son datos de demostración'),
          findsOneWidget,
        );
        final titles = [
          '1. Encuentra cerca',
          '2. Comparte y recibe',
          '3. Actúa en emergencias',
        ];
        expect(
          t.getTopLeft(find.text(titles.first)).dy,
          lessThan(t.getTopLeft(find.text(titles[1])).dy),
        );
        expect(
          t.getTopLeft(find.text(titles[1])).dy,
          lessThan(t.getTopLeft(find.text(titles.last)).dy),
        );
        await tap('Siguiente');
        expect(find.textContaining('demostraciones locales'), findsOneWidget);
        await tap('Anterior');
        expect(find.text('Paso 1 de 3'), findsOneWidget);
        await tap(titles.last);
        expect(
          find.textContaining('No sustituyen a los servicios oficiales'),
          findsOneWidget,
        );
        await tap('Entendido, comenzar');
        expect(router.state.uri.path, direct && !sos ? '/inicio' : origin);
      });
    }
  }
}
