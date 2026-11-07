# Próximas fases

El Dashboard de la referencia 02 está implementado con búsqueda local. Quedan pendientes los proveedores registrados, sus valoraciones y la ubicación autorizada. Las prioridades posteriores se definirán durante la hackathon.

| Área | Trabajo previsto |
|---|---|
| Identidad | DNI autodeclarado, nombre, creación de PIN de seis dígitos y teclado aleatorio en cada apertura del login. Se excluye el reconocimiento facial. |
| Servicios | Directorio, búsqueda, filtros, perfil del proveedor y reseñas. |
| Solidaridad y publicaciones | Necesidades, ofrecimientos, donaciones, intercambios y préstamos. Crear, confirmar y ampliar publicaciones. |
| Mapa | Solicitar ubicación al usar el mapa, manejar denegación y mostrar marcadores y filtros. |
| SOS | Reportes, solicitudes críticas, recursos, brigadas y seguimiento de ayuda. |
| Offline | Almacenamiento local y cola con reintentos e idempotencia. |
| Accesibilidad | Tutorial, textos grandes, alto contraste y navegación sencilla. |
| Cuenta | Perfil propio, preferencias y notificaciones. |

## Chat

Se prevén Flutter, Supabase, PostgreSQL y Supabase Realtime. El listado de conversaciones y el chat individual usarán modelos Conversation y Message, identificación de participantes y repositorios de conversaciones y mensajes. Implementar envío, recepción y estados de mensaje. Aplicar RLS por participante, suscribirse a cambios al abrir la conversación y cancelar la suscripción al salir. Al reconectar, reconciliar cambios y reintentar mensajes no enviados evitando duplicados.

## Componentes previstos

AppTextField, AppSearchBar y RandomPinKeypad para entrada. LocationChip, RatingStars, ServiceCard, SolidarityCard y EmergencyCard para los listados. SOSButton, OfflineBanner y StatusBadge para acciones y estados. MessageBubble y ChatInput para conversaciones.
