import 'package:flutter/widgets.dart';

import '../../models/map_point.dart';

typedef MapPointOpener = Future<void> Function(
  BuildContext context,
  MapPoint point,
);

/// Register a callback only after the corresponding real UUID detail is merged.
/// No production callback targets the demo routes present in this checkout.
class MapPointNavigation {
  const MapPointNavigation({
    this.service,
    this.alert,
    this.resource,
    this.group,
  });
  final MapPointOpener? service, alert, resource, group;
  MapPointOpener? forLayer(MapPointLayer layer) => switch (layer) {
    MapPointLayer.comercio => service,
    MapPointLayer.alerta => alert,
    MapPointLayer.recurso => resource,
    MapPointLayer.brigada => group,
  };
}
