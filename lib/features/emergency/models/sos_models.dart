// PostgreSQL enum literals are preserved for lossless RPC serialization.
// ignore_for_file: constant_identifier_names
import 'dart:typed_data';

typedef SosJson = Map<String, dynamic>;
String sosUuid(Object? value) {
  if (value is! String ||
      !RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')
          .hasMatch(value)) {
    throw const FormatException('UUID inválido');
  }
  return value;
}

class SosPoint {
  SosPoint(this.lat, this.lng) {
    if (!lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180) {
      throw const FormatException('Coordenadas inválidas');
    }
  }
  final double lat, lng;
  Map<String, Object> toJson() => {
    'type': 'Point',
    'coordinates': [lng, lat],
  };
  factory SosPoint.parse(Object value) {
    if (value is Map && value['type'] == 'Point') {
      final c = value['coordinates'] as List;
      if (c.length != 2) throw const FormatException('Punto inválido');
      return SosPoint((c[1] as num).toDouble(), (c[0] as num).toDouble());
    }
    if (value is String) {
      final wkt = RegExp(
        r'^(?:SRID=4326;)?POINT\s*\(([-+0-9.eE]+)\s+([-+0-9.eE]+)\)$',
      ).firstMatch(value);
      if (wkt != null) {
        return SosPoint(double.parse(wkt[2]!), double.parse(wkt[1]!));
      }
      final hex = value.startsWith(r'\x') ? value.substring(2) : value;
      if (!RegExp(r'^[a-fA-F0-9]+$').hasMatch(hex) ||
          ![42, 50].contains(hex.length)) {
        throw const FormatException('Formato geográfico desconocido');
      }
      final bytes = Uint8List.fromList([
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ]);
      if (bytes[0] > 1) throw const FormatException('Orden de bytes inválido');
      final data = ByteData.sublistView(bytes),
          endian = bytes[0] == 1 ? Endian.little : Endian.big;
      final type = data.getUint32(1, endian);
      final srid = (type & 0x20000000) != 0;
      if ((type & 0xdfffffff) != 1 || bytes.length != (srid ? 25 : 21)) {
        throw const FormatException('Tipo geográfico inválido');
      }
      if (srid && data.getUint32(5, endian) != 4326) {
        throw const FormatException('SRID inválido');
      }
      final offset = srid ? 9 : 5;
      return SosPoint(
        data.getFloat64(offset + 8, endian),
        data.getFloat64(offset, endian),
      );
    }
    throw const FormatException('Punto inválido');
  }
}

enum AlertClass { alerta, soporte }

enum EmergencyType {
  sismo,
  incendio,
  seguridad,
  salud,
  persona_atrapada,
  agua_alimentos,
  traslado_refugio,
  dano_vivienda,
  otro,
}

enum AlertUrgency { critica, urgente, normal }

enum AlertStatus {
  sin_verificar,
  verificada,
  atendida,
  falsa_alarma,
  sin_confirmar,
  cancelada,
}

enum HelpStatus { ofrecida, aceptada, en_camino, completada, cancelada }

enum ResourceType {
  agua,
  botiquin,
  herramientas,
  transporte,
  espacio_seguro,
  otro,
}

enum GroupType { brigada, voluntarios }

