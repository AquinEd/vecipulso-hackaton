import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/controllers/sos_controllers.dart';

import 'support/auth_fixture.dart';

import 'package:hackaton_veci_pulso/features/emergency/data/sos_repository.dart';
import 'package:hackaton_veci_pulso/features/emergency/models/sos_models.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/screens/sos_catalog_screen.dart';

import 'sos_data_test.dart' show repository, id;

class CatalogFake implements SosRepository {
  SosFailure? failure, detailFailure;
  bool empty = false;
  final resource = CriticalResource.fromJson({
    'id': id,
    'zona_id': id,
    'propietario_id': id,
    'tipo': 'agua',
    'cantidad': 2,
    'disponible': false,
    'descripcion': 'Reserva publicada',
    'ubicacion_aprox': 'POINT(-77 -12)',
    'creado_en': '2026-01-01T00:00:00Z',
  });
  var group = SupportGroup.fromJson({
    'id': id,
    'zona_id': id,
    'nombre': 'Grupo público',
    'tipo': 'brigada',
  });
  @override
  Future<List<CriticalResource>> resourcePage({
    int offset = 0,
    ResourceType? type,
  }) async {
    if (failure case final e?) throw e;
    return empty || type != null && type != ResourceType.agua ? [] : [resource];
  }

  @override
  Future<List<SupportGroup>> groupPage({
    int offset = 0,
    GroupType? type,
    String query = '',
  }) async {
    if (failure case final e?) throw e;
    return empty ||
            type == GroupType.voluntarios ||
            !group.nombre.toLowerCase().contains(query.toLowerCase())
        ? []
        : [group];
  }

  @override
  Future<CriticalResource> resourceDetail(String key) async {
    expect(key, id);
    if (detailFailure case final e?) throw e;
    return resource;
  }

  @override
  Future<SupportGroup> groupDetail(String key) async {
    expect(key, id);
    return group;
  }

