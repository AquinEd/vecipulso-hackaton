import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sos_models.dart';

enum SosFailure implements Exception {
  network('No se pudo conectar. Reintenta.'),
  session('Se requiere una sesión válida.'),
  denied('No tienes permiso para esta operación.'),
  missing('El registro no está disponible.'),
  duplicate('El registro ya existe.'),
  invalid('Revisa los datos enviados.'),
  conflict('El estado cambió o la transición no está permitida.'),
  quota('Se alcanzó el límite de alertas por hora.'),
  server('No se pudo completar la operación.');

  const SosFailure(this.message);
  final String message;
  static SosFailure from(Object e) {
    if (e is SosFailure) return e;
    if (e is TimeoutException ||
        e is AuthRetryableFetchException ||
        RegExp('SocketException|ClientException|HandshakeException')
            .hasMatch(e.runtimeType.toString())) {
      return network;
    }
    if (e is AuthException) return session;
    if (e is FormatException || e is TypeError || e is ArgumentError) {
      return invalid;
    }
    if (e is PostgrestException) {
      if (e.code == 'P0001') {
        return switch (e.message) {
          'Perfil incompleto' || 'Se requiere una sesion' => session,
          'No autorizado' => denied,
          'La ayuda no existe' => missing,
          'Límite de alertas por hora alcanzado' => quota,
          'Identificador en uso' => duplicate,
          'Estado obligatorio' ||
          'Coordenadas invalidas' ||
          'Latitud y longitud deben enviarse juntas' => invalid,
          _ => conflict,
        };
      }
      return switch (e.code) {
        '42501' => denied,
        '23505' => duplicate,
        '23503' || 'PGRST116' => missing,
        '23514' || '23502' || '22P02' => invalid,
        'PGRST301' || 'PGRST303' => session,
        _ => server,
      };
    }
    return server;
  }
}

abstract interface class SosRepository {
  String? get userId;
  Future<List<SosAlert>> alerts({bool mine = false, int offset = 0});
  Future<SosAlert> detail(String id);
  Future<String> emit({
    required String id,
    required AlertClass kind,
    required EmergencyType type,
    required AlertUrgency urgency,
    String? description,
    SosPoint? point,
    DateTime? createdLocal,
  });
  Future<SosAlert> cancel(String id);
  Future<List<NearbyAlert>> nearby(SosPoint origin, {int radius = 5000});
  Future<SosSummary?> summary();
  Future<List<HelpResponse>> responses(String alertId);
  Future<String?> publicName(String userId);
  Future<HelpResponse> offer({
    required String id,
    required String alertId,
    String? resourceId,
    String? message,
    SosPoint? point,
  });
  Future<HelpResponse> updateHelp(String id, HelpStatus status);
  Future<List<CriticalResource>> resources({int offset = 0});
  Future<List<SupportGroup>> groups({int offset = 0});
  Future<List<CriticalResource>> resourcePage({
    int offset = 0,
    ResourceType? type,
  });
  Future<List<SupportGroup>> groupPage({
    int offset = 0,
    GroupType? type,
    String query = '',
  });
  Future<CriticalResource> resourceDetail(String id);
  Future<SupportGroup> groupDetail(String id);
  Future<String?> zoneName(String id);
}

