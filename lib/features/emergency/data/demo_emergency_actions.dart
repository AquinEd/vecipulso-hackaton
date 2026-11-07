import '../models/emergency_action_option.dart';
import '../models/emergency_action_type.dart';

const emergencyDemoLocation = 'Ubicación de ejemplo: Barrio Los Álamos';
const emergencyDemoNotice = 'DEMOSTRACIÓN — Ninguna acción se enviará';

const demoEmergencyActions = [
  EmergencyActionDefinition(
    type: EmergencyActionType.neighborAlert,
    title: 'Emitir alerta vecinal',
    description: 'Sismo, incendio, seguridad o salud',
    selectorTitle: 'Tipo de alerta',
    summaryLabel: 'Tipo',
    notice: 'Esta alerta no ha sido registrada ni enviada a otros vecinos',
    options: [
      EmergencyActionOption(
        EmergencyActionCategory.earthquake,
        'Sismo',
        'Movimiento sísmico en el barrio.',
      ),
      EmergencyActionOption(
        EmergencyActionCategory.fire,
        'Incendio',
        'Humo o fuego en la comunidad.',
      ),
      EmergencyActionOption(
        EmergencyActionCategory.security,
        'Seguridad',
        'Situación de riesgo para los vecinos.',
      ),
      EmergencyActionOption(
        EmergencyActionCategory.health,
        'Salud',
        'Situación de salud que requiere atención.',
      ),
    ],
  ),
  EmergencyActionDefinition(
    type: EmergencyActionType.criticalSupport,
    title: 'Solicitar soporte crítico',
    description: 'Persona atrapada, medicina, agua o traslado',
    selectorTitle: 'Tipo de necesidad',
    summaryLabel: 'Tipo de necesidad',
    notice: 'La solicitud es una demostración. Todavía no se ha contactado a ningún vecino',
    options: [
      EmergencyActionOption(
        EmergencyActionCategory.trappedPerson,
        'Persona atrapada',
        'Apoyo ante dificultades para salir de un lugar.',
      ),
      EmergencyActionOption(
        EmergencyActionCategory.medicalHelp,
        'Ayuda médica',
        'Necesidad de atención o medicinas.',
      ),
      EmergencyActionOption(
        EmergencyActionCategory.foodAndWater,
        'Agua o alimentos',
        'Necesidad de suministros básicos.',
      ),
      EmergencyActionOption(
        EmergencyActionCategory.transportOrShelter,
        'Transporte o refugio',
        'Necesidad de traslado o un espacio seguro.',
      ),
    ],
  ),
  EmergencyActionDefinition(
    type: EmergencyActionType.offerResources,
    title: 'Ofrecer ayuda o recursos',
    description: 'Agua, botiquín, herramientas o refugio',
    selectorTitle: 'Tipo de recurso',
    summaryLabel: 'Tipo de recurso',
    notice: 'El ofrecimiento todavía no está disponible para otros vecinos',
    options: [
      EmergencyActionOption(
        EmergencyActionCategory.water,
        'Agua',
        'Agua para compartir con la comunidad.',
      ),
      EmergencyActionOption(
        EmergencyActionCategory.firstAid,
        'Botiquín',
        'Material básico de primeros auxilios.',
      ),
      EmergencyActionOption(
        EmergencyActionCategory.tools,
        'Herramientas',
        'Herramientas de apoyo para el barrio.',
      ),
      EmergencyActionOption(
        EmergencyActionCategory.transport,
        'Transporte',
        'Un medio de traslado disponible.',
      ),
      EmergencyActionOption(
        EmergencyActionCategory.shelter,
        'Espacio seguro o refugio',
        'Un lugar de resguardo temporal.',
      ),
    ],
  ),
];
