import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fixture.dart';

import 'package:hackaton_veci_pulso/core/theme/app_theme.dart';
import 'package:hackaton_veci_pulso/features/services/data/demo_services.dart';

void main() {
  const path = '/resenas/nueva';
  const open = 'Previsualizar Visto Bueno';
  const notice =
      'Esta es una vista previa. No se publicó ninguna reseña y la valoración del proveedor no cambió.';
  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  for (final provider in [carpentry, plumbing]) {
    testWidgets('Previsualizar desde ${provider.id} y recuperar los filtros', (
      t,
    ) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(412, 1100);
      addTearDown(t.view.reset);
      final router = signedInRouter();
      addTearDown(router.dispose);
      await t.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      router.go('/inicio');
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), provider.serviceName);
      await t.pumpAndSettle();
      await tap(t, find.text(provider.providerDisplayName));
      final link = find.text('Calificar experiencia (demo)');
      await t.scrollUntilVisible(
        link,
        170,
        scrollable: find.byType(Scrollable).first,
      );
      await tap(t, link);
      expect(router.state.uri.queryParameters['providerId'], provider.id);
      expect(find.text(provider.providerDisplayName), findsOneWidget);
      expect(
        find.textContaining(provider.providerPaternalSurname),
        findsNothing,
      );
      expect(find.text(provider.serviceName), findsOneWidget);
      expect(find.text('Opiniones entre vecinos'), findsOneWidget);
      expect(
        find.text(
          'Demostración: las valoraciones no se publican ni se verifican.',
        ),
        findsOneWidget,
      );
      expect(find.text('Deja una reseña opcional'), findsOneWidget);
      expect(find.text('Sin calificación'), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
      await tap(t, find.text(open));
      expect(find.text('Selecciona entre 1 y 5 estrellas.'), findsOneWidget);
      for (final n in [1, 3, 5, 1]) {
        await tap(t, find.byTooltip(n == 1 ? '1 estrella' : '$n estrellas'));
        expect(find.byIcon(Icons.star), findsNWidgets(n));
        expect(find.byIcon(Icons.star_border), findsNWidgets(5 - n));
        expect(find.text('$n de 5 estrellas'), findsOneWidget);
      }
      for (final note in ['', '   ', '  ¡Llegó a tiempo!\nBuen diseño.  ']) {
        if (note.trim().isNotEmpty) await tap(t, find.byTooltip('5 estrellas'));
        await t.enterText(find.byType(TextField), note);
        await tap(t, find.text(open));
        final dialog = find.byType(AlertDialog);
        Finder inside(String label) =>
            find.descendant(of: dialog, matching: find.text(label));
        expect(inside(notice), findsOneWidget);
        expect(inside(provider.providerDisplayName), findsOneWidget);
        expect(inside(provider.serviceName), findsOneWidget);
        expect(
          inside(note.trim().isEmpty ? '1 de 5 estrellas' : '5 de 5 estrellas'),
          findsOneWidget,
        );
        if (note.trim().isNotEmpty) expect(inside(note.trim()), findsOneWidget);
        if (note.trim().isEmpty) expect(inside(note), findsNothing);
        await tap(
          t,
          inside(note.isEmpty ? 'Cerrar vista previa' : 'Seguir editando'),
        );
        expect(
          t.widget<TextField>(find.byType(TextField)).controller!.text,
          note,
        );
      }
      if (provider == carpentry) {
        await t.binding.handlePopRoute();
      } else {
        await tap(t, find.byType(BackButton));
      }
      await t.pumpAndSettle();
      expect(router.state.uri.path, '/servicios/${provider.id}');
      expect(find.textContaining('Buen diseño.'), findsNothing);
      expect(provider.rating, provider == carpentry ? 4.7 : 4.8);
      expect(provider.reviewCount, provider == carpentry ? 98 : null);
      expect(provider.reviews.length, provider == carpentry ? 2 : 0);
      expect(provider.hasNeighborhoodApproval, isTrue);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text(provider.serviceName), findsWidgets);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        provider.serviceName,
      );
    });
  }

  testWidgets('Entradas directas sin proveedor válido', (t) async {
    final router = signedInRouter();
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    for (final invalid in [false, true]) {
      router.go(invalid ? '$path?providerId=desconocido' : path);
      await t.pumpAndSettle();
      expect(
        find.text(
          invalid
              ? 'Proveedor no encontrado.'
              : 'Selecciona un proveedor para calificar.',
        ),
        findsOneWidget,
      );
      expect(find.text(open), findsNothing);
      await tap(
        t,
        invalid ? find.byType(BackButton) : find.text('Volver al directorio'),
      );
      expect(router.state.uri.path, '/servicios');
    }
  });

  for (final width in [320.0, 412.0]) {
    for (final scale in [1.5, 2.0]) {
      testWidgets('Comentario y teclado a $width px y escala $scale', (
        t,
      ) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 740);
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final router = signedInRouter()
          ..go('$path?providerId=demo-carpinteria');
        addTearDown(router.dispose);
        await t.pumpWidget(
          MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        );
        await t.pumpAndSettle();
        await tap(t, find.byTooltip('3 estrellas'));
        final field = find.byType(TextField);
        await t.ensureVisible(field);
        await t.enterText(field, 'ñ' * 301);
        t.view.viewInsets = const FakeViewPadding(bottom: 260);
        await t.pumpAndSettle();
        expect(t.widget<TextField>(field).controller!.text, 'ñ' * 300);
        expect(find.text('300/300'), findsOneWidget);
        t.view.resetViewInsets();
        await tap(t, find.text(open));
        expect(find.byType(AlertDialog), findsOneWidget);
        await tap(t, find.text('Cerrar vista previa'));
        expect(t.takeException(), isNull);
      });
    }
  }
}
