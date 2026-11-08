import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_rows.dart';

enum ServicesFailure implements Exception {
  network('Revisa tu conexión y reintenta.'),
  session('Se requiere una sesión vigente.'),
  denied('No tienes permiso para esta operación.'),
  missing('El registro no está disponible.'),
  duplicate('El registro ya existe.'),
  invalid('Los datos no son válidos.'),
  conflict('La operación no es válida en el estado actual.'),
  server('No se pudo completar la operación.');

  const ServicesFailure(this.message);
  final String message;
  static ServicesFailure from(Object e) {
    if (e is ServicesFailure) return e;
    if (e is TimeoutException ||
        e is AuthRetryableFetchException ||
        [
          'ClientException',
          '_ClientSocketException',
          'SocketException',
        ].contains(e.runtimeType.toString())) {
      return network;
    }
    if (e is PostgrestException) {
      return switch (e.code) {
        '42501' => denied,
        '23505' => duplicate,
        '23503' || 'PGRST116' => missing,
        '23502' || '23514' || '22P02' => invalid,
        'PGRST301' || 'PGRST303' => session,
        'P0001' => switch (e.message) {
          'No autorizado' => denied,
          'La solicitud no existe' => missing,
          _ => conflict,
        },
        _ => server,
      };
    }
    if (e is FormatException || e is ArgumentError || e is TypeError) {
      return invalid;
    }
    return server;
  }
}

abstract class ServiceAccess {
  ServiceAccess(this.client);
  final SupabaseClient client;
  String get uid =>
      client.auth.currentUser?.id ?? (throw ServicesFailure.session);
  Future<T> run<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(const Duration(seconds: 20));
    } catch (e) {
      throw ServicesFailure.from(e);
    }
  }

  List<T> rows<T>(Object? data, T Function(JsonRow) parse) =>
      List.unmodifiable((data as List).map((r) => parse(r as JsonRow)));
}

class ServicesRepository extends ServiceAccess {
  ServicesRepository(super.client);
  RecommendationsRepository get recommendations =>
      RecommendationsRepository(client);
  Future<String?> zoneName(String id) => run(() async {
    final row = await client
        .from('zonas')
        .select('nombre')
        .eq('id', serviceUuid(id))
        .maybeSingle();
    return row?['nombre'] as String?;
  });
  static const fields =
      'id,proveedor_id,categoria_id,titulo,descripcion,anios_experiencia,zona_id,activo,creado_en';
  static const pageSize = 25;
  Future<List<DirectoryEntry>> page({
    String query = '',
    int? categoryId,
    int offset = 0,
  }) => run(() async {
    var request = client
        .from('servicios')
        .select('$fields,recomendaciones(count)')
        .eq('activo', true);
    if (categoryId != null) request = request.eq('categoria_id', categoryId);
    if (query.isNotEmpty) {
      request = request.textSearch(
        'titulo',
        query,
        config: 'spanish',
        type: TextSearchType.plain,
      );
    }
    return rows(
      await request
          .order('titulo')
          .order('id')
          .range(offset, offset + pageSize),
      DirectoryEntry.fromJson,
    );
  });
  Future<List<ServiceCategoryRow>> categories() => run(
    () async => rows(
      await client
          .from('categorias_servicio')
          .select('id,nombre,icono')
          .order('nombre'),
      ServiceCategoryRow.fromJson,
    ),
  );
  // La política servicios_lectura restringe las filas a mi_zona().
  Future<List<ServiceRow>> directory({int? categoryId}) => run(() async {
    var q = client.from('servicios').select(fields).eq('activo', true);
    if (categoryId != null) q = q.eq('categoria_id', categoryId);
    return rows(await q.order('titulo').order('id'), ServiceRow.fromJson);
  });
  Future<List<NearbyService>> nearby(
    double lat,
    double lng, {
    int radius = 3000,
    String? query,
    double minimum = 0,
    String? category,
  }) => run(() async {
    if (!lat.isFinite ||
        lat.abs() > 90 ||
        !lng.isFinite ||
        lng.abs() > 180 ||
        radius <= 0 ||
        !minimum.isFinite ||
        minimum < 0 ||
        minimum > 5) {
      throw ServicesFailure.invalid;
    }
    final results = rows(
      await client.rpc(
        'buscar_servicios_cercanos',
        params: {
          'p_lat': lat,
          'p_lng': lng,
          'p_radio_m': radius,
          'p_texto': query,
          'p_min_estrellas': minimum,
        },
      ),
      NearbyService.fromJson,
    );
    return results
        .where((s) => category == null || s.categoria == category)
        .toList();
  });
  Future<ServiceRow> detail(String id) => run(
    () async => ServiceRow.fromJson(
      await client
          .from('servicios')
          .select(fields)
          .eq('id', serviceUuid(id))
          .single(),
    ),
  );
  Future<PublicProvider?> provider(String id) => run(() async {
    final row = await client
        .rpc('perfiles_publicos_de_mi_zona')
        .eq('id', serviceUuid(id))
        .maybeSingle();
    return row == null ? null : PublicProvider.fromJson(row);
  });
  Future<ServiceContact?> contact(String id) => run(() async {
    final row = await client
        .from('servicio_contacto')
        .select('servicio_id,telefono,autorizado')
        .eq('servicio_id', serviceUuid(id))
        .eq('autorizado', true)
        .maybeSingle();
    return row == null ? null : ServiceContact.fromJson(row);
  });
  Future<List<ServiceWork>> works(String id) => run(
    () async => rows(
      await client
          .from('servicio_trabajos')
          .select('id,servicio_id,titulo,creado_en')
          .eq('servicio_id', serviceUuid(id))
          .order('creado_en'),
      ServiceWork.fromJson,
    ),
  );
  Future<ServiceRow> publish({
    required String id,
    required int categoryId,
    required String title,
    String? description,
    int? years,
  }) => run(() async {
    final owner = uid;
    final zone = await client.rpc('mi_zona');
    return ServiceRow.fromJson(
      await client
          .from('servicios')
          .insert({
            'id': serviceUuid(id),
            'proveedor_id': owner,
            'zona_id': serviceUuid(zone),
            'categoria_id': categoryId,
            'titulo': title.trim(),
            'descripcion': description,
            'anios_experiencia': years,
          })
          .select(fields)
          .single(),
    );
  });
  Future<ServiceRow> update(
    String id, {
    required String title,
    String? description,
    int? years,
    required bool active,
  }) => run(
    () async => ServiceRow.fromJson(
      await client
          .from('servicios')
          .update({
            'titulo': title.trim(),
            'descripcion': description,
            'anios_experiencia': years,
            'activo': active,
          })
          .eq('id', serviceUuid(id))
          .select(fields)
          .single(),
    ),
  );
}

