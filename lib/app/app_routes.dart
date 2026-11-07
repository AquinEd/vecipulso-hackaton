enum AppRoute {
  home('/inicio', 'Inicio'),
  map('/mapa', 'Mapa'),
  publish('/publicar/tipo', 'Publicar'),
  messages('/mensajes', 'Mensajes'),
  profile('/perfil', 'Perfil'),
  services('/servicios', 'Servicios del Barrio'),
  provider('/servicios/:id', 'Perfil de proveedor'),
  solidarity('/favores', 'Cadena de Favores'),
  expanded('/favores/ampliado', 'Muro ampliado'),
  details('/publicar/detalles', 'Detalles de publicación'),
  success('/publicar/exito', 'Publicación preparada'),
  sos('/sos', 'Modo SOS'),
  brigades('/sos/brigadas', 'Brigadas'),
  help('/sos/confirmacion', 'Confirmación de ayuda'),
  actions('/sos/acciones', 'Acciones SOS'),
  riskMap('/sos/mapa', 'Mapa SOS'),
  tracking('/sos/seguimiento', 'Seguimiento de ayuda'),
  login('/auth/login', 'Ingreso con PIN'),
  register('/auth/registro', 'Registro'),
  pin('/auth/pin', 'Crear PIN'),
  tutorial('/tutorial', 'Tutorial'),
  pending('/offline/pendiente', 'Sincronización pendiente'),
  synced('/offline/sincronizado', 'Sincronización'),
  settings('/configuracion', 'Configuración'),
  access('/configuracion/accesibilidad', 'Accesibilidad'),
  review('/resenas/nueva', 'Nueva reseña'),
  chat('/mensajes/:id', 'Conversación'),
  notifications('/notificaciones', 'Notificaciones');

  const AppRoute(this.path, this.title);
  final String path, title;
}
