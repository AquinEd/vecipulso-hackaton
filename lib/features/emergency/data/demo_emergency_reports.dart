import '../models/emergency_report.dart';

const demoEmergencyReports = [
  EmergencyReport(
    id: 'demo-sos-rescate',
    title: 'Persona atrapada',
    description: 'Ejemplo de una solicitud comunitaria de ayuda durante una situación de emergencia.',
    category: EmergencyCategory.rescue,
    priority: EmergencyPriority.critical,
    distanceLabel: '120 m',
    isDemo: true,
  ),
  EmergencyReport(
    id: 'demo-sos-agua',
    title: 'Necesita agua',
    description: 'Ejemplo ficticio de una necesidad de agua para probar el tablero comunitario.',
    category: EmergencyCategory.resources,
    priority: EmergencyPriority.urgent,
    distanceLabel: '250 m',
    isDemo: true,
  ),
  EmergencyReport(
    id: 'demo-sos-vivienda',
    title: 'Daño en vivienda',
    description: 'Ejemplo ficticio de daños en una vivienda pendientes de revisión. No corresponde a una propiedad real.',
    category: EmergencyCategory.housing,
    priority: EmergencyPriority.underReview,
    distanceLabel: '400 m',
    isDemo: true,
  ),
  EmergencyReport(
    id: 'demo-sos-abrigo',
    title: 'Necesita abrigo',
    description:
        'Ejemplo ficticio de una necesidad de mantas y prendas de abrigo.',
    category: EmergencyCategory.resources,
    priority: EmergencyPriority.urgent,
    distanceLabel: '550 m',
    isDemo: true,
  ),
  EmergencyReport(
    id: 'demo-sos-techo',
    title: 'Revisión de techo',
    description: 'Ejemplo ficticio de una solicitud de revisión de techo para explorar la lista ampliada.',
    category: EmergencyCategory.housing,
    priority: EmergencyPriority.underReview,
    distanceLabel: '700 m',
    isDemo: true,
  ),
];
