import 'package:flutter_map/flutter_map.dart';

import '../models/map_origin.dart';
import 'map_origin_repository.dart';

/// Composition boundary. Tests can supply image providers without any HTTP.
class MapEnvironment {
  const MapEnvironment({this.createTiles, this.origins, this.sessionOrigin});
  final TileProvider Function()? createTiles;
  final MapOriginRepository? origins;

  /// Only an explicitly authorized position from the current session.
  final MapOrigin? sessionOrigin;

  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgent = 'VeciPulso/0.1 (community-map; Android)';
  factory MapEnvironment.openStreetMap({MapOriginRepository? origins}) =>
      MapEnvironment(
        origins: origins,
        createTiles: () => NetworkTileProvider(
          headers: {'User-Agent': userAgent},
          attemptDecodeOfHttpErrorResponses: false,
          cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
            maxCacheSize: 64 * 1024 * 1024,
          ),
        ),
      );
}
