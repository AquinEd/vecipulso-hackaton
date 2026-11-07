import '../models/service_preview.dart';

const plumbing = ServicePreview(
  id: 'demo-gasfiteria',
  serviceName: 'Gasfitería del Barrio',
  providerFirstName: 'Carlos',
  providerPaternalSurname: 'Luna',
  description: 'Instalaciones y reparaciones.',
  category: ServiceCategory.plumbing,
  rating: 4.8,
  distanceMeters: 220,
  hasNeighborhoodApproval: true,
);
const carpentry = ServicePreview(
  id: 'demo-carpinteria',
  serviceName: 'Carpintería Vecinal',
  providerFirstName: 'José',
  providerPaternalSurname: 'Ramírez',
  occupation: 'Carpintero del barrio',
  summary: 'Muebles y arreglos.',
  description: 'Muebles a medida, reparación y restauración de trabajos en madera. Atención cercana y recomendada.',
  category: ServiceCategory.carpentry,
  rating: 4.7,
  distanceMeters: 420,
  hasNeighborhoodApproval: true,
  reviewCount: 98,
  yearsExperience: 10,
  completedWorks: ['Repisas de madera', 'Muebles a medida', 'Puertas y marcos'],
  reviews: [
    (
      author: 'Carolina R.',
      comment: 'Muy buen trabajo y puntualidad.',
      stars: 5,
    ),
    (author: 'Luis A.', comment: 'Me ayudó con una puerta.', stars: 5),
  ],
);
const tutoring = ServicePreview(
  id: 'demo-matematicas',
  serviceName: 'Clases con Ana',
  providerFirstName: 'Ana',
  providerPaternalSurname: 'López',
  description: 'Tutoría particular de matemáticas.',
  category: ServiceCategory.education,
  rating: 4.9,
  distanceMeters: 500,
  hasNeighborhoodApproval: true,
);
const demoServices = [
  plumbing,
  ServicePreview(
    id: 'demo-electricidad',
    serviceName: 'Electricista Rápido',
    providerFirstName: 'María',
    providerPaternalSurname: 'Fernández',
    description: 'Revisión de circuitos e instalaciones eléctricas.',
    category: ServiceCategory.electricity,
    rating: 4.6,
    distanceMeters: 330,
    hasNeighborhoodApproval: true,
  ),
  carpentry,
  tutoring,
  ServicePreview(
    id: 'demo-cerrajeria',
    serviceName: 'Cerrajería Cerca',
    providerFirstName: 'Pedro',
    providerPaternalSurname: 'Rojas',
    description: 'Apertura y cambio de cerraduras.',
    category: ServiceCategory.locksmith,
    rating: 4.8,
    distanceMeters: 650,
  ),
];
