import '../../solidarity/models/solidarity_post.dart';

class PublicationTemplate {
  const PublicationTemplate(this.label, this.hint, this.title, this.detail);
  final String label, hint, title, detail;
}

const publicationTemplates = {
  PostType.need: PublicationTemplate(
    'Necesito ayuda',
    'Pedir un servicio, recurso o apoyo',
    'Ayuda para una mudanza',
    'Busco apoyo para trasladar unas cajas y muebles',
  ),
  PostType.offer: PublicationTemplate(
    'Ofrezco ayuda',
    'Compartir mis habilidades o recursos',
    'Ofrezco herramientas para reparaciones',
    'Puedo prestar herramientas durante el fin de semana',
  ),
  PostType.donation: PublicationTemplate(
    'Donación',
    'Entregar productos o materiales',
    'Donación de ropa abrigadora',
    'Tengo prendas en buen estado para donar',
  ),
  PostType.exchange: PublicationTemplate(
    'Intercambio',
    'Cambiar servicios o artículos',
    'Intercambio clases por ayuda con plantas',
    'Ofrezco clases de inglés a cambio de ayuda con mis plantas',
  ),
};
