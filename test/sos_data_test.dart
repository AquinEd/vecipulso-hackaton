import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hackaton_veci_pulso/features/emergency/models/sos_models.dart';
import 'package:hackaton_veci_pulso/features/emergency/data/sos_repository.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/controllers/sos_controllers.dart';

const id = '11111111-1111-4111-8111-111111111111';

class SignedSos extends SupabaseSosRepository {
  SignedSos(super.client);
  @override
  String get uid => id;
}

class EmptySos implements SosRepository {
  @override
  Future<List<SosAlert>> alerts({bool mine = false, int offset = 0}) async =>
      [];
  @override
  Future<List<CriticalResource>> resources({int offset = 0}) async => [];
  @override
  Future<List<SupportGroup>> groups({int offset = 0}) async => [];
  @override
  Future<SosAlert> detail(String id) async => SosAlert.fromJson(alert());
  @override
  Future<List<HelpResponse>> responses(String id) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SosJson alert() => {
  'id': id,
  'autor_id': id,
  'zona_id': id,
  'clase': 'soporte',
  'tipo': 'salud',
  'urgencia': 'critica',
  'estado': 'sin_verificar',
  'ubicacion_aprox': 'SRID=4326;POINT(-77 -12)',
  'creado_en': '2026-01-01T00:00:00-05:00',
};
SupabaseSosRepository repository(
  Future<http.Response> Function(http.Request) respond,
) => SupabaseSosRepository(
  SupabaseClient(
    'https://local.invalid',
    'test',
    httpClient: MockClient((r) async {
      final result = await respond(r);
      return http.Response.bytes(
        result.bodyBytes,
        result.statusCode,
        request: r,
        headers: {'content-type': 'application/json', ...result.headers},
      );
    }),
  ),
);
void main() {
  test('Respuestas carga todas las páginas con RLS y no devuelve una lista parcial tras un fallo', () async {
    final offsets = <int>[];
    var fail = false;
    final repo = repository((request) async {
      expect(request.url.path, '/rest/v1/sos_respuestas');
      expect(request.url.queryParameters['alerta_id'], 'eq.$id');
      expect(request.url.queryParameters['limit'], '50');
      final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
      offsets.add(offset);
      if (fail && offset > 0) {
        return http.Response('{"code":"42501","message":"private"}', 403);
      }
      final rows = [
        for (
          var i = offset;
          i <
              (offset == 0
                  ? 2
                  : offset == 2
                  ? 3
                  : offset);
          i++
        )
          {
            'id':
                '11111111-1111-4111-8111-${(i + 1).toString().padLeft(12, '0')}',
            'alerta_id': id,
            'voluntario_id': id,
            'estado': 'ofrecida',
            'creado_en': '2026-01-01T00:00:00Z',
            'actualizado_en': '2026-01-01T00:00:00Z',
          },
      ];
      return http.Response(jsonEncode(rows), 200);
    });
    final rows = await repo.responses(id);
    expect(rows.length, 3);
    expect(offsets, [0, 2, 3]);
    fail = true;
    await expectLater(repo.responses(id), throwsA(SosFailure.denied));
  });
  test(
    'Controladores de funcionalidades aceptan repositorio sin cliente Supabase',
    () async {
      final repo = EmptySos();
      final alerts = AlertsController(repo),
          resources = ResourcesController(repo),
          groups = BrigadesController(repo),
          detail = AlertDetailController(repo),
          help = HelpResponsesController(repo);
      await alerts.refresh(mine: true);
      await resources.refresh();
      await groups.refresh();
      await help.refresh(id);
      await detail.refresh(id);
      expect(alerts.stage, SosStage.empty);
      expect(resources.stage, SosStage.empty);
      expect(groups.stage, SosStage.empty);
      expect(help.stage, SosStage.empty);
      expect(detail.data?.id, id);
      alerts.dispose();
      resources.dispose();
      groups.dispose();
      help.dispose();
      detail.dispose();
    },
  );
  test('Ofrecimiento fija identidad actual, valida UUID y conserva NULL geográfico', () async {
    final base = repository((r) async {
      expect(r.method, 'POST');
      expect(r.url.path, '/rest/v1/sos_respuestas');
      expect(jsonDecode(r.body), {
        'id': id,
        'alerta_id': id,
        'voluntario_id': id,
        'recurso_id': null,
        'mensaje': null,
        'ubicacion_aprox': null,
      });
      return http.Response(
        jsonEncode({
          'id': id,
          'alerta_id': id,
          'voluntario_id': id,
          'estado': 'ofrecida',
          'creado_en': '2026-01-01T00:00:00Z',
          'actualizado_en': '2026-01-01T00:00:00Z',
        }),
        200,
      );
    });
    final response = await SignedSos(base.client).offer(id: id, alertId: id);
    expect(response.voluntarioId, id);
    expect(response.ubicacionAprox, isNull);
    expect(
      HelpResponse.fromJson(response.toJson()).estado,
      HelpStatus.ofrecida,
    );
    await expectLater(
      SignedSos(base.client).offer(id: 'demo', alertId: id),
      throwsA(SosFailure.invalid),
    );
  });
  test('RPC de cercanía y resumen respetan la proyección', () async {
    final repo = repository((r) async {
      if (r.url.path.endsWith('resumen_emergencia')) {
        return http.Response(
          jsonEncode({
            'zona': 'Barrio',
            'en_riesgo': false,
            'reportes_activos': 0,
            'actualizado_en': '2026-01-01T00:00:00Z',
          }),
          200,
        );
      }
      expect(jsonDecode(r.body), {
        'p_lat': -12.0,
        'p_lng': -77.0,
        'p_radio_m': 5000,
      });
      return http.Response(
        jsonEncode([
          {
            'id': id,
            'clase': 'alerta',
            'tipo': 'salud',
            'urgencia': 'normal',
            'estado': 'sin_verificar',
            'verificada': false,
            'es_mia': false,
            'distancia_m': 300,
            'lat': -12,
            'lng': -77,
            'creado_en': '2026-01-01T00:00:00Z',
          },
        ]),
        200,
      );
    });
    expect((await repo.summary())?.reportesActivos, 0);
    final row = (await repo.nearby(SosPoint(-12, -77))).single;
    expect(row.distanciaM, 300);
    expect(row.descripcion, isNull);
    expect(NearbyAlert.fromJson(row.toJson()).verificada, isFalse);
  });
  test('Sesión expirada y errores de negocio producen mensajes seguros', () {
    for (final entry in {
      'PGRST301': SosFailure.session,
      '23505': SosFailure.duplicate,
      '23514': SosFailure.invalid,
    }.entries) {
      expect(
        SosFailure.from(
          PostgrestException(message: 'detalle privado', code: entry.key),
        ),
        entry.value,
      );
    }
    expect(
      SosFailure.from(
        const PostgrestException(
          message: 'Límite de alertas por hora alcanzado',
          code: 'P0001',
        ),
      ),
      SosFailure.quota,
    );
  });
  test('Filas y NULL conservan UUID, UTC, estados y geografía', () {
    final a = SosAlert.fromJson(alert());
    expect(a.creadoEn.hour, 5);
    expect(a.creadoLocal, isNull);
    expect(a.ubicacionAprox.lat, -12);
    expect(SosAlert.fromJson(a.toJson()).toJson(), a.toJson());
    expect(
      () => SosAlert.fromJson({...alert(), 'id': 'demo'}),
      throwsFormatException,
    );
    expect(
      () => SosAlert.fromJson({...alert(), 'estado': 'inventado'}),
      throwsArgumentError,
    );
    final resource = CriticalResource.fromJson({
      'id': id,
      'zona_id': id,
      'propietario_id': id,
      'tipo': 'agua',
      'cantidad': 1,
      'disponible': true,
      'creado_en': '2026-01-01T00:00:00Z',
    });
    expect(resource.ubicacionAprox, isNull);
    expect(CriticalResource.fromJson(resource.toJson()).descripcion, isNull);
    final group = SupportGroup.fromJson({
      'id': id,
      'zona_id': id,
      'nombre': 'Brigada',
      'tipo': 'brigada',
    });
    expect(group.contacto, isNull);
    expect(group.integrantes, isNull);
  });
  test('EWKB de PostGIS y coordenadas inválidas', () {
    final bytes = ByteData(25)
      ..setUint8(0, 1)
      ..setUint32(1, 0x20000001, Endian.little)
      ..setUint32(5, 4326, Endian.little)
      ..setFloat64(9, -77, Endian.little)
      ..setFloat64(17, -12, Endian.little);
    final hex = bytes.buffer
        .asUint8List()
        .map((v) => v.toRadixString(16).padLeft(2, '0'))
        .join();
    expect(SosPoint.parse(hex).lng, -77);
    expect(() => SosPoint.parse('0102'), throwsFormatException);
    expect(() => SosPoint(double.nan, 0), throwsFormatException);
  });
  test('Emisión usa firma efectiva, UUID estable y fallback sin GPS', () async {
    final repo = repository((r) async {
      expect(r.url.path, '/rest/v1/rpc/emitir_alerta');
      expect(jsonDecode(r.body), {
        'p_id': id,
        'p_clase': 'soporte',
        'p_tipo': 'salud',
        'p_urgencia': 'critica',
        'p_descripcion': null,
        'p_lat': null,
        'p_lng': null,
        'p_creado_local': null,
      });
      return http.Response(jsonEncode(id), 200);
    });
    expect(
      await repo.emit(
        id: id,
        kind: AlertClass.soporte,
        type: EmergencyType.salud,
        urgency: AlertUrgency.critica,
      ),
      id,
    );
  });
  test('Ayuda actualizada por RPC se relee, nunca UPDATE directo', () async {
    final repo = repository((r) async {
      if (r.method == 'POST') {
        expect(r.url.path, '/rest/v1/rpc/actualizar_ayuda');
        expect(jsonDecode(r.body), {'p_resp': id, 'p_estado': 'aceptada'});
        return http.Response('', 204);
      }
      expect(r.url.path, '/rest/v1/sos_respuestas');
      expect(r.url.queryParameters['id'], 'eq.$id');
      return http.Response(
        jsonEncode({
          'id': id,
          'alerta_id': id,
          'voluntario_id': id,
          'estado': 'aceptada',
          'creado_en': '2026-01-01T00:00:00Z',
          'actualizado_en': '2026-01-01T00:00:00Z',
        }),
        200,
      );
    });
    expect(
      (await repo.updateHelp(id, HelpStatus.aceptada)).estado,
      HelpStatus.aceptada,
    );
  });
  test('Listas vacías, fallo remoto y RLS no se convierten en éxito', () async {
    final empty = repository((r) async => http.Response('[]', 200));
    expect(await empty.alerts(), isEmpty);
    expect(await empty.resources(), isEmpty);
    expect(await empty.groups(), isEmpty);
    final denied = repository(
      (r) async => http.Response('{"code":"42501","message":"private"}', 403),
    );
    await expectLater(denied.alerts(), throwsA(SosFailure.denied));
    final offline = repository((r) async => throw TimeoutException('red'));
    await expectLater(offline.resources(), throwsA(SosFailure.network));
    final server = repository(
      (r) async => http.Response('{"code":"XX000","message":"private"}', 500),
    );
    await expectLater(server.groups(), throwsA(SosFailure.server));
  });
  test(
    'Controlador descarta carga antigua, reintenta, limpia y libera',
    () async {
      final c = SosController<List<int>>(), slow = Completer<List<int>>();
      final first = c.perform(() => slow.future);
      expect(c.stage, SosStage.loading);
      await c.perform(() async => [2]);
      slow.complete([1]);
      await first;
      expect(c.data, [2]);
      await c.perform(() async => throw SosFailure.denied);
      expect(c.stage, SosStage.denied);
      await c.perform(() async => []);
      expect(c.stage, SosStage.empty);
      expect(c.failure, isNull);
      c.clear();
      expect(c.stage, SosStage.initial);
      final pending = Completer<List<int>>();
      final last = c.perform(() => pending.future);
      c.dispose();
      pending.complete([3]);
      await last;
      expect(c.data, isNull);
    },
  );
  test(
    'Doble escritura y clear durante operación preservan exclusión',
    () async {
      final c = SosController<int>(), pending = Completer<int>();
      var calls = 0;
      final write = c.perform(() {
        calls++;
        return pending.future;
      }, write: true);
      await c.perform(() async {
        calls++;
        return 2;
      }, write: true);
      expect(calls, 1);
      c.clear();
      await c.perform(() async {
        calls++;
        return 3;
      }, write: true);
      expect(calls, 1);
      pending.complete(1);
      await write;
      expect(c.data, isNull);
      await c.perform(() async => 4, write: true);
      expect(c.data, 4);
      c.dispose();
    },
  );
}
