import 'dart:typed_data';

class GeoCoordinate {
  GeoCoordinate(this.latitude, this.longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Coordenada no válida');
    }
  }
  final double latitude, longitude;

  factory GeoCoordinate.fromGeography(Object? value) {
    if (value is! String ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value) ||
        (value.length != 42 && value.length != 50)) {
      throw const FormatException('Se requiere un Point WKB/EWKB 2D');
    }
    final bytes = Uint8List.fromList([
      for (var i = 0; i < value.length; i += 2)
        int.parse(value.substring(i, i + 2), radix: 16),
    ]);
    if (bytes.first != 0 && bytes.first != 1) throw const FormatException();
    final order = bytes.first == 1 ? Endian.little : Endian.big;
    final data = ByteData.sublistView(bytes);
    final type = data.getUint32(1, order);
    final srid = type == 0x20000001;
    if (type != 1 && !srid || bytes.length != (srid ? 25 : 21)) {
      throw const FormatException();
    }
    if (srid && data.getUint32(5, order) != 4326) throw const FormatException();
    final offset = srid ? 9 : 5;
    return GeoCoordinate(
      data.getFloat64(offset + 8, order),
      data.getFloat64(offset, order),
    );
  }
}

class MapOrigin {
  const MapOrigin(
    this.coordinate,
    this.label, {
    this.zoom = 14,
    this.isNeutral = false,
  });
  final GeoCoordinate coordinate;
  final String label;
  final double zoom;
  final bool isNeutral;
  static MapOrigin get neutral => MapOrigin(
    GeoCoordinate(0, 0),
    'Vista general · no es tu ubicación',
    zoom: 2,
    isNeutral: true,
  );
}
