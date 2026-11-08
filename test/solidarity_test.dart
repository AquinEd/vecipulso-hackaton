import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fixture.dart';

import 'package:hackaton_veci_pulso/features/solidarity/data/demo_solidarity_posts.dart';
import 'package:hackaton_veci_pulso/features/solidarity/models/solidarity_post.dart';
import 'package:hackaton_veci_pulso/features/solidarity/presentation/screens/solidarity_wall_screen.dart';
import 'package:hackaton_veci_pulso/features/solidarity/presentation/widgets/solidarity_post_card.dart';

void main() {
  test('Los dos modos conservan los registros y sus identificadores', () {
    final wall = visiblePosts(demoSolidarityPosts, WallMode.wall, null);
    final economy = visiblePosts(demoSolidarityPosts, WallMode.economy, null);
    expect(demoSolidarityPosts.map((p) => p.id).toSet(), hasLength(6));
    expect(wall.map((p) => p.type), [
      PostType.offer,
      PostType.need,
      PostType.donation,
    ]);
    expect(economy.map((p) => p.type), [
      PostType.donation,
      PostType.need,
      PostType.exchange,
      PostType.loan,
    ]);
    expect(identical(wall.last, economy.first), isTrue);
  });

  testWidgets(
    'Selección, identidad de cada tarjeta y contadores ilustrativos',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: SolidarityWallScreen())),
      );
      for (final (type, name) in [
        (PostType.offer, 'Carlos Roja'),
        (PostType.need, 'Ana Lópe'),
        (PostType.donation, 'Rosa Herr'),
      ]) {
        await t.tap(find.widgetWithText(ChoiceChip, type.label));
        await t.pumpAndSettle();
        final post = demoSolidarityPosts.firstWhere((p) => p.type == type);
        expect(find.byType(SolidarityPostCard), findsOneWidget);
        for (final label in [
          name,
          post.title,
          post.description,
          '${post.category} · ${post.modality}',
          '✓ Visto Bueno',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
      }
      for (final (count, title) in [
        ('24', 'Favoritos'),
        ('8', 'Comentarios'),
      ]) {
        await t.tap(find.text(count));
        await t.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        await t.tap(find.text('Entendido'));
        await t.pumpAndSettle();
        expect(find.text(count), findsOneWidget);
      }
      await t.tap(find.text('Todos'));
      await t.pumpAndSettle();
      expect(find.text(demoSolidarityPosts.first.title), findsOneWidget);
    },
  );

  testWidgets('Una categoría vacía ofrece volver a Todos', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SolidarityWallScreen(posts: [demoSolidarityPosts.first]),
        ),
      ),
    );
    await t.tap(find.text('Dono'));
    await t.pumpAndSettle();
    expect(find.text('No hay publicaciones de esta categoría'), findsOneWidget);
    await t.tap(find.text('Volver a Todos'));
    await t.pumpAndSettle();
    expect(find.text('Carlos Roja'), findsOneWidget);
  });

  testWidgets('Drawer, pestañas, detalle y regreso conservan el filtro', (
    t,
  ) async {
    final router = signedInRouter();
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    expect(router.state.uri.path, '/inicio');
    await t.tap(find.byTooltip('Abrir menú'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ListTile, 'Cadena de Favores'));
    await t.pumpAndSettle();
    expect(router.state.uri.path, '/favores');
    await t.tap(find.widgetWithText(ChoiceChip, 'Dono'));
    await t.pumpAndSettle();
    await t.tap(find.text('Explorar economía solidaria'));
    await t.pumpAndSettle();
    expect(find.text('Todo sin dinero: juntos nos apoyamos'), findsOneWidget);
    await t.tap(find.text('Contactar').first);
    await t.pumpAndSettle();
    expect(
      find.text(
        'El contacto entre vecinos estará disponible cuando se integre el sistema de mensajería',
      ),
      findsOneWidget,
    );
    await t.tap(find.text('Entendido'));
    await t.pumpAndSettle();
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(
      t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Dono')).selected,
      isTrue,
    );
    await t.tap(find.text('Publicar'));
    await t.pumpAndSettle();
    expect(find.text('¿Qué quieres publicar?'), findsOneWidget);
    await t.tap(find.text('Inicio'));
    await t.pumpAndSettle();
    expect(find.text('¡Hola, vecino!'), findsOneWidget);
    await t.tap(find.byTooltip('Abrir menú'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ListTile, 'Cadena de Favores'));
    await t.pumpAndSettle();
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(router.state.uri.path, '/inicio');
  });

  testWidgets('320 px, texto al 150 %, scroll y rotación', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(320, 720);
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final router = signedInRouter();
    addTearDown(router.dispose);
    router.go('/favores');
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    await t.ensureVisible(find.widgetWithText(ChoiceChip, 'Dono'));
    await t.tap(find.widgetWithText(ChoiceChip, 'Dono'));
    await t.pumpAndSettle();
    await t.tap(find.text('Explorar economía solidaria'));
    await t.pumpAndSettle();
    for (final size in [const Size(320, 720), const Size(720, 320)]) {
      t.view.physicalSize = size;
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Taladro disponible'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(t.takeException(), isNull);
    }
  });
}
