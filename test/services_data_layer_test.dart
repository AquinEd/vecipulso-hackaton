import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hackaton_veci_pulso/features/services/data/services_repository.dart';
import 'package:hackaton_veci_pulso/features/services/models/service_rows.dart';
import 'package:hackaton_veci_pulso/features/services/presentation/controllers/services_controllers.dart';

class _Customer extends RequestsRepository {
  _Customer(super.client);
  @override
  String get uid => '22222222-2222-4222-8222-222222222222';
}

class _Owner extends ServicesRepository {
  _Owner(super.client);
  @override
  String get uid => '22222222-2222-4222-8222-222222222222';
}

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
  test('Publicación y edición usan zona y propietario de sesión, incluida desactivación', () async {
    const owner = '22222222-2222-4222-8222-222222222222';
    final row = {
      'id': id,
      'zona_id': id,
      'categoria_id': 7,
      'proveedor_id': owner,
      'titulo': 'Mesas',
      'activo': true,
      'creado_en': '2026-01-01T00:00:00Z',
    };
    final repo = _Owner(
      client((r) async {
        Object data;
        if (r.url.path.endsWith('/rpc/mi_zona')) {
          data = id;
        } else if (r.method == 'POST') {
          final body = jsonDecode(r.body) as Map;
          expect(body['proveedor_id'], owner);
          expect(body['zona_id'], id);
          expect(body.containsKey('ubicacion_aprox'), isFalse);
          data = row;
        } else {
          expect(r.url.queryParameters['proveedor_id'], 'eq.$owner');
          if (r.method == 'PATCH') {
            expect(jsonDecode(r.body)['activo'], false);
            data = {...row, 'activo': false};
          } else {
            data = [row];
          }
        }
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    expect(
      (await repo.publish(id: id, title: 'Mesas', categoryId: 7)).proveedorId,
      owner,
    );
    expect((await repo.mine()).single.id, id);
    expect(
      (await repo.update(id, title: 'Mesas', active: false)).activo,
      isFalse,
    );
  });
  test(
    'Edición denegada y solicitud inexistente conservan el error de dominio',
    () async {
      final repo = _Owner(
        client(
          (r) async => http.Response(
            jsonEncode({'code': '42501', 'message': 'denied'}),
            403,
          ),
        ),
      );
      await expectLater(
        repo.update(id, title: 'Mesas', active: false),
        throwsA(ServicesFailure.denied),
      );
      final requests = RequestsRepository(
        client(
          (r) async => http.Response(
            jsonEncode({'code': 'P0001', 'message': 'La solicitud no existe'}),
            400,
          ),
        ),
      );
      await expectLater(
        requests.transition(id, RequestStatus.completada),
        throwsA(ServicesFailure.missing),
      );
    },
  );
  test('Solicitar usa el UID de sesión, el estado por defecto y comunica solicitud duplicada', () async {
    var attempts = 0;
    final repo = _Customer(
      client((r) async {
        expect(r.method, 'POST');
        expect(r.url.path, '/rest/v1/solicitudes_servicio');
        final body = jsonDecode(r.body);
        expect(body['solicitante_id'], '22222222-2222-4222-8222-222222222222');
        expect(body.containsKey('estado'), isFalse);
        attempts++;
        if (attempts == 2) {
          return http.Response(
            jsonEncode({'code': '23505', 'message': 'duplicate'}),
            409,
          );
        }
        return http.Response(
          jsonEncode({...request, 'estado': 'solicitada'}),
          200,
        );
      }),
    );
    expect((await repo.create(id, id)).estado, RequestStatus.solicitada);
    await expectLater(repo.create(id, id), throwsA(ServicesFailure.duplicate));
  });
  test(
    'Categoría eliminada, puntuación inválida y experiencia no autorizada',
    () async {
      final repo = _Owner(
        client((r) async {
          if (r.url.path.endsWith('mi_zona')) {
            return http.Response(jsonEncode(id), 200);
          }
          return http.Response(
            jsonEncode({'code': '23503', 'message': 'invalid category'}),
            409,
          );
        }),
      );
      await expectLater(
        repo.publish(id: id, title: 'Mesas', categoryId: 999),
        throwsA(ServicesFailure.missing),
      );
      var writes = 0;
      final reviews = _SignedInRecommendations(
        client((r) async {
          writes++;
          return http.Response(
            jsonEncode({'code': '42501', 'message': 'denied'}),
            403,
          );
        }),
      );
      for (final score in [0, 6]) {
        await expectLater(
          reviews.recommend(id, id, score),
          throwsA(ServicesFailure.invalid),
        );
      }
      expect(writes, 0);
      await expectLater(
        reviews.recommend(id, id, 4),
        throwsA(ServicesFailure.denied),
      );
    },
  );
  test('Media completa y sello SQL incluyen todas las páginas', () async {
    final repo = RecommendationsRepository(
      client((r) async {
        if (r.url.path.endsWith('/rpc/tiene_visto_bueno')) {
          expect(jsonDecode(r.body), {'n': 3, 'promedio': 4.0});
          return http.Response('true', 200);
        }
        expect(r.url.path, '/rest/v1/recomendaciones');
        expect(r.url.queryParameters['servicio_id'], 'eq.$id');
        expect(r.url.queryParameters['select'], 'id,puntaje');
        final offset = int.parse(r.url.queryParameters['offset'] ?? '0');
        return http.Response(
          jsonEncode(
            offset == 0
                ? [
                    {'id': id, 'puntaje': 5},
                    {'id': id, 'puntaje': 4},
                  ]
                : offset == 2
                ? [
                    {'id': id, 'puntaje': 3},
                  ]
                : [],
          ),
          200,
        );
      }),
    );
    final result = await repo.statistics(id);
    expect(result.count, 3);
    expect(result.average, 4.0);
    expect(result.approved, isTrue);
  });
  test(
    'Directorio por zona pagina y combina título con categoría en el servidor',
    () async {
      final repo = ServicesRepository(
        client((r) async {
          final q = r.url.queryParameters;
          expect(r.method, 'GET');
          expect(r.url.path, '/rest/v1/servicios');
          expect(q['activo'], 'eq.true');
          expect(q['categoria_id'], 'eq.7');
          expect(q['titulo'], 'plfts(spanish).mesas');
          expect(q['offset'], '25');
          expect(q['limit'], '26');
          expect(q['select'], contains('recomendaciones(count)'));
          expect(q['select'], isNot(contains('telefono')));
          return http.Response('[]', 200);
        }),
      );
      expect(
        await repo.page(query: 'mesas', categoryId: 7, offset: 25),
        isEmpty,
      );
    },
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
