import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:hackaton_veci_pulso/features/maps/data/location_service.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/controllers/location_controller.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/widgets/geographic_map_canvas.dart';

Position syntheticPosition({bool hasAccuracy = true}) => Position(
  longitude: -77,
  latitude: -12,
  timestamp: DateTime.now().toUtc(),
  accuracy: 80,
  hasAccuracy: hasAccuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class LocationPlatformFake extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission decision = LocationPermission.whileInUse;
  LocationAccuracyStatus precision = LocationAccuracyStatus.precise;
  Object? error;
  int reads = 0, requests = 0, streams = 0;
  LocationSettings? settings;
  Completer<Position>? gate;
  Completer<LocationPermission>? permissionGate;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return permissionGate == null ? decision : await permissionGate!.future;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    reads++;
    settings = locationSettings;
    if (error case final e?) throw e;
    return gate == null ? syntheticPosition() : await gate!.future;
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => precision;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streams++;
    throw StateError('El seguimiento está prohibido');
  }
}

void main() {
  LocationController controller(LocationPlatformFake p) =>
      LocationController(GeolocatorLocationService(platform: p));

  for (final entry in [
    (
      precision: LocationAccuracyStatus.precise,
      expected: PositionPrecision.precise,
    ),
    (
      precision: LocationAccuracyStatus.reduced,
      expected: PositionPrecision.approximate,
    ),
    (
      precision: LocationAccuracyStatus.unknown,
      expected: PositionPrecision.unknown,
    ),
  ]) {
    test('Lectura puntual con precisión ${entry.expected.name}', () async {
      final p = LocationPlatformFake()..precision = entry.precision;
      final c = controller(p);
      expect(p.reads, 0);
      expect(p.requests, 0);
      await c.locate();
      expect(c.stage, LocationStage.ready);
      expect(c.location!.precision, entry.expected);
      expect(c.location!.coordinate.latitude, -12);
      expect(c.location!.accuracyMeters, 80);
      expect(p.requests, 0);
      expect(p.reads, 1);
      expect(p.streams, 0);
      expect(p.settings!.timeLimit, const Duration(seconds: 20));
      expect(p.settings!.accuracy, LocationAccuracy.medium);
      c.dispose();
    });
  }
  for (final entry in [
    (decision: LocationPermission.whileInUse, expected: LocationStage.ready),
    (decision: LocationPermission.denied, expected: LocationStage.denied),
    (
      decision: LocationPermission.deniedForever,
      expected: LocationStage.permanentlyDenied,
    ),
  ]) {
    test(
      'Permiso solicitado solo por acción, decisión ${entry.decision.name}',
      () async {
        final p = LocationPlatformFake()
          ..permission = LocationPermission.denied
          ..decision = entry.decision;
        final c = controller(p);
        expect(p.requests, 0);
        await c.locate();
        expect(p.requests, 1);
        expect(c.stage, entry.expected);
        expect(p.reads, entry.expected == LocationStage.ready ? 1 : 0);
        c.dispose();
      },
    );
  }
  test(
    'Bloqueo permanente no reabre el diálogo y GPS apagado no lee',
    () async {
      final p = LocationPlatformFake()
        ..permission = LocationPermission.deniedForever;
      final c = controller(p);
      await c.locate();
      expect(c.stage, LocationStage.permanentlyDenied);
      expect(p.requests, 0);
      p.enabled = false;
      await c.locate();
      expect(c.stage, LocationStage.disabled);
      expect(p.reads, 0);
      c.dispose();
    },
  );
  for (final error in [
    (value: TimeoutException('synthetic'), expected: LocationStage.timeout),
    (value: StateError('synthetic'), expected: LocationStage.unavailable),
    (
      value: const LocationServiceDisabledException(),
      expected: LocationStage.disabled,
    ),
    (
      value: const PermissionDeniedException('synthetic'),
      expected: LocationStage.denied,
    ),
  ]) {
    test(
      'Error de lectura ${error.expected.name} y reintento explícito',
      () async {
        final p = LocationPlatformFake()..error = error.value;
        final c = controller(p);
        await c.locate();
        expect(c.stage, error.expected);
        expect(c.location, isNull);
        expect(c.failure!.message, isNot(contains('synthetic')));
        p.error = null;
        await c.locate();
        expect(c.stage, LocationStage.ready);
        expect(p.reads, 2);
        c.dispose();
      },
    );
  }
  test('Doble pulsación y clear no abren una segunda lectura nativa', () async {
    final p = LocationPlatformFake()..gate = Completer<Position>();
    final c = controller(p);
    final first = c.locate();
    await Future<void>.delayed(Duration.zero);
    await c.locate();
    c.clear();
    await c.locate();
    expect(p.reads, 1);
    p.gate!.complete(syntheticPosition());
    await first;
    expect(c.location, isNull);
    expect(c.stage, LocationStage.initial);
    c.dispose();
  });
  test(
    'Dispose durante permiso evita iniciar GPS y no notifica tarde',
    () async {
      final p = LocationPlatformFake()
        ..permission = LocationPermission.denied
        ..permissionGate = Completer<LocationPermission>();
      final c = controller(p);
      var changes = 0;
      c.addListener(() => changes++);
      final pending = c.locate();
      await Future<void>.delayed(Duration.zero);
      expect(changes, 1);
      c.dispose();
      p.permissionGate!.complete(LocationPermission.whileInUse);
      await pending;
      expect(p.reads, 0);
      expect(changes, 1);
    },
  );
  test('Cambio de sesión descarta coordenadas y limpia memoria', () async {
    var user = 'synthetic-A';
    final p = LocationPlatformFake()..gate = Completer<Position>();
    final c = LocationController(
      GeolocatorLocationService(platform: p),
      sessionId: () => user,
    );
    final pending = c.locate();
    await Future<void>.delayed(Duration.zero);
    user = 'synthetic-B';
    p.gate!.complete(syntheticPosition());
    await pending;
    expect(c.location, isNull);
    expect(c.stage, LocationStage.session);
    c.syncSession();
    expect(c.stage, LocationStage.initial);
    c.dispose();
  });
  test('No existe stream ni acceso Supabase en la capa de ubicación', () {
    for (final name in [
      'lib/features/maps/data/location_service.dart',
      'lib/features/maps/presentation/controllers/location_controller.dart',
    ]) {
      final code = File(name).readAsStringSync();
      expect(code, isNot(contains('getPositionStream(')));
      expect(code, isNot(contains('supabase')));
    }
  });
  testWidgets(
    'Sin solicitud inicial, centra e indica posición y falla sin bloquear mapa',
    (t) async {
      final p = LocationPlatformFake()
        ..precision = LocationAccuracyStatus.reduced;
      final c = controller(p);
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: c,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: GeographicMapCanvas()),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(p.reads, 0);
      expect(p.requests, 0);
      await t.tap(find.text('Usar mi ubicación'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('own-position')), findsOneWidget);
      expect(
        find.text('Tu ubicación aproximada · lectura puntual'),
        findsOneWidget,
      );
      final camera = t
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      expect(camera.camera.center.latitude, -12);
      p.permission = LocationPermission.deniedForever;
      await t.tap(find.text('Actualizar mi ubicación'));
      await t.pumpAndSettle();
      expect(
        find.text(LocationFailure.permanentlyDenied.message),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('own-position')), findsNothing);
      expect(find.text('Vista general · no es tu ubicación'), findsOneWidget);
      expect(camera.camera.center.latitude, 0);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
