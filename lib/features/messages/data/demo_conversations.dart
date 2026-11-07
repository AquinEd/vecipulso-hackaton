import '../../services/utils/provider_display_name.dart';
import '../../../core/utils/normalize_search.dart';

class DemoConversation {
  const DemoConversation(
    this.id,
    this.firstName,
    this.surname,
    this.topic,
    this.question,
    this.reply,
    this.time,
  );
  final String id, firstName, surname, topic, question, reply, time;
  String get publicName => formatProviderDisplayName(firstName, surname);
  bool matches(String query) =>
      normalizeSearch('$publicName $topic $question $reply')
          .contains(normalizeSearch(query));
}

const demoConversations = [
  DemoConversation(
    'ayuda',
    'Inés',
    'Pradera',
    'Ayuda comunitaria',
    '¿Qué podemos preparar para el taller?',
    'Podemos llevar papel y colores.',
    '09:15',
  ),
  DemoConversation(
    'carpinteria',
    'Leo',
    'Vega',
    'Carpintería',
    '¿Se puede reparar una repisa?',
    'Sí, podemos revisar la madera en el taller.',
    '10:30',
  ),
  DemoConversation(
    'intercambio',
    'Alba',
    'Sol',
    'Intercambio',
    '¿Intercambiamos libros de cuentos?',
    'Tengo un libro de aventuras para el intercambio.',
    '11:20',
  ),
  DemoConversation(
    'servicio',
    'Noé',
    'Rivera',
    'Servicio local',
    '¿Qué incluye el taller de costura?',
    'Practicamos cómo colocar un botón.',
    '15:45',
  ),
];
