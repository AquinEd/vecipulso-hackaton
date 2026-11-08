import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hackaton_veci_pulso/features/maps/data/map_environment.dart';
import 'package:hackaton_veci_pulso/features/maps/data/map_points_repository.dart';
import 'package:hackaton_veci_pulso/features/maps/data/location_service.dart';
import 'package:hackaton_veci_pulso/features/maps/models/map_origin.dart';
import 'package:hackaton_veci_pulso/features/maps/models/map_point.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/controllers/map_filters_controller.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/controllers/map_points_controller.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/controllers/location_controller.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/navigation/map_point_navigation.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/widgets/geographic_map_canvas.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/widgets/map_filters_panel.dart';

import 'map_points_test.dart' show PointsFake, pointRow;
import 'location_test.dart' show LocationPlatformFake;

void main() {
  for (final layer in MapPointLayer.values) {
    test('Filtro real de ${layer.name}', () {
      final filters = MapFiltersController()..only(layer);
      expect(filters.apply(PointsFake().rows).single.layer, layer);
      filters.dispose();
    });
  }
  test('Todos, combinación, ninguno, restauración y búsqueda sin tildes', () {
    final filters = MapFiltersController()..only(MapPointLayer.comercio);
    final points = PointsFake().rows;
    filters.setLayer(MapPointLayer.recurso, true);
    expect(filters.apply(points).length, 2);
    filters.showAll();
    expect(filters.apply(points).length, 4);
    filters.setQuery('inexistente');
    expect(filters.apply(points), isEmpty);
    filters.restore();
    expect(filters.query, isEmpty);
    expect(filters.apply(points).length, 4);
    for (final layer in MapPointLayer.values) {
      filters.setLayer(layer, false);
    }
    expect(filters.apply(points), isEmpty);
    filters.restore();
    final service = MapPoint.fromJson({
      ...pointRow(10),
      'titulo': 'Gasfitería local',
    });
    filters.setQuery('GASFITERIA');
    expect(filters.apply([service]).single, service);
    filters.dispose();
  });
  test('No hay un destino activo ni una capa inventada de favores', () {
    const navigation = MapPointNavigation();
    for (final layer in MapPointLayer.values) {
      expect(navigation.forLayer(layer), isNull);
    }
    expect(MapPointLayer.values.map((x) => x.name), isNot(contains('favor')));
  });

  Future<void> tap(WidgetTester t, Finder finder) async {
    await t.ensureVisible(finder);
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  Future<
    ({
      MapPointsController points,
      MapFiltersController filters,
      GoRouter router,
    })
  >
  mount(
    WidgetTester t,
    PointsFake repo, {
    MapPointNavigation? navigation,
    LocationController? gps,
  }) async {
    final points = MapPointsController(repo);
    final filters = MapFiltersController();
    // Test-only target: this is not a production feature route.
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  MapFiltersPanel(controller: filters, compact: true),
                  GeographicMapCanvas(filters: filters),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/fixture/:id',
          builder: (context, state) => Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: () => context.pop()),
              title: const Text('Detalle de fixture'),
            ),
            body: Text(state.pathParameters['id']!),
          ),
        ),
      ],
    );
    addTearDown(() {
      router.dispose();
      points.dispose();
      filters.dispose();
    });
    await t.pumpWidget(
      Provider<MapEnvironment>.value(
        value: MapEnvironment(
          sessionOrigin: MapOrigin(GeoCoordinate(-12, -77), 'Zona de prueba'),
        ),
        child: ChangeNotifierProvider.value(
          value: points,
          child: ChangeNotifierProvider<LocationController?>.value(
            value: gps,
            child: Provider<MapPointNavigation>.value(
              value: navigation ?? const MapPointNavigation(),
              child: MaterialApp.router(routerConfig: router),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return (points: points, filters: filters, router: router);
  }

  testWidgets(
    'Chips funcionales, filtros rápidos sin RPC y vacío recuperable',
    (t) async {
      final repo = PointsFake();
      final scene = await mount(t, repo);
      expect(repo.calls, 1);
      for (final point in repo.rows) {
        scene.filters.only(point.layer);
        await t.pumpAndSettle();
        for (final other in repo.rows) {
          expect(
            find.byKey(ValueKey('map-point:${other.key}')),
            point.layer == other.layer ? findsOneWidget : findsNothing,
          );
        }
      }
      scene.filters.restore();
      await t.pumpAndSettle();
      await tap(t, find.widgetWithText(FilterChip, 'Servicios'));
      expect(scene.filters.layers, {MapPointLayer.comercio});
      await tap(t, find.widgetWithText(FilterChip, 'Recursos críticos'));
      expect(scene.filters.layers, {
        MapPointLayer.comercio,
        MapPointLayer.recurso,
      });
      await t.enterText(find.byType(TextField), 'ausente');
      await t.pumpAndSettle();
      expect(
        find.text('No hay coincidencias con estos filtros.'),
        findsOneWidget,
      );
      await tap(t, find.text('Restaurar filtros'));
      expect(scene.filters.isDefault, isTrue);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tap(t, find.widgetWithText(FilterChip, 'Servicios'));
      await tap(t, find.widgetWithText(FilterChip, 'Todos'));
      expect(scene.filters.all, isTrue);
      expect(repo.calls, 1);
      expect(find.text('Favores'), findsNothing);
    },
  );
  testWidgets(
    'Destino ausente: ficha pública revalidada, sin enlace ficticio',
    (t) async {
      final repo = PointsFake();
      final scene = await mount(t, repo);
      final point = repo.rows.first;
      await tap(t, find.byKey(ValueKey('map-point:${point.key}')));
      expect(repo.calls, 2);
      expect(find.text(point.title), findsOneWidget);
      expect(find.text('Ubicación comunitaria aproximada'), findsOneWidget);
      expect(
        find.text('El detalle de este módulo no está disponible por ahora.'),
        findsOneWidget,
      );
      expect(find.text('Ver detalles'), findsNothing);
      expect(find.textContaining('telefono'), findsNothing);
      expect(find.textContaining('dni'), findsNothing);
      expect(scene.router.state.uri.path, '/');
      await tap(t, find.text('Cerrar'));
      expect(find.byType(FlutterMap), findsOneWidget);
    },
  );
  testWidgets(
    'Registro eliminado o alerta cerrada no se presentan como activos',
    (t) async {
      final repo = PointsFake();
      await mount(t, repo);
      final alert = repo.rows.singleWhere(
        (p) => p.layer == MapPointLayer.alerta,
      );
      repo.rows = repo.rows.where((p) => p.key != alert.key).toList();
      await tap(t, find.byKey(ValueKey('map-point:${alert.key}')));
      expect(
        find.text('El punto ya no está disponible en esta consulta.'),
        findsOneWidget,
      );
      expect(find.text(alert.title), findsNothing);
      expect(find.text('Ver detalles'), findsNothing);
    },
  );
  testWidgets('Sesión denegada durante selección no conserva ficha ni navega', (
    t,
  ) async {
    final repo = PointsFake();
    var opened = 0;
    await mount(
      t,
      repo,
      navigation: MapPointNavigation(
        service: (_, _) async {
          opened++;
        },
      ),
    );
    repo.failure = MapPointsFailure.denied;
    await tap(t, find.byKey(ValueKey('map-point:${repo.rows.first.key}')));
    expect(find.text(MapPointsFailure.denied.message), findsWidgets);
    expect(find.text(repo.rows.first.title), findsNothing);
    expect(opened, 0);
    expect(find.text('Ver detalles'), findsNothing);
  });
  testWidgets('Red fallida en ficha permite reintento sin éxito simulado', (
    t,
  ) async {
    final repo = PointsFake();
    await mount(t, repo);
    repo.failure = MapPointsFailure.offline;
    await tap(t, find.byKey(ValueKey('map-point:${repo.rows.first.key}')));
    expect(find.text(MapPointsFailure.offline.message), findsWidgets);
    repo.failure = null;
    await tap(t, find.text('Actualizar ficha'));
    expect(find.text(repo.rows.first.title), findsOneWidget);
  });
  testWidgets(
    'Enlace inyectado recibe UUID y regreso conserva cámara, filtros y GPS',
    (t) async {
      final repo = PointsFake();
      final platform = LocationPlatformFake();
      final gps = LocationController(
        GeolocatorLocationService(platform: platform),
      );
      addTearDown(gps.dispose);
      String? received;
      final scene = await mount(
        t,
        repo,
        gps: gps,
        navigation: MapPointNavigation(
          service: (context, point) async {
            received = point.id;
            await GoRouter.of(context).push<void>('/fixture/${point.id}');
          },
        ),
      );
      await tap(t, find.text('Usar mi ubicación'));
      expect(platform.reads, 1);
      await tap(t, find.byTooltip('Acercar mapa'));
      final camera = t
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final zoom = camera.camera.zoom;
      scene.filters.only(MapPointLayer.comercio);
      await t.pumpAndSettle();
      final point = repo.rows.first;
      camera.move(
        LatLng(point.coordinate.latitude, point.coordinate.longitude),
        zoom,
      );
      await t.pumpAndSettle();
      await tap(t, find.byKey(ValueKey('map-point:${point.key}')));
      await tap(t, find.byKey(ValueKey('open-point:${point.key}')));
      expect(received, point.id);
      expect(scene.router.state.uri.path, '/fixture/${point.id}');
      expect(find.text(point.id), findsOneWidget);
      await tap(t, find.byType(BackButton));
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(camera.camera.zoom, zoom);
      expect(scene.filters.layers, {MapPointLayer.comercio});
      expect(gps.location, isNotNull);
      expect(platform.reads, 1);
      expect(find.byKey(const ValueKey('own-position')), findsOneWidget);
    },
  );
  testWidgets(
    'Cambio antes de abrir bloquea registro y callback con error es seguro',
    (t) async {
      final repo = PointsFake();
      var calls = 0;
      await mount(
        t,
        repo,
        navigation: MapPointNavigation(
          service: (_, _) async {
            calls++;
            throw StateError('PRIVATE');
          },
        ),
      );
      final service = repo.rows.first;
      await tap(t, find.byKey(ValueKey('map-point:${service.key}')));
      repo.rows = [];
      await tap(t, find.byKey(ValueKey('open-point:${service.key}')));
      expect(calls, 0);
      expect(
        find.text('El punto ya no está disponible en esta consulta.'),
        findsWidgets,
      );
      await tap(t, find.text('Cerrar'));
      repo.rows = [service];
      await tap(t, find.text('Actualizar puntos'));
      await tap(t, find.byKey(ValueKey('map-point:${service.key}')));
      await tap(t, find.byKey(ValueKey('open-point:${service.key}')));
      expect(calls, 1);
      expect(
        find.text(
          'No se pudo abrir el detalle. El destino no está disponible.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('PRIVATE'), findsNothing);
    },
  );
  testWidgets('El indicador GPS no bloquea un punto público coincidente', (
    t,
  ) async {
    final repo = PointsFake()..rows = [MapPoint.fromJson(pointRow(1))];
    final platform = LocationPlatformFake();
    final gps = LocationController(
      GeolocatorLocationService(platform: platform),
    );
    addTearDown(gps.dispose);
    await mount(t, repo, gps: gps);
    await tap(t, find.text('Usar mi ubicación'));
    await tap(t, find.byKey(ValueKey('map-point:${repo.rows.single.key}')));
    expect(find.text(repo.rows.single.title), findsOneWidget);
    expect(platform.reads, 1);
  });
  testWidgets(
    'Actualizar con filtro no duplica marcadores y mantiene la selección',
    (t) async {
      final repo = PointsFake();
      final scene = await mount(t, repo);
      scene.filters.only(MapPointLayer.recurso);
      await t.pumpAndSettle();
      await tap(t, find.text('Actualizar puntos'));
      expect(repo.calls, 2);
      expect(scene.filters.layers, {MapPointLayer.recurso});
      for (final point in repo.rows) {
        expect(
          find.byKey(ValueKey('map-point:${point.key}')),
          point.layer == MapPointLayer.recurso ? findsOneWidget : findsNothing,
        );
      }
      expect(t.takeException(), isNull);
    },
  );
}
