import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hackaton_veci_pulso/features/maps/data/map_environment.dart';
import 'package:hackaton_veci_pulso/features/maps/data/map_origin_repository.dart';
import 'package:hackaton_veci_pulso/features/maps/models/map_origin.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/widgets/geographic_map_canvas.dart';

class LocalImage extends ImageProvider<LocalImage> {
  LocalImage(this.result);
  final Future<ui.Image> result;
  @override
  Future<LocalImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(LocalImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        result.then((image) => ImageInfo(image: image.clone())),
      );
}

class LocalTiles extends TileProvider {
  LocalTiles(this.result);
  final Future<ui.Image> result;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      LocalImage(result);
}

Uint8List tilePng() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

Future<ui.Image> decodeTile() async {
  final codec = await ui.instantiateImageCodec(tilePng());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

class OriginFake implements MapOriginRepository {
  OriginFake(this.result);
  Future<MapOrigin?> result;
  int calls = 0;
  @override
  Future<MapOrigin?> load() {
    calls++;
    return result;
  }
}

void main() {
  Future<void> mount(WidgetTester t, MapEnvironment env) async {
    await t.pumpWidget(
      Provider<MapEnvironment>.value(
        value: env,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: GeographicMapCanvas()),
          ),
        ),
      ),
    );
    await t.pump();
  }

  test(
    'Point EWKB preserva longitud/latitud y rechaza SRID/rangos inválidos',
    () {
      final bytes = ByteData(25)
        ..setUint8(0, 1)
        ..setUint32(1, 0x20000001, Endian.little)
        ..setUint32(5, 4326, Endian.little)
        ..setFloat64(9, -77, Endian.little)
        ..setFloat64(17, -12, Endian.little);
      String hex() => bytes.buffer
          .asUint8List()
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final point = GeoCoordinate.fromGeography(hex());
      expect(point.latitude, -12);
      expect(point.longitude, -77);
      bytes.setUint32(5, 3857, Endian.little);
      expect(() => GeoCoordinate.fromGeography(hex()), throwsFormatException);
      for (final value in [null, '', 'POINT(-77 -12)', '00', {}]) {
        expect(() => GeoCoordinate.fromGeography(value), throwsFormatException);
      }
      expect(() => GeoCoordinate(91, 0), throwsFormatException);
      expect(() => GeoCoordinate(0, double.nan), throwsFormatException);
    },
  );
  test('Solo permisos de ubicación en primer plano, sin seguimiento', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('ACCESS_FINE_LOCATION'));
    expect(manifest, contains('ACCESS_COARSE_LOCATION'));
    expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    expect(File('pubspec.yaml').readAsStringSync(), contains('geolocator:'));
  });
  testWidgets(
    'Cartografía local inyectada, centro neutral, zoom, pan y recentrado',
    (t) async {
      final image = await t.runAsync(decodeTile);
      addTearDown(image!.dispose);
      await mount(
        t,
        MapEnvironment(createTiles: () => LocalTiles(Future.value(image))),
      );
      await t.pumpAndSettle();
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(find.text('Vista general · no es tu ubicación'), findsOneWidget);
      final map = t.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
      expect(map.camera.center.latitude, 0);
      expect(map.camera.zoom, 2);
      expect(find.byKey(const ValueKey('tiles-loading')), findsNothing);
      await t.tap(find.byTooltip('Acercar mapa'));
      await t.pumpAndSettle();
      expect(map.camera.zoom, 3);
      await t.drag(find.byType(FlutterMap), const Offset(70, 0));
      await t.pumpAndSettle();
      expect(map.camera.center.longitude, isNot(0));
      await t.tap(find.byTooltip('Centrar vista inicial'));
      await t.pumpAndSettle();
      expect(map.camera.center.longitude, 0);
      expect(map.camera.zoom, 2);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Carga diferida de mosaicos y error visible con reintento', (
    t,
  ) async {
    final image = await t.runAsync(decodeTile);
    addTearDown(image!.dispose);
    final pending = Completer<ui.Image>();
    var attempt = 0;
    await mount(
      t,
      MapEnvironment(
        createTiles: () =>
            LocalTiles(attempt++ == 0 ? pending.future : Future.value(image)),
      ),
    );
    expect(find.byKey(const ValueKey('tiles-loading')), findsOneWidget);
    pending.completeError(StateError('Fallo sintético del proveedor'));
    await t.pumpAndSettle();
    expect(
      find.textContaining('No se pudieron cargar algunos mosaicos'),
      findsOneWidget,
    );
    await t.tap(find.text('Reintentar cartografía'));
    await t.pumpAndSettle();
    expect(
      find.textContaining('No se pudieron cargar algunos mosaicos'),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('tiles-loading')), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Origen de zona autorizado, fallo recuperable y preferencia de sesión',
    (t) async {
      final waiting = Completer<MapOrigin?>();
      final repo = OriginFake(waiting.future);
      await mount(t, MapEnvironment(origins: repo));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      waiting.completeError(const FormatException());
      await t.pumpAndSettle();
      expect(
        find.textContaining('No se pudo obtener el centro'),
        findsOneWidget,
      );
      repo.result = Future.value(
        MapOrigin(GeoCoordinate(-12, -77), 'Zona sintética'),
      );
      await t.tap(find.text('Reintentar centro'));
      await t.pumpAndSettle();
      expect(find.text('Zona sintética'), findsOneWidget);
      expect(
        t
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!
            .camera
            .center
            .latitude,
        -12,
      );
      await t.pumpWidget(const SizedBox());
      await mount(
        t,
        MapEnvironment(
          origins: repo,
          sessionOrigin: MapOrigin(
            GeoCoordinate(10, 20),
            'Referencia autorizada de sesión',
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(repo.calls, 2);
      expect(find.text('Referencia autorizada de sesión'), findsOneWidget);
    },
  );
  testWidgets('Una lectura de centro tardía no actualiza después de dispose', (
    t,
  ) async {
    final wait = Completer<MapOrigin?>();
    await mount(t, MapEnvironment(origins: OriginFake(wait.future)));
    await t.pumpWidget(const SizedBox());
    wait.complete(MapOrigin(GeoCoordinate(10, 20), 'Tardío'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
