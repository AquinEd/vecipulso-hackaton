import 'package:flutter/material.dart';

import '../../models/map_point.dart';

String pointLayerLabel(MapPointLayer layer) => switch (layer) {
  MapPointLayer.comercio => 'Servicio comunitario',
  MapPointLayer.recurso => 'Recurso crítico',
  MapPointLayer.alerta => 'Alerta SOS',
  MapPointLayer.brigada => 'Grupo de apoyo',
};
IconData pointIcon(MapPointLayer layer) => switch (layer) {
  MapPointLayer.comercio => Icons.storefront,
  MapPointLayer.recurso => Icons.inventory_2_outlined,
  MapPointLayer.alerta => Icons.warning_rounded,
  MapPointLayer.brigada => Icons.groups,
};
Color pointColor(MapPointLayer layer) => switch (layer) {
  MapPointLayer.comercio => const Color(0xff2465a8),
  MapPointLayer.recurso => const Color(0xff08855e),
  MapPointLayer.alerta => const Color(0xffba2835),
  MapPointLayer.brigada => const Color(0xff087f96),
};
