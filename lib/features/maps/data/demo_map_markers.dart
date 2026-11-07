import '../../services/data/demo_services.dart';
import '../../services/models/service_preview.dart';
import '../models/community_map_marker.dart';

CommunityMapMarker _shop(ServicePreview service, double x, double y) =>
    CommunityMapMarker(
      id: service.id,
      title: service.serviceName,
      description: service.description,
      category: MapCategory.shop,
      relativeX: x,
      relativeY: y,
      serviceId: service.id,
    );

final demoMapMarkers = List<CommunityMapMarker>.unmodifiable([
  const CommunityMapMarker(
    id: 'herramientas',
    title: 'Herramientas comunitarias',
    description: 'Herramientas disponibles para préstamo vecinal.',
    category: MapCategory.resource,
    relativeX: .15,
    relativeY: .18,
  ),
  _shop(plumbing, .70, .21),
  _shop(carpentry, .39, .40),
  const CommunityMapMarker(
    id: 'apoyo',
    title: 'Punto de apoyo comunitario',
    description:
        'Ejemplo de un punto de distribución de víveres entre vecinos.',
    category: MapCategory.aid,
    relativeX: .82,
    relativeY: .53,
  ),
  const CommunityMapMarker(
    id: 'brigada',
    title: 'Brigada vecinal de ejemplo',
    description:
        'Grupo ilustrativo de vecinos que organiza jornadas de apoyo barrial.',
    category: MapCategory.brigade,
    relativeX: .23,
    relativeY: .73,
  ),
  const CommunityMapMarker(
    id: 'ropa',
    title: 'Donación de ropa',
    description: 'Prendas de abrigo para compartir con familias del barrio.',
    category: MapCategory.resource,
    relativeX: .66,
    relativeY: .84,
  ),
]);
