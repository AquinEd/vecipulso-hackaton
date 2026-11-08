import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/map_origin.dart';
import '../models/map_point.dart';

enum MapPointsFailure implements Exception {
  offline(
    'No se pudieron consultar los puntos. Comprueba tu conexión y reintenta.',
  ),
  denied('Tu sesión no tiene acceso a esta consulta. Revisa tu acceso.'),
  invalid('La consulta o las coordenadas recibidas no son válidas.'),
  server('No se pudieron cargar los puntos. Inténtalo nuevamente.'),
  cancelled('Consulta descartada.');

  const MapPointsFailure(this.message);
  final String message;
  static MapPointsFailure from(Object error) {
    if (error is MapPointsFailure) return error;
    if (error is TimeoutException ||
        error is AuthRetryableFetchException ||
        RegExp('SocketException|ClientException|HandshakeException')
            .hasMatch(error.runtimeType.toString())) {
      return offline;
    }
    if (error is AuthException) return denied;
    if (error is FormatException ||
        error is ArgumentError ||
        error is TypeError) {
      return invalid;
    }
    if (error is PostgrestException) {
      if ({'42501', 'PGRST301', 'PGRST303'}.contains(error.code)) return denied;
      if ({'22P02', '22003', '22023'}.contains(error.code)) return invalid;
    }
    return server;
  }
}

abstract interface class MapPointsRepository {
  String? get userId;
  Future<MapPointsResult> load(
    GeoCoordinate origin, {
    int radiusMeters = 3000,
    bool Function()? isActive,
  });
}

class SupabaseMapPointsRepository implements MapPointsRepository {
  SupabaseMapPointsRepository(this.client);
  final SupabaseClient client;
  static const maxPoints = 500, pageSize = 100;
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  Future<MapPointsResult> load(
    GeoCoordinate origin, {
    int radiusMeters = 3000,
    bool Function()? isActive,
  }) async {
    final viewer = userId;
    void check() {
      if (viewer == null || userId != viewer) throw MapPointsFailure.denied;
      if (isActive != null && !isActive()) throw MapPointsFailure.cancelled;
    }

    try {
      check();
      if (radiusMeters <= 0 || radiusMeters > 2147483647) {
        throw MapPointsFailure.invalid;
      }
      final points = <String, MapPoint>{};
      var offset = 0;
      // One extra row detects a bounded result, without fetching an entire zone.
      while (offset <= maxPoints) {
        check();
        final end = (offset + pageSize - 1).clamp(0, maxPoints);
        final rows = await client
            .rpc(
              'puntos_mapa',
              params: {
                'p_lat': origin.latitude,
                'p_lng': origin.longitude,
                'p_radio_m': radiusMeters,
              },
            )
            .order('capa', ascending: true)
            .order('id', ascending: true)
            .range(offset, end)
            .timeout(const Duration(seconds: 15));
        check();
        if (rows is! List || rows.length > end - offset + 1) {
          throw MapPointsFailure.invalid;
        }
        if (rows.isEmpty) return MapPointsResult(points.values);
        for (final row in rows) {
          final point = MapPoint.fromJson(
            Map<String, dynamic>.from(row as Map),
          );
          if (offset < maxPoints) points[point.key] = point;
          offset++;
        }
        if (offset > maxPoints) {
          return MapPointsResult(points.values, truncated: true);
        }
      }
      return MapPointsResult(points.values);
    } catch (error) {
      throw MapPointsFailure.from(error);
    }
  }
}
