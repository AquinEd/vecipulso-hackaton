import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hackaton_veci_pulso/features/maps/data/map_environment.dart';
import 'package:hackaton_veci_pulso/features/maps/data/location_service.dart';
import 'package:hackaton_veci_pulso/features/maps/models/map_origin.dart';
import 'package:hackaton_veci_pulso/features/maps/models/map_point.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/controllers/location_controller.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/controllers/map_filters_controller.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/controllers/map_points_controller.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/widgets/geographic_map_canvas.dart';

import 'geographic_map_test.dart' show decodeTile, LocalTiles;
import 'location_test.dart' show LocationPlatformFake;
import 'map_points_test.dart' show PointsFake, pointRow;

void main() {
  testWidgets('500 puntos: agrupación, filtros rápidos y consulta única', (
    t,
  ) async {
    final repo = PointsFake()
      ..rows = [
        for (var i = 0; i < 500; i++)
          MapPoint.fromJson(
            pointRow(i, layer: MapPointLayer.values[i % 4].name),
          ),
      ];
    final points = MapPointsController(repo);
    final filters = MapFiltersController();
    addTearDown(points.dispose);
    addTearDown(filters.dispose);
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: points,
        child: Provider<MapEnvironment>.value(
          value: MapEnvironment(
            sessionOrigin: MapOrigin(GeoCoordinate(-12, -77), 'Zona sintética'),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GeographicMapCanvas(filters: filters),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.byTooltip('500 puntos en esta ubicación aproximada'),
      findsOneWidget,
    );
    for (var i = 0; i < 100; i++) {
      filters.only(MapPointLayer.values[i % 4]);
    }
    await t.pumpAndSettle();
    expect(
      find.byTooltip('125 puntos en esta ubicación aproximada'),
      findsOneWidget,
    );
    expect(points.result!.points.length, 500);
    expect(repo.calls, 1);
    filters.restore();
    await t.pumpAndSettle();
    expect(
      find.byTooltip('500 puntos en esta ubicación aproximada'),
      findsOneWidget,
    );
    expect(repo.calls, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    '500 posiciones distintas mantienen identidad y filtran sin otra consulta',
    (t) async {
      final repo = PointsFake()
        ..rows = [
          for (var i = 0; i < 500; i++)
            MapPoint.fromJson(
              pointRow(
                i,
                layer: MapPointLayer.values[i % 4].name,
                lat: -12 + i * .000001,
                lng: -77 + i * .000001,
              ),
            ),
        ];
      final points = MapPointsController(repo);
      final filters = MapFiltersController();
      addTearDown(points.dispose);
      addTearDown(filters.dispose);
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: points,
          child: Provider<MapEnvironment>.value(
            value: MapEnvironment(
              sessionOrigin: MapOrigin(
                GeoCoordinate(-12, -77),
                'Zona sintética',
              ),
            ),
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: GeographicMapCanvas(filters: filters),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      List<Marker> markers() =>
          t.widget<MarkerLayer>(find.byType(MarkerLayer)).markers;
      expect(markers().length, 500);
      expect(markers().map((m) => m.child.key).toSet().length, 500);
      filters.only(MapPointLayer.alerta);
      await t.pumpAndSettle();
      expect(markers().length, 125);
      expect(repo.calls, 1);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Restaurar Android revalida una vez y conserva cámara sin GPS automático',
    (t) async {
      final image = (await t.runAsync(decodeTile))!;
      addTearDown(image.dispose);
      final repo = PointsFake();
      final points = MapPointsController(repo);
      final platform = LocationPlatformFake();
      final gps = LocationController(
        GeolocatorLocationService(platform: platform),
      );
      final filters = MapFiltersController()..only(MapPointLayer.recurso);
      addTearDown(points.dispose);
      addTearDown(gps.dispose);
      addTearDown(filters.dispose);
      var surfaces = 0;
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: gps,
          child: ChangeNotifierProvider.value(
            value: points,
            child: Provider<MapEnvironment>.value(
              value: MapEnvironment(
                sessionOrigin: MapOrigin(
                  GeoCoordinate(-12, -77),
                  'Zona sintética',
                ),
                createTiles: () {
                  surfaces++;
                  return LocalTiles(Future.value(image));
                },
              ),
              child: MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: GeographicMapCanvas(filters: filters),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final camera = t
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      camera.move(camera.camera.center, 15);
      await t.pumpAndSettle();
      final center = camera.camera.center;
      expect(surfaces, 1);
      expect(repo.calls, 1);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pumpAndSettle();
      expect(find.byType(TileLayer), findsOneWidget);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pumpAndSettle();
      // Android pausa el dibujo; no se afirma cancelación de HTTP en vuelo.
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(repo.calls, 1);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(find.byType(TileLayer), findsOneWidget);
      expect(surfaces, 1);
      expect(repo.calls, 2);
      expect(camera.camera.zoom, 15);
      expect(camera.camera.center, center);
      expect(filters.layers, {MapPointLayer.recurso});
      expect(platform.reads, 0);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(repo.calls, 2);
      await t.pumpWidget(const SizedBox());
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
}
