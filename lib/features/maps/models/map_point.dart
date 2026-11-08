import 'map_origin.dart';

enum MapPointLayer { comercio, recurso, alerta, brigada }

enum MapPointUrgency { critica, urgente, normal }

/// Exact projection of puntos_mapa, without profile/contact/zone fields.
class MapPoint {
  MapPoint.fromJson(Map<String, dynamic> row)
    : layer = MapPointLayer.values.byName(_text(row, 'capa')),
      id = _uuid(row['id']),
      title = _text(row, 'titulo'),
      subtype = _text(row, 'subtipo'),
      state = _text(row, 'estado'),
      urgency = row['urgencia'] == null
          ? null
          : MapPointUrgency.values.byName(_text(row, 'urgencia')),
      coordinate = GeoCoordinate(_number(row['lat']), _number(row['lng'])),
      distanceMeters = _distance(row['distancia_m']) {
    final allowed = switch (layer) {
      MapPointLayer.comercio || MapPointLayer.brigada => {'activo'},
      MapPointLayer.recurso => {'disponible'},
      MapPointLayer.alerta => {'sin_verificar', 'verificada'},
    };
    if (!allowed.contains(state) ||
        (layer == MapPointLayer.alerta) != (urgency != null)) {
      throw const FormatException('Respuesta de mapa incompatible');
    }
  }
  final MapPointLayer layer;
  final String id, title, subtype, state;
  final MapPointUrgency? urgency;
  final GeoCoordinate coordinate;
  final int distanceMeters;
  String get key => '${layer.name}:$id';
  Map<String, dynamic> toJson() => {
    'capa': layer.name,
    'id': id,
    'titulo': title,
    'subtipo': subtype,
    'estado': state,
    'urgencia': urgency?.name,
    'lat': coordinate.latitude,
    'lng': coordinate.longitude,
    'distancia_m': distanceMeters,
  };
  static String _text(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) throw const FormatException();
    return value;
  }

  static String _uuid(Object? value) {
    if (value is! String ||
        !RegExp(r'^[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$')
            .hasMatch(value)) {
      throw const FormatException('UUID inválido');
    }
    return value.toLowerCase();
  }

  static double _number(Object? value) {
    if (value is! num) throw const FormatException('Coordenada inválida');
    return value.toDouble();
  }

  static int _distance(Object? value) {
    if (value is! int || value < 0 || value > 2147483647) {
      throw const FormatException();
    }
    return value;
  }
}

class MapPointsResult {
  MapPointsResult(Iterable<MapPoint> points, {this.truncated = false})
    : points = List.unmodifiable(points);
  final List<MapPoint> points;

  /// Client-side metadata, not an RPC column.
  final bool truncated;
}