class SupabaseSosRepository implements SosRepository {
  SupabaseSosRepository(this.client);
  final SupabaseClient client;
  @override
  Future<String?> zoneName(String id) => run(() async {
    final row = await client
        .from('zonas')
        .select('nombre')
        .eq('id', sosUuid(id))
        .maybeSingle();
    return row?['nombre'] as String?;
  });
  @override
  Future<CriticalResource> resourceDetail(String id) => run(
    () async => CriticalResource.fromJson(
      await client
          .from('recursos_criticos')
          .select()
          .eq('id', sosUuid(id))
          .single(),
    ),
  );
  @override
  Future<SupportGroup> groupDetail(String id) => run(
    () async => SupportGroup.fromJson(
      await client.from('grupos_apoyo').select().eq('id', sosUuid(id)).single(),
    ),
  );
  @override
  Future<List<CriticalResource>> resourcePage({
    int offset = 0,
    ResourceType? type,
  }) => run(() async {
    offsetValid(offset);
    var query = client.from('recursos_criticos').select();
    if (type != null) query = query.eq('tipo', type.name);
    return parse(
      await query
          .order('creado_en', ascending: false)
          .order('id')
          .range(offset, offset + pageSize - 1),
      CriticalResource.fromJson,
    );
  });
  @override
  Future<List<SupportGroup>> groupPage({
    int offset = 0,
    GroupType? type,
    String query = '',
  }) => run(() async {
    offsetValid(offset);
    var request = client.from('grupos_apoyo').select();
    if (type != null) request = request.eq('tipo', type.name);
    final text = query
        .trim()
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    if (text.isNotEmpty) request = request.ilike('nombre', '%$text%');
    return parse(
      await request
          .order('nombre')
          .order('id')
          .range(offset, offset + pageSize - 1),
      SupportGroup.fromJson,
    );
  });
  @override
  String? get userId => client.auth.currentUser?.id;
  static const pageSize = 50;
  String get uid => client.auth.currentUser?.id ?? (throw SosFailure.session);
  Future<T> run<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(const Duration(seconds: 20));
    } catch (e) {
      throw SosFailure.from(e);
    }
  }

  List<T> parse<T>(Object? rows, T Function(SosJson) decode) =>
      List.unmodifiable((rows as List).map((r) => decode(r as SosJson)));
  void offsetValid(int offset) {
    if (offset < 0) throw SosFailure.invalid;
  }

  @override
  Future<List<SosAlert>> alerts({bool mine = false, int offset = 0}) =>
      run(() async {
        offsetValid(offset);
        var query = client.from('alertas_sos').select();
        if (mine) query = query.eq('autor_id', uid);
        return parse(
          await query
              .order('creado_en', ascending: false)
              .order('id')
              .range(offset, offset + pageSize - 1),
          SosAlert.fromJson,
        );
      });
  @override
  Future<SosAlert> detail(String id) => run(
    () async => SosAlert.fromJson(
      await client.from('alertas_sos').select().eq('id', sosUuid(id)).single(),
    ),
  );
  @override
  Future<String> emit({
    required String id,
    required AlertClass kind,
    required EmergencyType type,
    required AlertUrgency urgency,
    String? description,
    SosPoint? point,
    DateTime? createdLocal,
  }) => run(() async {
    return sosUuid(
      await client.rpc(
        'emitir_alerta',
        params: {
          'p_id': sosUuid(id),
          'p_clase': kind.name,
          'p_tipo': type.name,
          'p_urgencia': urgency.name,
          'p_descripcion': description,
          'p_lat': point?.lat,
          'p_lng': point?.lng,
          'p_creado_local': createdLocal?.toUtc().toIso8601String(),
        },
      ),
    );
  });
  @override
  Future<SosAlert> cancel(String id) => run(() async {
    await client.rpc('cancelar_alerta', params: {'p_alerta': sosUuid(id)});
    return detail(id);
  });
  @override
  Future<List<NearbyAlert>> nearby(SosPoint origin, {int radius = 5000}) =>
      run(() async {
        if (radius <= 0) throw SosFailure.invalid;
        return parse(
          await client.rpc(
            'alertas_cercanas',
            params: {
              'p_lat': origin.lat,
              'p_lng': origin.lng,
              'p_radio_m': radius,
            },
          ),
          NearbyAlert.fromJson,
        );
      });
  @override
  Future<SosSummary?> summary() => run(() async {
    final row = await client.rpc('resumen_emergencia').maybeSingle();
    return row == null ? null : SosSummary.fromJson(row);
  });
  @override
  Future<String?> publicName(String userId) => run(() async {
    final row = await client
        .rpc('perfiles_publicos_de_mi_zona')
        .eq('id', sosUuid(userId))
        .maybeSingle();
    return row?['nombre_publico'] as String?;
  });
  @override
  Future<List<HelpResponse>> responses(String alertId) => run(() async {
    final id = sosUuid(alertId);
    final result = <HelpResponse>[];
    var offset = 0;
    while (true) {
      final page = parse(
        await client
            .from('sos_respuestas')
            .select()
            .eq('alerta_id', id)
            .order('creado_en')
            .order('id')
            .range(offset, offset + pageSize - 1),
        HelpResponse.fromJson,
      );
      if (page.isEmpty) return List.unmodifiable(result);
      result.addAll(page);
      offset += page.length;
    }
  });
  @override
  Future<HelpResponse> offer({
    required String id,
    required String alertId,
    String? resourceId,
    String? message,
    SosPoint? point,
  }) => run(
    () async => HelpResponse.fromJson(
      await client
          .from('sos_respuestas')
          .insert({
            'id': sosUuid(id),
            'alerta_id': sosUuid(alertId),
            'voluntario_id': uid,
            'recurso_id': resourceId == null ? null : sosUuid(resourceId),
            'mensaje': message,
            'ubicacion_aprox': point == null
                ? null
                : 'SRID=4326;POINT(${point.lng} ${point.lat})',
          })
          .select()
          .single(),
    ),
  );
  @override
  Future<HelpResponse> updateHelp(String id, HelpStatus status) =>
      run(() async {
        await client.rpc(
          'actualizar_ayuda',
          params: {'p_resp': sosUuid(id), 'p_estado': status.name},
        );
        return HelpResponse.fromJson(
          await client.from('sos_respuestas').select().eq('id', id).single(),
        );
      });
  @override
  Future<List<CriticalResource>> resources({int offset = 0}) => run(() async {
    offsetValid(offset);
    return parse(
      await client
          .from('recursos_criticos')
          .select()
          .order('creado_en', ascending: false)
          .order('id')
          .range(offset, offset + pageSize - 1),
      CriticalResource.fromJson,
    );
  });
  @override
  Future<List<SupportGroup>> groups({int offset = 0}) => run(() async {
    offsetValid(offset);
    return parse(
      await client
          .from('grupos_apoyo')
          .select()
          .order('nombre')
          .order('id')
          .range(offset, offset + pageSize - 1),
      SupportGroup.fromJson,
    );
  });
}
