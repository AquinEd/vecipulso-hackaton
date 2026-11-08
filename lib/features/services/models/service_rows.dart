typedef JsonRow = Map<String, dynamic>;

class DirectoryEntry {
  DirectoryEntry.fromJson(JsonRow row)
    : service = ServiceRow.fromJson(row),
      count = ((row['recomendaciones'] as List).single as Map)['count'] as int;
  final ServiceRow service;
  final int count;
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
);
String serviceUuid(Object? value) {
  if (value is String && _uuidPattern.hasMatch(value)) return value;
  throw const FormatException('UUID inválido');
}

enum RequestStatus { solicitada, contactado, completada, cancelada }

class ServiceCategoryRow {
  ServiceCategoryRow.fromJson(JsonRow row)
    : id = row['id'] as int,
      nombre = row['nombre'] as String,
      icono = row['icono'] as String?;
  final int id;
  final String nombre;
  final String? icono;
}

class ServiceRow {
  ServiceRow.fromJson(JsonRow row)
    : id = serviceUuid(row['id']),
      proveedorId = serviceUuid(row['proveedor_id']),
      categoriaId = row['categoria_id'] as int,
      titulo = row['titulo'] as String,
      descripcion = row['descripcion'] as String?,
      aniosExperiencia = row['anios_experiencia'] as int?,
      zonaId = serviceUuid(row['zona_id']),
      activo = row['activo'] as bool,
      creadoEn = DateTime.parse(row['creado_en'] as String).toUtc();
  final String id;
  final String proveedorId;
  final int categoriaId;
  final String titulo;
  final String? descripcion;
  final int? aniosExperiencia;
  final String zonaId;
  final bool activo;
  final DateTime creadoEn;
}

class PublicProvider {
  PublicProvider.fromJson(JsonRow row)
    : id = serviceUuid(row['id']),
      nombrePublico = row['nombre_publico'] as String,
      avatarUrl = row['avatar_url'] as String?,
      zonaId = serviceUuid(row['zona_id']),
      vecinoConfiable = row['vecino_confiable'] as bool;
  final String id;
  final String nombrePublico;
  final String? avatarUrl;
  final String zonaId;
  final bool vecinoConfiable;
}

class ServiceContact {
  ServiceContact.fromJson(JsonRow row)
    : servicioId = serviceUuid(row['servicio_id']),
      telefono = row['telefono'] as String,
      autorizado = row['autorizado'] as bool;
  final String servicioId;
  final String telefono;
  final bool autorizado;
}

class ServiceWork {
  ServiceWork.fromJson(JsonRow row)
    : id = serviceUuid(row['id']),
      servicioId = serviceUuid(row['servicio_id']),
      titulo = row['titulo'] as String,
      creadoEn = DateTime.parse(row['creado_en'] as String).toUtc();
  final String id;
  final String servicioId;
  final String titulo;
  final DateTime creadoEn;
}

class ServiceRequest {
  ServiceRequest.fromJson(JsonRow row)
    : id = serviceUuid(row['id']),
      servicioId = serviceUuid(row['servicio_id']),
      solicitanteId = serviceUuid(row['solicitante_id']),
      estado = RequestStatus.values.byName(row['estado'] as String),
      mensaje = row['mensaje'] as String?,
      creadoEn = DateTime.parse(row['creado_en'] as String).toUtc();
  final String id;
  final String servicioId;
  final String solicitanteId;
  final RequestStatus estado;
  final String? mensaje;
  final DateTime creadoEn;
}

class SentRequest {
  SentRequest.fromJson(JsonRow row)
    : id = serviceUuid(row['id']),
      servicioId = serviceUuid(row['servicio_id']),
      servicio = row['servicio'] as String,
      proveedor = row['proveedor'] as String,
      estado = RequestStatus.values.byName(row['estado'] as String),
      puedoRecomendar = row['puedo_recomendar'] as bool,
      creadoEn = DateTime.parse(row['creado_en'] as String).toUtc();
  final String id;
  final String servicioId;
  final String servicio;
  final String proveedor;
  final RequestStatus estado;
  final bool puedoRecomendar;
  final DateTime creadoEn;
}

class ReceivedRequest {
  ReceivedRequest.fromJson(JsonRow row)
    : id = serviceUuid(row['id']),
      servicioId = serviceUuid(row['servicio_id']),
      servicio = row['servicio'] as String,
      solicitante = row['solicitante'] as String,
      estado = RequestStatus.values.byName(row['estado'] as String),
      mensaje = row['mensaje'] as String?,
      creadoEn = DateTime.parse(row['creado_en'] as String).toUtc();
  final String id;
  final String servicioId;
  final String servicio;
  final String solicitante;
  final RequestStatus estado;
  final String? mensaje;
  final DateTime creadoEn;
}

class ServiceReview {
  ServiceReview.fromJson(JsonRow row)
    : id = serviceUuid(row['id']),
      autor = row['autor'] as String,
      puntaje = row['puntaje'] as int,
      comentario = row['comentario'] as String?,
      creadoEn = DateTime.parse(row['creado_en'] as String).toUtc();
  final String id;
  final String autor;
  final int puntaje;
  final String? comentario;
  final DateTime creadoEn;
}

class NearbyService {
  NearbyService.fromJson(JsonRow row)
    : id = serviceUuid(row['id']),
      titulo = row['titulo'] as String,
      categoria = row['categoria'] as String,
      descripcion = row['descripcion'] as String?,
      proveedor = row['proveedor'] as String,
      aniosExperiencia = row['anios_experiencia'] as int?,
      distanciaM = row['distancia_m'] as int,
      promedio = (row['promedio'] as num?)?.toDouble(),
      recomendaciones = row['recomendaciones'] as int,
      vistoBueno = row['visto_bueno'] as bool,
      lat = (row['lat'] as num).toDouble(),
      lng = (row['lng'] as num).toDouble() {
    if (!lat.isFinite || lat.abs() > 90 || !lng.isFinite || lng.abs() > 180) {
      throw const FormatException('Coordenadas inválidas');
    }
  }
  final String id;
  final String titulo;
  final String categoria;
  final String? descripcion;
  final String proveedor;
  final int? aniosExperiencia;
  final int distanciaM;
  final double? promedio;
  final int recomendaciones;
  final bool vistoBueno;
  final double lat;
  final double lng;
}
