# Próximas fases

El Dashboard de la referencia 02 está implementado con búsqueda local. Quedan pendientes los proveedores registrados, sus valoraciones y la ubicación autorizada. Las prioridades posteriores se definirán durante la hackathon.

| Área | Trabajo previsto |
|---|---|
| Identidad | Integrar Supabase para crear cuentas y perfiles, registrar el PIN de forma segura, validarlo en el servidor y recuperar el nombre. Implementar sesiones, autorización de rutas y backend, recuperación de credenciales y bloqueo temporal por intentos fallidos. |
| Servicios | Conectar Supabase, registrar proveedores reales, calcular distancias con GPS autorizado, habilitar contacto y solicitudes. Incorporar reseñas auténticas, moderación y verificación comunitaria. El directorio, los filtros y los perfiles actuales usan datos ilustrativos. |
| Solidaridad y publicaciones | Implementados el muro, sus filtros locales y Economía solidaria con tarjetas y datos de demostración. Pendientes la integración con Supabase, creación y edición de publicaciones reales, contacto y chat entre vecinos, favoritos persistentes, comentarios reales, Visto Bueno Vecinal auténtico, moderación, notificaciones y sincronización offline. |
| Publicación rápida | Implementados selector, plantillas, formulario y vista previa local. Pendientes Supabase, persistencia, autoría autenticada, ubicación real, sincronización offline, creación, edición y eliminación real, aparición en el muro y notificaciones a vecinos. |
| Mapa | Implementados el mapa ilustrativo, búsqueda, filtros, leyenda y fichas locales. Pendientes mapas geográficos, GPS y permisos, Supabase, datos comunitarios reales, ubicaciones aproximadas con consentimiento y cálculo de distancias. El mapa de emergencias, los reportes y las brigadas auténticas quedan pendientes. |
| SOS | Implementado el tablero 08 frontend: encabezado rojo de demostración, cinco reportes ficticios, prioridades, detalles de consulta, avisos informativos, lista ampliable, estado temporal normal/SOS, navegación principal por reemplazo, pestañas según modo, salida explícita y mapa SOS ilustrativo de fase 13 con pruebas de Atrás Android. Implementada la pantalla 18: Centro de Ayuda Vecinal, tres acciones, trece categorías, selección temporal, resúmenes de demostración, accesos desde el tablero y pruebas de navegación y accesibilidad. Pendientes backend, Supabase, reportes reales, GPS, solicitud y ofrecimiento real de ayuda, envío y confirmación real de alertas, recursos reales, coordinación de voluntarios, brigadas reales y contactos verificados, aceptación real de voluntarios, seguimiento y chat reales, notificaciones y sincronización offline. |
| Offline | Almacenamiento local y cola con reintentos e idempotencia. |
| Accesibilidad | Fase 15 implementada. Tutorial consultable y cuatro preferencias en memoria. Queda pendiente integrar almacenamiento para conservar los ajustes entre sesiones. |
| Cuenta | Perfil propio, preferencias y notificaciones. |

## Chat

Se prevén Flutter, Supabase, PostgreSQL y Supabase Realtime. El listado de conversaciones y el chat individual usarán modelos Conversation y Message, identificación de participantes y repositorios de conversaciones y mensajes. Implementar envío, recepción y estados de mensaje. Aplicar RLS por participante, suscribirse a cambios al abrir la conversación y cancelar la suscripción al salir. Al reconectar, reconciliar cambios y reintentar mensajes no enviados evitando duplicados.

## Componentes previstos

AppSearchBar para búsqueda. LocationChip, RatingStars, ServiceCard y EmergencyCard para los listados. SOSButton, OfflineBanner y StatusBadge para acciones y estados. MessageBubble y ChatInput para conversaciones.

Fase 10 implementada: pantalla 09 Grupos de Apoyo y Brigadas, catálogo ficticio con sectores e integrantes, búsqueda local sin tildes, filtros por tipo, tarjetas reutilizables, estado vacío y restablecimiento, avisos de contacto no disponible, integración con Tablero y Modo SOS y pruebas automatizadas. Pendientes Supabase, brigadas reales, identificación de miembros, contactos verificados, chat y llamadas, registro de voluntarios, coordinación de ayuda, notificaciones, GPS y sincronización offline. El mapa definitivo de la pantalla 23 sigue pendiente.

Fase 11 completada en frontend. La pantalla 10 presenta una necesidad local y un voluntario ficticio. Siguen pendientes el envío, la aceptación real, el contacto y el seguimiento.

Fase 12 completada en frontend. El seguimiento visual incluye un recorrido ficticio y una conversación ilustrativa de solo lectura. Siguen pendientes la integración con backend, la aceptación real, la coordinación entre usuarios, las llamadas, la mensajería y las notificaciones.

Fase 14 completada en frontend. Los perfiles permiten previsualizar una calificación y un comentario opcional con validación local. Quedan pendientes la persistencia, la publicación y la verificación vecinal real.
