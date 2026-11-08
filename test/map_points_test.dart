import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hackaton_veci_pulso/features/maps/data/map_environment.dart';
import 'package:hackaton_veci_pulso/features/maps/data/map_points_repository.dart';
import 'package:hackaton_veci_pulso/features/maps/models/map_origin.dart';
import 'package:hackaton_veci_pulso/features/maps/models/map_point.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/controllers/map_points_controller.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/widgets/geographic_map_canvas.dart';

const user = '11111111-1111-4111-8111-111111111111';
String pointId(int index) =>
    '00000000-0000-4000-8000-${index.toRadixString(16).padLeft(12, '0')}';
Map<String, dynamic> pointRow(
  int index, {
  String layer = 'comercio',
  double? lat,
  double? lng,
}) => {
  'capa': layer,
  'id': pointId(index),
  'titulo': 'Punto sintético $index',
  'subtipo': layer == 'comercio' ? 'Oficio' : 'otro',
  'estado': layer == 'alerta'
      ? 'sin_verificar'
      : layer == 'recurso'
      ? 'disponible'
      : 'activo',
  'urgencia': layer == 'alerta' ? 'urgente' : null,
  'lat': lat ?? -12.0,
  'lng': lng ?? -77.0,
  'distancia_m': 100,
};
http.Response reply(http.Request request, Object json, {int status = 200}) =>
    http.Response(
      jsonEncode(json),
      status,
      headers: {'content-type': 'application/json'},
      request: request,
    );

Future<SupabaseMapPointsRepository> sdkRepo(
  Future<http.Response> Function(http.Request) handler, {
  bool signedIn = true,
}) async {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final client = SupabaseClient(
    'https://synthetic.invalid',
    'publishable-test',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      if (request.url.path == '/auth/v1/signup') {
        final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
        return reply(request, {
          'access_token':
              '${encode({'alg': 'HS256'})}.${encode({'sub': user, 'exp': exp, 'role': 'authenticated'})}.synthetic',
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'synthetic-only',
          'user': {
            'id': user,
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
            'app_metadata': {},
            'user_metadata': {},
            'is_anonymous': true,
          },
        });
      }
      return handler(request);
    }),
  );
  addTearDown(client.dispose);
  if (signedIn) await client.auth.signInAnonymously();
  return SupabaseMapPointsRepository(client);
}

class PointsFake implements MapPointsRepository {
  @override
  String? userId = user;
  int calls = 0;
  MapPointsFailure? failure;
  List<MapPoint> rows = [
    for (final (i, layer) in MapPointLayer.values.indexed)
      MapPoint.fromJson(
        pointRow(i, layer: layer.name, lat: -12 + (i - 1.5) * .004),
      ),
  ];
  bool slow = false;
  final pending = <Completer<MapPointsResult>>[];
  @override
  Future<MapPointsResult> load(
    GeoCoordinate origin, {
    int radiusMeters = 3000,
    bool Function()? isActive,
  }) async {
    calls++;
    if (slow) {
      final gate = Completer<MapPointsResult>();
      pending.add(gate);
      return gate.future;
    }
    if (failure case final e?) throw e;
    return MapPointsResult(rows);
  }
}