  @override
  Future<String?> zoneName(String key) async => 'Zona sintética';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SlowCatalog extends CatalogFake {
  final pending = <Completer<List<CriticalResource>>>[];
  @override
  Future<List<CriticalResource>> resourcePage({
    int offset = 0,
    ResourceType? type,
  }) {
    final request = Completer<List<CriticalResource>>();
    pending.add(request);
    return request.future;
  }
}

void main() {
  test(
    'Catálogo descarta respuestas antiguas y no notifica tras dispose',
    () async {
      final repo = SlowCatalog();
      final c = SosCatalogController(repo, false);
      final old = c.refresh();
      c.resourceType = ResourceType.botiquin;
      final latest = c.refresh();
      repo.pending[1].complete([]);
      await latest;
      repo.pending[0].complete([repo.resource]);
      await old;
      expect(c.data!.resources, isEmpty);
      var notifications = 0;
      c.addListener(() => notifications++);
      final pending = c.refresh();
      expect(notifications, 1);
      c.dispose();
      repo.pending[2].complete([repo.resource]);
      await pending;
      expect(notifications, 1);
    },
  );

  testWidgets('Contacto publicado del grupo y regreso por la ruta existente', (
    t,
  ) async {
    final repo = CatalogFake();
    repo.group = SupportGroup.fromJson({
      'id': id,
      'zona_id': id,
      'nombre': 'Grupo público',
      'tipo': 'brigada',
      'contacto': 'Canal comunitario autorizado',
    });
    final router = signedInRouter();
    addTearDown(router.dispose);
    await t.pumpWidget(
      Provider<SosRepository?>.value(
        value: repo,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go('/sos/brigadas');
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ListTile, 'Grupo público'));
    await t.pumpAndSettle();
    expect(find.text('Canal comunitario autorizado'), findsOneWidget);
    await t.tap(find.text('Cerrar'));
    await t.pumpAndSettle();
    await t.tap(find.byType(BackButton).first);
    await t.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/sos/tablero');
    expect(find.textContaining('Contacto no publicado'), findsNothing);
  });

  Future<void> tap(WidgetTester t, String label) async {
    final f = find.text(label).last;
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> mount(
    WidgetTester t,
    CatalogFake repo, {
    bool brigades = false,
  }) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SosCatalogScreen(repository: repo, brigades: brigades),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'Recurso real, detalle por UUID, ubicación aproximada y ausencia de contactos privados',
    (t) async {
      final repo = CatalogFake();
      await mount(t, repo);
      await t.tap(find.widgetWithText(ListTile, 'agua'));
      await t.pumpAndSettle();
      expect(find.text('Reserva publicada'), findsOneWidget);
      expect(find.text('Cantidad registrada: 2'), findsOneWidget);
      expect(find.text('No disponible según el registro'), findsNWidgets(2));
      expect(find.text('Zona sintética'), findsOneWidget);
      expect(find.text('Ubicación aproximada publicada'), findsOneWidget);
      expect(find.textContaining('-77'), findsNothing);
      expect(find.textContaining('propietario_id'), findsNothing);
      await tap(t, 'Cerrar');
      await tap(t, 'botiquin');
      expect(find.text('No hay registros para esta consulta'), findsOneWidget);
      await tap(t, 'Todos');
      expect(find.widgetWithText(ListTile, 'agua'), findsOneWidget);
    },
  );
  testWidgets('Vacío, red, autorización y reintento recuperan los recursos', (
    t,
  ) async {
    final repo = CatalogFake()..empty = true;
    await mount(t, repo);
    expect(find.text('No hay registros para esta consulta'), findsOneWidget);
    for (final error in [SosFailure.network, SosFailure.denied]) {
      repo.failure = error;
      await tap(t, 'Actualizar');
      expect(find.text(error.message), findsOneWidget);
      repo.failure = null;
    }
    repo.empty = false;
    await tap(t, 'Actualizar');
    expect(find.widgetWithText(ListTile, 'agua'), findsOneWidget);
    repo.detailFailure = SosFailure.missing;
    await t.tap(find.widgetWithText(ListTile, 'agua'));
    await t.pumpAndSettle();
    expect(find.text(SosFailure.missing.message), findsOneWidget);
    repo.detailFailure = null;
    await tap(t, 'Reintentar');
    expect(find.text('Reserva publicada'), findsOneWidget);
  });
  testWidgets(
    'Brigada sin adicionales, búsqueda y filtro, sin controles de roles',
    (t) async {
      final repo = CatalogFake();
      await mount(t, repo, brigades: true);
      await tap(t, 'Grupo público');
      expect(find.text('Sin especialidad publicada'), findsOneWidget);
      expect(find.text('Contacto no publicado'), findsOneWidget);
      expect(find.text('Ubicación no publicada'), findsOneWidget);
      expect(find.textContaining('líder'), findsNothing);
      await tap(t, 'Cerrar');
      await tap(t, 'voluntarios');
      expect(find.text('No hay registros para esta consulta'), findsOneWidget);
      await tap(t, 'Todos');
      await t.enterText(find.byType(TextField), 'ausente');
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      expect(find.text('No hay registros para esta consulta'), findsOneWidget);
    },
  );
  test('Consultas de catálogo filtran en el servidor sin leer perfiles o membresías', () async {
    final repo = repository((r) async {
      expect(r.method, 'GET');
      if (r.url.path.endsWith('recursos_criticos')) {
        expect(r.url.queryParameters['tipo'], 'eq.agua');
      } else {
        expect(r.url.path, '/rest/v1/grupos_apoyo');
        expect(r.url.queryParameters['tipo'], 'eq.brigada');
        expect(r.url.queryParameters['nombre'], 'ilike.%Grupo%');
      }
      expect(r.url.queryParameters['offset'], '50');
      expect(r.url.queryParameters['limit'], '50');
      return http.Response(jsonEncode([]), 200);
    });
    expect(
      await repo.resourcePage(offset: 50, type: ResourceType.agua),
      isEmpty,
    );
    expect(
      await repo.groupPage(offset: 50, type: GroupType.brigada, query: 'Grupo'),
      isEmpty,
    );
  });
}
