import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/map_origin.dart';

enum LocationFailure implements Exception {
  denied('Permiso denegado. Puedes continuar usando el mapa sin ubicación.'),
  permanentlyDenied(
    'Permiso bloqueado. Habilítalo en Ajustes si deseas usar tu ubicación.',
  ),
  disabled(
    'La ubicación del dispositivo está desactivada. Puedes seguir usando el mapa.',
  ),
  timeout('La lectura tardó demasiado. Puedes reintentar cuando lo necesites.'),
  unavailable(
    'No se pudo obtener una posición. Comprueba la señal o conexión y reintenta.',
  ),
  session('La sesión cambió. Vuelve a solicitar tu ubicación.'),
  cancelled('Lectura descartada.');

  const LocationFailure(this.message);
  final String message;
}

enum PositionPrecision { approximate, precise, unknown }

class DeviceLocation {
  DeviceLocation({
    required this.coordinate,
    required this.precision,
    required this.accuracyMeters,
    required this.measuredAt,
  }) {
    if (accuracyMeters != null &&
        (!accuracyMeters!.isFinite || accuracyMeters! < 0)) {
      throw const FormatException();
    }
  }
  final GeoCoordinate coordinate;
  final PositionPrecision precision;
  final double? accuracyMeters;
  final DateTime measuredAt;
  String get accuracyLabel => accuracyMeters == null
      ? 'Precisión estimada no disponible'
      : 'Precisión estimada: ${accuracyMeters!.round()} m';
  String get label => switch (precision) {
    PositionPrecision.approximate =>
      'Tu ubicación aproximada · lectura puntual',
    PositionPrecision.precise =>
      'Tu ubicación con permiso preciso · lectura puntual',
    PositionPrecision.unknown =>
      'Tu ubicación · precisión no determinada · lectura puntual',
  };
}

abstract interface class LocationService {
  Future<DeviceLocation> locate({required bool Function() isActive});
}

class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({GeolocatorPlatform? platform})
    : platform = platform ?? GeolocatorPlatform.instance;
  final GeolocatorPlatform platform;
  static const readingLimit = Duration(seconds: 20);

  @override
  Future<DeviceLocation> locate({required bool Function() isActive}) async {
    void checkActive() {
      if (!isActive()) throw LocationFailure.cancelled;
    }

    try {
      checkActive();
      final enabled = await platform.isLocationServiceEnabled().timeout(
        const Duration(seconds: 10),
      );
      checkActive();
      if (!enabled) throw LocationFailure.disabled;
      var permission = await platform.checkPermission().timeout(
        const Duration(seconds: 10),
      );
      checkActive();
      if (permission == LocationPermission.denied) {
        permission = await platform.requestPermission();
        checkActive();
      }
      if (permission == LocationPermission.deniedForever) {
        throw LocationFailure.permanentlyDenied;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw LocationFailure.denied;
      }
      // One foreground fix, no stream, foreground service or history.
      final position = await platform
          .getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: readingLimit,
            ),
          )
          .timeout(const Duration(seconds: 22));
      checkActive();
      var precision = PositionPrecision.unknown;
      try {
        final accuracy = await platform.getLocationAccuracy().timeout(
          const Duration(seconds: 5),
        );
        precision = switch (accuracy) {
          LocationAccuracyStatus.reduced => PositionPrecision.approximate,
          LocationAccuracyStatus.precise => PositionPrecision.precise,
          _ => PositionPrecision.unknown,
        };
      } on UnsupportedError {
        // A platform without this signal must not imply precise permission.
      } on TimeoutException {
        // Keep precision unknown if the supplementary query times out.
      }
      checkActive();
      return DeviceLocation(
        coordinate: GeoCoordinate(position.latitude, position.longitude),
        precision: precision,
        accuracyMeters: position.hasAccuracy ? position.accuracy : null,
        measuredAt: position.timestamp.toUtc(),
      );
    } on LocationFailure {
      rethrow;
    } on TimeoutException {
      throw LocationFailure.timeout;
    } on LocationServiceDisabledException {
      throw LocationFailure.disabled;
    } on PermissionDeniedException {
      throw LocationFailure.denied;
    } catch (_) {
      throw LocationFailure.unavailable;
    }
  }
}