class RequestsRepository extends ServiceAccess {
  RequestsRepository(super.client);
  Future<ServiceRequest> create(
    String id,
    String serviceId, {
    String? message,
  }) => run(
    () async => ServiceRequest.fromJson(
      await client
          .from('solicitudes_servicio')
          .insert({
            'id': serviceUuid(id),
            'servicio_id': serviceUuid(serviceId),
            'solicitante_id': uid,
            'mensaje': message,
          })
          .select()
          .single(),
    ),
  );
  Future<List<SentRequest>> sent() => run(
    () async => rows(
      await client.rpc('mis_solicitudes_enviadas'),
      SentRequest.fromJson,
    ),
  );
  Future<List<ReceivedRequest>> received() => run(
    () async => rows(
      await client.rpc('mis_solicitudes_recibidas'),
      ReceivedRequest.fromJson,
    ),
  );
  Future<ServiceRequest> transition(String id, RequestStatus status) =>
      run(() async {
        await client.rpc(
          'actualizar_solicitud_servicio',
          params: {'p_solicitud': serviceUuid(id), 'p_estado': status.name},
        );
        return ServiceRequest.fromJson(
          await client
              .from('solicitudes_servicio')
              .select()
              .eq('id', id)
              .single(),
        );
      });
}

class RecommendationsRepository extends ServiceAccess {
  RecommendationsRepository(super.client);
  Future<({int count, double? average, bool approved})> statistics(String id) =>
      run(() async {
        var count = 0;
        var sum = 0;
        var pageLength = 500;
        for (var offset = 0; ; offset += pageLength) {
          final page = await client
              .from('recomendaciones')
              .select('id,puntaje')
              .eq('servicio_id', serviceUuid(id))
              .order('id')
              .range(offset, offset + 499);
          for (final row in page) {
            sum += row['puntaje'] as int;
            count++;
          }
          pageLength = page.length;
          if (page.isEmpty) break;
        }
        final average = count == 0 ? null : sum / count;
        final approved = await client.rpc(
          'tiene_visto_bueno',
          params: {'n': count, 'promedio': average},
        );
        return (count: count, average: average, approved: approved as bool);
      });
  Future<List<ServiceReview>> reviews(String serviceId) => run(() async {
    final result = <ServiceReview>[];
    var pageLength = 500;
    for (var offset = 0; ; offset += pageLength) {
      final page = rows(
        await client
            .rpc(
              'resenas_de_servicio',
              params: {'p_servicio': serviceUuid(serviceId)},
            )
            .order('id')
            .range(offset, offset + 499),
        ServiceReview.fromJson,
      );
      result.addAll(page);
      pageLength = page.length;
      if (page.isEmpty) return List.unmodifiable(result);
    }
  });
  Future<String> recommend(
    String id,
    String serviceId,
    int stars, {
    String? comment,
  }) => run(() async {
    if (stars < 1 || stars > 5) throw ServicesFailure.invalid;
    final row = await client
        .from('recomendaciones')
        .insert({
          'id': serviceUuid(id),
          'servicio_id': serviceUuid(serviceId),
          'autor_id': uid,
          'puntaje': stars,
          'comentario': comment,
        })
        .select('id')
        .single();
    return serviceUuid(row['id']);
  });
}