class SosAlert {
  SosAlert.fromJson(SosJson row)
    : id = sosUuid(row['id']),
      autorId = sosUuid(row['autor_id']),
      clase = AlertClass.values.byName(row['clase'] as String),
      tipo = EmergencyType.values.byName(row['tipo'] as String),
      urgencia = AlertUrgency.values.byName(row['urgencia'] as String),
      descripcion = row['descripcion'] == null
          ? null
          : row['descripcion'] as String,
      zonaId = sosUuid(row['zona_id']),
      ubicacionAprox = SosPoint.parse(row['ubicacion_aprox']!),
      estado = AlertStatus.values.byName(row['estado'] as String),
      creadoLocal = row['creado_local'] == null
          ? null
          : DateTime.parse(row['creado_local'] as String).toUtc(),
      creadoEn = DateTime.parse(row['creado_en'] as String).toUtc(),
      cerradoEn = row['cerrado_en'] == null
          ? null
          : DateTime.parse(row['cerrado_en'] as String).toUtc();
  final String id;
  final String autorId;
  final AlertClass clase;
  final EmergencyType tipo;
  final AlertUrgency urgencia;
  final String? descripcion;
  final String zonaId;
  final SosPoint ubicacionAprox;
  final AlertStatus estado;
  final DateTime? creadoLocal;
  final DateTime creadoEn;
  final DateTime? cerradoEn;
  SosJson toJson() => {
    'id': id,
    'autor_id': autorId,
    'clase': clase.name,
    'tipo': tipo.name,
    'urgencia': urgencia.name,
    'descripcion': descripcion,
    'zona_id': zonaId,
    'ubicacion_aprox': ubicacionAprox.toJson(),
    'estado': estado.name,
    'creado_local': creadoLocal?.toIso8601String(),
    'creado_en': creadoEn.toIso8601String(),
    'cerrado_en': cerradoEn?.toIso8601String(),
  };
}

class HelpResponse {
  HelpResponse.fromJson(SosJson row)
    : id = sosUuid(row['id']),
      alertaId = sosUuid(row['alerta_id']),
      voluntarioId = sosUuid(row['voluntario_id']),
      recursoId = row['recurso_id'] == null ? null : sosUuid(row['recurso_id']),
      estado = HelpStatus.values.byName(row['estado'] as String),
      mensaje = row['mensaje'] == null ? null : row['mensaje'] as String,
      ubicacionAprox = row['ubicacion_aprox'] == null
          ? null
          : SosPoint.parse(row['ubicacion_aprox']!),
      creadoEn = DateTime.parse(row['creado_en'] as String).toUtc(),
      actualizadoEn = DateTime.parse(row['actualizado_en'] as String).toUtc();
  final String id;
  final String alertaId;
  final String voluntarioId;
  final String? recursoId;
  final HelpStatus estado;
  final String? mensaje;
  final SosPoint? ubicacionAprox;
  final DateTime creadoEn;
  final DateTime actualizadoEn;
  SosJson toJson() => {
    'id': id,
    'alerta_id': alertaId,
    'voluntario_id': voluntarioId,
    'recurso_id': recursoId,
    'estado': estado.name,
    'mensaje': mensaje,
    'ubicacion_aprox': ubicacionAprox?.toJson(),
    'creado_en': creadoEn.toIso8601String(),
    'actualizado_en': actualizadoEn.toIso8601String(),
  };
}

class CriticalResource {
  CriticalResource.fromJson(SosJson row)
    : id = sosUuid(row['id']),
      zonaId = sosUuid(row['zona_id']),
      propietarioId = sosUuid(row['propietario_id']),
      tipo = ResourceType.values.byName(row['tipo'] as String),
      cantidad = row['cantidad'] as int,
      descripcion = row['descripcion'] == null
          ? null
          : row['descripcion'] as String,
      ubicacionAprox = row['ubicacion_aprox'] == null
          ? null
          : SosPoint.parse(row['ubicacion_aprox']!),
      disponible = row['disponible'] as bool,
      creadoLocal = row['creado_local'] == null
          ? null
          : DateTime.parse(row['creado_local'] as String).toUtc(),
      creadoEn = DateTime.parse(row['creado_en'] as String).toUtc();
  final String id;
  final String zonaId;
  final String propietarioId;
  final ResourceType tipo;
  final int cantidad;
  final String? descripcion;
  final SosPoint? ubicacionAprox;
  final bool disponible;
  final DateTime? creadoLocal;
  final DateTime creadoEn;
  SosJson toJson() => {
    'id': id,
    'zona_id': zonaId,
    'propietario_id': propietarioId,
    'tipo': tipo.name,
    'cantidad': cantidad,
    'descripcion': descripcion,
    'ubicacion_aprox': ubicacionAprox?.toJson(),
    'disponible': disponible,
    'creado_local': creadoLocal?.toIso8601String(),
    'creado_en': creadoEn.toIso8601String(),
  };
}

