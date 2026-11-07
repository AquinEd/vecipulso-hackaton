# Próximas fases

El Dashboard de la referencia 02 está implementado con búsqueda local. Quedan pendientes los proveedores registrados, sus valoraciones y la ubicación autorizada. Las prioridades posteriores se definirán durante la hackathon.

| Área | Trabajo previsto |
|---|---|
| Identidad | Integrar Supabase para crear cuentas y perfiles, registrar el PIN de forma segura, validarlo en el servidor y recuperar el nombre. Implementar sesiones, autorización de rutas y backend, recuperación de credenciales y bloqueo temporal por intentos fallidos. |
| Servicios | Conectar Supabase, registrar proveedores reales, calcular distancias con GPS autorizado, habilitar contacto y solicitudes. Incorporar reseñas auténticas, moderación y verificación comunitaria. El directorio, los filtros y los perfiles actuales usan datos ilustrativos. |
| Solidaridad y publicaciones | Necesidades, ofrecimientos, donaciones, intercambios y préstamos. Crear, confirmar y ampliar publicaciones. |
| Mapa | Solicitar ubicación al usar el mapa, manejar denegación y mostrar marcadores y filtros. |
| SOS | Reportes, solicitudes críticas, recursos, brigadas y seguimiento de ayuda. |
| Offline | Almacenamiento local y cola con reintentos e idempotencia. |
| Accesibilidad | Tutorial, textos grandes, alto contraste y navegación sencilla. |
| Cuenta | Perfil propio, preferencias y notificaciones. |

## Chat

Se prevén Flutter, Supabase, PostgreSQL y Supabase Realtime. El listado de conversaciones y el chat individual usarán modelos Conversation y Message, identificación de participantes y repositorios de conversaciones y mensajes. Implementar envío, recepción y estados de mensaje. Aplicar RLS por participante, suscribirse a cambios al abrir la conversación y cancelar la suscripción al salir. Al reconectar, reconciliar cambios y reintentar mensajes no enviados evitando duplicados.

## Componentes previstos

AppSearchBar para búsqueda. LocationChip, RatingStars, ServiceCard, SolidarityCard y EmergencyCard para los listados. SOSButton, OfflineBanner y StatusBadge para acciones y estados. MessageBubble y ChatInput para conversaciones.
