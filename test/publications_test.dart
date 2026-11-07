import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackaton_veci_pulso/app/app_router.dart';
import 'package:hackaton_veci_pulso/features/publications/models/publication_draft.dart';
import 'package:hackaton_veci_pulso/features/publications/data/publication_templates.dart';
import 'package:hackaton_veci_pulso/features/solidarity/models/solidarity_post.dart';

void main() {
  test('Plantillas independientes y resumen temporal', () {
    final flow = PublicationDraftController();
    flow.select(PostType.loan);
    expect(flow.draft, isNull);
    for (final entry in publicationTemplates.entries) {
      flow.select(entry.key);
      expect(flow.draft!.type, entry.key);
      expect(flow.draft!.title, entry.value.title);
      flow.draft!.title = '   ';
      expect(flow.confirm(), isFalse);
      flow.draft!.title = '  Texto editado  ';
      flow.select(entry.key);
      expect(flow.draft!.title, '  Texto editado  ');
    }
    expect(flow.confirm(), isTrue);
    expect(flow.confirm(), isFalse);
    expect(flow.draft, isNull);
    expect(flow.preview!.title, 'Texto editado');
    expect(PublicationDraftController().preview, isNull);
    flow.clear();
    expect(flow.preview, isNull);
  });
  testWidgets('Recorrido local a 320 px y texto al 150 %', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(320, 780);
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final router = createRouter();
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    Future<void> tap(String label) async {
      final item = find.text(label);
      if (item.evaluate().isEmpty) {
        await t.scrollUntilVisible(
          item,
          160,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await t.ensureVisible(item);
      await t.pumpAndSettle();
      await t.tap(item);
      await t.pumpAndSettle();
    }

    await tap('Publicar');
    for (final template in publicationTemplates.values) {
      expect(find.text(template.label), findsOneWidget);
    }
    await tap('Donación');
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Donación de ropa abrigadora'), findsOneWidget);
    final fields = find.byType(TextFormField);
    Future<void> enter(int index, String value) async {
      await t.ensureVisible(fields.at(index));
      await t.enterText(fields.at(index), value);
    }

    await enter(0, 'x' * 100);
    expect(find.text('x' * 80), findsOneWidget);
    await enter(1, 'x' * 550);
    expect(find.text('x' * 500), findsOneWidget);
    await enter(0, '   ');
    await tap('Confirmar demostración');
    expect(find.text('Escribe un título para continuar.'), findsOneWidget);
    await enter(0, '  Abrigos para donar  ');
    await enter(1, '');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    router.pop();
    await t.pumpAndSettle();
    await tap('Siguiente');
    expect(find.text('  Abrigos para donar  '), findsOneWidget);
    await tap('Confirmar demostración');
    expect(find.text('Abrigos para donar'), findsOneWidget);
    expect(find.text('No enviada · Demostración'), findsOneWidget);
    expect(find.text(PublicationDraft.neighborhood), findsOneWidget);
    await tap('Ver mi publicación');
    expect(find.text('Vista previa local'), findsOneWidget);
    await tap('Cerrar');
    await tap('Volver al inicio');
    expect(router.state.uri.path, '/inicio');
    for (final path in ['/publicar/exito', '/publicar/detalles']) {
      router.go(path);
      await t.pumpAndSettle();
      expect(router.state.uri.path, '/publicar/tipo');
    }
    expect(t.takeException(), isNull);
  });
}
