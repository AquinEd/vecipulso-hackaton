import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hackaton_veci_pulso/features/services/data/services_repository.dart';
import 'package:hackaton_veci_pulso/features/services/models/service_rows.dart';
import 'package:hackaton_veci_pulso/features/services/presentation/controllers/services_controllers.dart';

class _SignedInRecommendations extends RecommendationsRepository {
  _SignedInRecommendations(super.client);
  @override
  String get uid => '22222222-2222-4222-8222-222222222222';
}

void main() {
  const id = '11111111-1111-4111-8111-111111111111';
  test('La RPC conserva el sello del servidor, admite media nula y valida el punto', () {
    final row = {
      'id': id,
      'titulo': 'Servicio',
      'categoria': 'Cocina',
      'proveedor': 'Vecino',
      'distancia_m': 50,
      'recomendaciones': 0,
      'visto_bueno': false,
      'lat': -12,
      'lng': -77.5,
    };
    final item = NearbyService.fromJson(row);
    expect(item.promedio, isNull);
    expect(item.vistoBueno, isFalse);
    expect(item.lat, -12.0);
    expect(
      () => NearbyService.fromJson({...row, 'lng': 181}),
      throwsFormatException,
    );
  });
  final request = {
    'id': id,
    'servicio_id': id,
    'solicitante_id': id,
    'estado': 'completada',
    'mensaje': null,
    'creado_en': '2026-01-01T12:00:00-05:00',
  };
  SupabaseClient client(Future<http.Response> Function(http.Request) handler) =>
      SupabaseClient(
        'https://local.invalid',
        'test',
        httpClient: MockClient((request) async {
          final response = await handler(request);
          return http.Response.bytes(
            response.bodyBytes,
            response.statusCode,
            headers: response.headers,
            request: request,
          );
        }),
      );
  test(
    'INSERT de recomendación espera confirmación y comunica duplicado',
    () async {
      var calls = 0;
      final repo = _SignedInRecommendations(
        client((r) async {
          calls++;
          expect(r.url.path, '/rest/v1/recomendaciones');
          expect(r.method, 'POST');
          expect(jsonDecode(r.body), {
            'servicio_id': id,
            'id': id,
            'autor_id': '22222222-2222-4222-8222-222222222222',
            'puntaje': 5,
            'comentario': null,
          });
          return calls == 1
              ? http.Response(
                  jsonEncode({'id': id}),
                  200,
                  headers: {'content-type': 'application/json'},
                )
              : http.Response(
                  jsonEncode({'code': '23505', 'message': 'duplicate'}),
                  409,
                );
        }),
      );
      expect(await repo.recommend(id, id, 5), id);
      await expectLater(
        repo.recommend(id, id, 5),
        throwsA(ServicesFailure.duplicate),
      );
    },
  );

  test('Solicitud conserva UUID, NULL y fecha UTC', () {
    final r = ServiceRequest.fromJson(request);
    expect(r.estado, RequestStatus.completada);
    expect(r.mensaje, isNull);
    expect(r.creadoEn.hour, 17);
    expect(
      () => ServiceRequest.fromJson({...request, 'id': 'demo'}),
      throwsFormatException,
    );
    expect(
      () => ServiceRequest.fromJson({...request, 'creado_en': 'x'}),
      throwsFormatException,
    );
  });
  test('RPC cercana usa parámetros exactos y conserva vacío', () async {
    final repo = ServicesRepository(
      client((r) async {
        expect(r.url.path, '/rest/v1/rpc/buscar_servicios_cercanos');
        expect(jsonDecode(r.body), {
          'p_lat': -12,
          'p_lng': -77,
          'p_radio_m': 500,
          'p_texto': 'cocina',
          'p_min_estrellas': 4,
        });
        return http.Response('[]', 200);
      }),
    );
    expect(
      await repo.nearby(-12, -77, radius: 500, query: 'cocina', minimum: 4),
      isEmpty,
    );
    await expectLater(
      repo.nearby(double.nan, 0),
      throwsA(ServicesFailure.invalid),
    );
  });
  test('Transición por RPC recupera fila persistida', () async {
    final calls = <String>[];
    final repo = RequestsRepository(
      client((r) async {
        calls.add(r.url.path);
        if (r.method == 'POST') {
          expect(jsonDecode(r.body), {
            'p_solicitud': id,
            'p_estado': 'completada',
          });
          return http.Response('', 204);
        }
        expect(r.url.queryParameters['id'], 'eq.$id');
        return http.Response(
          jsonEncode(request),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    expect(
      (await repo.transition(id, RequestStatus.completada)).estado,
      RequestStatus.completada,
    );
    expect(calls, [
      '/rest/v1/rpc/actualizar_solicitud_servicio',
      '/rest/v1/solicitudes_servicio',
    ]);
  });
  test('Errores de acceso y red traducidos', () async {
    final repo = ServicesRepository(
      client(
        (r) async => http.Response(
          jsonEncode({'code': '42501', 'message': 'private'}),
          403,
        ),
      ),
    );
    await expectLater(repo.directory(), throwsA(ServicesFailure.denied));
    final offline = ServicesRepository(
      client((r) async => throw TimeoutException('red')),
    );
    await expectLater(offline.categories(), throwsA(ServicesFailure.network));
  });
  test('Respuesta vieja, reintento, limpieza y dispose', () async {
    final c = ServiceController<List<int>>();
    final first = Completer<List<int>>();
    final pending = c.load(() => first.future);
    expect(c.stage, ServiceStage.loading);
    await c.load(() async => []);
    expect(c.stage, ServiceStage.empty);
    first.complete([1]);
    await pending;
    expect(c.data, isEmpty);
    await c.load(() async => throw ServicesFailure.denied);
    expect(c.stage, ServiceStage.denied);
    await c.load(() async => [2]);
    expect(c.data, [2]);
    expect(c.failure, isNull);
    c.clear();
    expect(c.stage, ServiceStage.initial);
    final last = Completer<List<int>>();
    final waiting = c.load(() => last.future);
    c.dispose();
    last.complete([3]);
    await waiting;
    expect(c.data, isNull);
  });
}