void main() {
  test('DTO exacto, cuatro capas, coordenadas, NULL y descarte de columnas privadas', () {
    for (final (i, layer) in MapPointLayer.values.indexed) {
      final data = pointRow(i, layer: layer.name)
        ..addAll({'dni': 'SENSITIVE', 'telefono': 'PRIVATE', 'pin': 'SECRET'});
      final point = MapPoint.fromJson(data);
      expect(point.layer, layer);
      expect(point.coordinate.latitude, -12);
      expect(point.coordinate.longitude, -77);
      expect(point.urgency == null, layer != MapPointLayer.alerta);
      expect(point.toJson().keys.toSet(), {
        'capa',
        'id',
        'titulo',
        'subtipo',
        'estado',
        'urgencia',
        'lat',
        'lng',
        'distancia_m',
      });
      expect(jsonEncode(point.toJson()), isNot(contains('SENSITIVE')));
    }
    expect(
      MapPoint.fromJson({...pointRow(1), 'lat': 90, 'lng': -180})
          .coordinate
          .latitude,
      90,
    );
  });
  test(
    'Rechaza coordenadas, UUID y proyecciones malformadas sin rellenarlas',
    () {
      for (final change in [
        {'lat': null},
        {'lat': '-12'},
        {'lat': 91},
        {'lng': 181},
        {'lat': double.nan},
        {'lng': double.infinity},
        {'id': 'demo-point'},
        {'capa': 'favor'},
        {'titulo': null},
        {'distancia_m': -1},
        {'estado': 'inventado'},
        {'urgencia': 'critica'},
      ]) {
        expect(
          () => MapPoint.fromJson({...pointRow(1), ...change}),
          throwsA(anyOf(isA<FormatException>(), isA<ArgumentError>())),
        );
      }
    },
  );
  test('SDK: RPC/parámetros exactos, paginación según filas reales y deduplicación', () async {
    var calls = 0;
    final requests = <http.Request>[];
    final repo = await sdkRepo((request) async {
      requests.add(request);
      calls++;
      return reply(
        request,
        calls == 1
            ? [pointRow(1), pointRow(1), pointRow(2, layer: 'recurso')]
            : [],
      );
    });
    final result = await repo.load(GeoCoordinate(-12, -77));
    expect(result.points.length, 2);
    expect(result.truncated, isFalse);
    expect(calls, 2);
    for (final (i, request) in requests.indexed) {
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/rpc/puntos_mapa');
      expect(jsonDecode(request.body), {
        'p_lat': -12.0,
        'p_lng': -77.0,
        'p_radio_m': 3000,
      });
      expect(
        request.headers['Authorization'] ?? request.headers['authorization'],
        startsWith('Bearer '),
      );
      expect(
        request.url.queryParameters['order'],
        'capa.asc.nullslast,id.asc.nullslast',
      );
      expect(request.url.queryParameters['limit'], '100');
      expect(request.url.queryParameters['offset'], i == 0 ? '0' : '3');
    }
  });
  test('SDK vacío y rechazo previo de sesión/radio inválido', () async {
    var reads = 0;
    final repo = await sdkRepo((r) async {
      reads++;
      return reply(r, []);
    });
    expect((await repo.load(GeoCoordinate(-12, -77))).points, isEmpty);
    await expectLater(
      repo.load(GeoCoordinate(-12, -77), radiusMeters: 0),
      throwsA(MapPointsFailure.invalid),
    );
    final guest = await sdkRepo((r) async {
      fail('No debe consultar sin sesión');
    }, signedIn: false);
    await expectLater(
      guest.load(GeoCoordinate(-12, -77)),
      throwsA(MapPointsFailure.denied),
    );
    expect(reads, 1);
  });
  for (final error in [
    MapPointsFailure.offline,
    MapPointsFailure.denied,
    MapPointsFailure.invalid,
  ]) {
    test('SDK comunica error seguro ${error.name}', () async {
      final repo = await sdkRepo((r) async {
        if (error == MapPointsFailure.offline) {
          throw http.ClientException('SENSITIVE');
        }
        if (error == MapPointsFailure.invalid) {
          return reply(r, [
            {...pointRow(1), 'lat': null},
          ]);
        }
        return reply(r, {
          'code': '42501',
          'message': 'SENSITIVE',
          'details': null,
          'hint': null,
        }, status: 403);
      });
      await expectLater(repo.load(GeoCoordinate(-12, -77)), throwsA(error));
      expect(error.message, isNot(contains('SENSITIVE')));
    });
  }
  test(
    'SDK acota 500 puntos y detecta truncamiento con una fila adicional',
    () async {
      var reads = 0;
      final repo = await sdkRepo((r) async {
        reads++;
        final offset = int.parse(r.url.queryParameters['offset']!);
        final limit = int.parse(r.url.queryParameters['limit']!);
        return reply(r, [
          for (var i = offset; i < offset + limit; i++) pointRow(i),
        ]);
      });
      final result = await repo.load(GeoCoordinate(-12, -77));
      expect(result.points.length, 500);
      expect(result.truncated, isTrue);
      expect(reads, 6);
    },
  );
  test(
    'No devuelve resultados parciales si falla una página posterior',
    () async {
      var reads = 0;
      final repo = await sdkRepo((r) async {
        reads++;
        if (reads == 1) return reply(r, [pointRow(1)]);
        throw http.ClientException('synthetic');
      });
      await expectLater(
        repo.load(GeoCoordinate(-12, -77)),
        throwsA(MapPointsFailure.offline),
      );
    },
  );
  test(
    'Controlador: carga, caché, actualización, vacío, error y reintento',
    () async {
      final repo = PointsFake();
      final c = MapPointsController(repo);
      final load = c.refresh(GeoCoordinate(-12, -77));
      expect(c.stage, MapPointsStage.loading);
      await load;
      expect(c.stage, MapPointsStage.ready);
      await c.refresh(GeoCoordinate(-12, -77));
      expect(repo.calls, 1);
      repo.rows = [];
      await c.refresh(GeoCoordinate(-12, -77), force: true);
      expect(c.stage, MapPointsStage.empty);
      repo.failure = MapPointsFailure.denied;
      await c.refresh(GeoCoordinate(-12, -77), force: true);
      expect(c.stage, MapPointsStage.denied);
      expect(c.result, isNull);
      repo.failure = null;
      await c.refresh(GeoCoordinate(-12, -77));
      expect(c.stage, MapPointsStage.empty);
      c.dispose();
    },
  );
  test(
    'Concurrencia: una consulta idéntica y descarte de respuesta antigua',
    () async {
      final repo = PointsFake()..slow = true;
      final c = MapPointsController(repo);
      final first = c.refresh(GeoCoordinate(-12, -77));
      final duplicate = c.refresh(GeoCoordinate(-12, -77), force: true);
      expect(identical(first, duplicate), isTrue);
      final newer = c.refresh(GeoCoordinate(-12.1, -77));
      expect(repo.calls, 2);
      repo.pending[1].complete(MapPointsResult([]));
      await newer;
      repo.pending[0].complete(MapPointsResult(repo.rows));
      await first;
      expect(c.stage, MapPointsStage.empty);
      expect(c.result!.points, isEmpty);
      c.dispose();
    },
  );
  test('Cambio de sesión y dispose no publican datos pendientes', () async {
    final repo = PointsFake()..slow = true;
    final c = MapPointsController(repo);
    final request = c.refresh(GeoCoordinate(-12, -77));
    repo.userId = pointId(99);
    repo.pending[0].complete(MapPointsResult(repo.rows));
    await request;
    expect(c.result, isNull);
    expect(c.stage, MapPointsStage.denied);
    final next = c.refresh(GeoCoordinate(-12, -77));
    var notifications = 0;
    c.addListener(() => notifications++);
    c.dispose();
    repo.pending[1].complete(MapPointsResult(repo.rows));
    await next;
    expect(notifications, 0);
  });

  Future<void> mount(
    WidgetTester t,
    PointsFake repo, {
    bool neutral = false,
  }) async {
    final controller = MapPointsController(repo);
    addTearDown(controller.dispose);
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: Provider<MapEnvironment>.value(
          value: MapEnvironment(
            sessionOrigin: neutral
                ? null
                : MapOrigin(
                    GeoCoordinate(-12, -77),
                    'Centro sintético de zona',
                  ),
          ),
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: GeographicMapCanvas()),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'Sin GPS: cuatro tipos reales de fixture, ficha pública y recarga',
    (t) async {
      final repo = PointsFake();
      await mount(t, repo);
      expect(repo.calls, 1);
      expect(find.byType(FlutterMap), findsOneWidget);
      for (final point in repo.rows) {
        final marker = find.byKey(ValueKey('map-point:${point.key}'));
        expect(marker, findsOneWidget);
        await t.ensureVisible(marker);
        await t.tap(marker);
        await t.pumpAndSettle();
        expect(find.text(point.title), findsOneWidget);
        expect(find.textContaining('PRIVATE'), findsNothing);
        await t.tap(find.text('Cerrar'));
        await t.pumpAndSettle();
      }
      final update = find.text('Actualizar puntos');
      await t.ensureVisible(update);
      await t.tap(update);
      await t.pumpAndSettle();
      expect(repo.calls, 2 + repo.rows.length);
    },
  );
  testWidgets(
    'Origen neutral no consulta; error de red y reintento sin puntos demo',
    (t) async {
      final repo = PointsFake();
      await mount(t, repo, neutral: true);
      expect(repo.calls, 0);
      expect(
        find.textContaining('La vista general no es un origen'),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
      repo.failure = MapPointsFailure.offline;
      await mount(t, repo);
      expect(find.text(MapPointsFailure.offline.message), findsOneWidget);
      expect(
        find.byKey(ValueKey('map-point:${repo.rows.first.key}')),
        findsNothing,
      );
      repo.failure = null;
      await t.ensureVisible(find.text('Reintentar puntos'));
      await t.tap(find.text('Reintentar puntos'));
      await t.pumpAndSettle();
      expect(
        find.byKey(ValueKey('map-point:${repo.rows.first.key}')),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Puntos coincidentes conservan coordenada y se agrupan sin inventar posiciones',
    (t) async {
      final repo = PointsFake()
        ..rows = [
          for (final (i, layer) in MapPointLayer.values.indexed)
            MapPoint.fromJson(pointRow(i, layer: layer.name)),
        ];
      await mount(t, repo);
      expect(find.byType(Badge), findsOneWidget);
      final marker = find.byKey(ValueKey('map-point:${repo.rows.first.key}'));
      await t.ensureVisible(marker);
      await t.tap(marker);
      await t.pumpAndSettle();
      for (final point in repo.rows) {
        expect(find.text(point.title), findsOneWidget);
      }
      expect(find.byType(ListTile), findsNWidgets(4));
      final controller = Provider.of<MapPointsController>(
        t.element(find.byType(GeographicMapCanvas)),
        listen: false,
      );
      controller.clear();
      await t.pumpAndSettle();
      expect(
        find.text('El punto ya no está disponible en esta consulta.'),
        findsOneWidget,
      );
      for (final point in repo.rows) {
        expect(find.text(point.title), findsNothing);
      }
    },
  );
}
