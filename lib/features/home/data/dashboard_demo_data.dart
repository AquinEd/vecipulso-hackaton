import 'package:hackaton_veci_pulso/features/services/models/service_preview.dart';

const dashboardDemoData = [
  ServicePreview(
    id: 'demo-gasfiteria',
    name: 'Gasfitería del Barrio',
    description: 'Instalaciones y reparaciones.',
    category: ServiceCategory.plumbing,
    rating: 4.8,
    distanceMeters: 320,
  ),
  ServicePreview(
    id: 'demo-carpinteria',
    name: 'Carpintería Vecinal',
    description: 'Muebles y arreglos.',
    category: ServiceCategory.carpentry,
    rating: 4.7,
    distanceMeters: 420,
  ),
  ServicePreview(
    id: 'demo-matematicas',
    name: 'Clases de Matemáticas',
    description: 'Tutoría particular.',
    category: ServiceCategory.education,
    rating: 4.9,
    distanceMeters: 500,
  ),
];