class SupportGroup {
  SupportGroup.fromJson(SosJson row)
    : id = sosUuid(row['id']),
      zonaId = sosUuid(row['zona_id']),
      nombre = row['nombre'] as String,
      tipo = GroupType.values.byName(row['tipo'] as String),
      especialidad = row['especialidad'] == null
          ? null
          : row['especialidad'] as String,
      sector = row['sector'] == null ? null : row['sector'] as String,
      integrantes = row['integrantes'] == null
          ? null
          : row['integrantes'] as int,
      contacto = row['contacto'] == null ? null : row['contacto'] as String,
      ubicacionAprox = row['ubicacion_aprox'] == null
          ? null
          : SosPoint.parse(row['ubicacion_aprox']!);
  final String id;
  final String zonaId;
  final String nombre;
  final GroupType tipo;
  final String? especialidad;
  final String? sector;
  final int? integrantes;
  final String? contacto;
  final SosPoint? ubicacionAprox;
  SosJson toJson() => {
    'id': id,
    'zona_id': zonaId,
    'nombre': nombre,
    'tipo': tipo.name,
    'especialidad': especialidad,
    'sector': sector,
    'integrantes': integrantes,
    'contacto': contacto,
    'ubicacion_aprox': ubicacionAprox?.toJson(),
  };
}

class NearbyAlert {
  NearbyAlert.fromJson(SosJson row)
    : id = sosUuid(row['id']),
      clase = AlertClass.values.byName(row['clase'] as String),
      tipo = EmergencyType.values.byName(row['tipo'] as String),
      urgencia = AlertUrgency.values.byName(row['urgencia'] as String),
      estado = AlertStatus.values.byName(row['estado'] as String),
      descripcion = row['descripcion'] == null
          ? null
          : row['descripcion'] as String,
      verificada = row['verificada'] as bool,
      esMia = row['es_mia'] as bool,
      distanciaM = row['distancia_m'] as int,
      lat = (row['lat'] as num).toDouble(),
      lng = (row['lng'] as num).toDouble(),
      creadoEn = DateTime.parse(row['creado_en'] as String).toUtc();
  final String id;
  final AlertClass clase;
  final EmergencyType tipo;
  final AlertUrgency urgencia;
  final AlertStatus estado;
  final String? descripcion;
  final bool verificada;
  final bool esMia;
  final int distanciaM;
  final double lat;
  final double lng;
  final DateTime creadoEn;
  SosJson toJson() => {
    'id': id,
    'clase': clase.name,
    'tipo': tipo.name,
    'urgencia': urgencia.name,
    'estado': estado.name,
    'descripcion': descripcion,
    'verificada': verificada,
    'es_mia': esMia,
    'distancia_m': distanciaM,
    'lat': lat,
    'lng': lng,
    'creado_en': creadoEn.toIso8601String(),
  };
}

class SosSummary {
  SosSummary.fromJson(SosJson row)
    : zona = row['zona'] as String,
      enRiesgo = row['en_riesgo'] as bool,
      reportesActivos = row['reportes_activos'] as int,
      actualizadoEn = DateTime.parse(row['actualizado_en'] as String).toUtc();
  final String zona;
  final bool enRiesgo;
  final int reportesActivos;
  final DateTime actualizadoEn;
  SosJson toJson() => {
    'zona': zona,
    'en_riesgo': enRiesgo,
    'reportes_activos': reportesActivos,
    'actualizado_en': actualizadoEn.toIso8601String(),
  };
}
