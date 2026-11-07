import 'dart:ui';

import '../models/emergency_map_marker.dart';
import 'demo_brigades.dart';
import 'demo_emergency_reports.dart';

final demoEmergencyMapMarkers = List<EmergencyMapMarker>.unmodifiable([
  for (final (id, position) in const [
    ('demo-sos-rescate', Offset(.16, .16)),
    ('demo-sos-agua', Offset(.25, .61)),
    ('demo-sos-vivienda', Offset(.66, .25)),
  ])
    EmergencyMapMarker.report(
      demoEmergencyReports.firstWhere((r) => r.id == id),
      position,
    ),
  for (final (id, position) in const [
    ('demo-alamos', Offset(.76, .47)),
    ('demo-salud', Offset(.34, .85)),
  ])
    EmergencyMapMarker.brigade(
      demoBrigades.firstWhere((b) => b.id == id),
      position,
    ),
  const EmergencyMapMarker.resource(
    'demo-refugio',
    'Refugio de ejemplo',
    'Espacio ficticio de resguardo temporal.',
    Offset(.58, .72),
  ),
]);
