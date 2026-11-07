# Navegación

«Estados offline (demo)» apila `/offline/pendiente` desde el Drawer. Elegir éxito abre `/offline/sincronizado`; su entrada directa muestra una vista previa. Atrás conserva el origen y, sin historial, vuelve a Inicio o al Tablero según el modo. «Ir al tablero de ayuda» abre `/sos/tablero` y activa SOS mediante la navegación existente.

El Drawer apila `/tutorial` y `/configuracion/accesibilidad` sobre el origen. Ambas son pantallas enfocadas con un encabezado y sin barra inferior. Atrás recupera el destino anterior. Si se abre una ruta directamente, Atrás conduce a Inicio o al Tablero SOS según el modo vigente. Finalizar el tutorial usa la misma salida.

El Drawer y las categorías del Dashboard cambian destinos principales mediante `AppNavigation.open` y `go()`, cerrando el Drawer antes de navegar. Servicios, Cadena de Favores, Notificaciones y Configuración sustituyen la sección anterior. Atrás vuelve a Inicio sin recorrer secciones previas. Los detalles de proveedores, el muro ampliado y los pasos de formularios conservan `push()` para volver al origen inmediato.

En modo normal, Inicio abre `/inicio` (Dashboard) y Mapa abre `/mapa` (recursos). Seleccionar Modo SOS activa el estado temporal y abre `/sos/tablero`; `/sos` mantiene su redirección de compatibilidad. En modo SOS, Inicio abre el tablero y Mapa abre `/sos/mapa` en su propia rama del shell, con una sola barra inferior. El botón «Ver mapa de reportes» usa ese mismo destino sin apilarlo. Publicar, Mensajes y Perfil conservan sus destinos habituales y el estado SOS permanece activo.

El Mapa de Emergencia incluye filtros locales y detalles que se abren y cierran en un panel de consulta. Desde allí, Atrás o «Volver al Tablero SOS» abre el tablero. «Salir del Modo SOS» desactiva el estado y abre el Dashboard; Atrás desde el tablero también sale a Inicio. Estas reglas se aplican al botón de la interfaz y a Atrás de Android. Inicio y Mapa no restauran rutas SOS obsoletas después de salir. El mapa comunitario conserva sus filtros durante el cambio de modo. La aplicación continúa iniciando en `/inicio`.

«Cadena de Favores» abre `/favores` reemplazando la sección principal desde el Dashboard o el Drawer. «Explorar economía solidaria» abre su ruta hija existente `/favores/ampliado` con la misma pantalla en modo ampliado. Volver recupera la selección anterior. Ambas vistas comparten el encabezado, el Drawer y la barra de cinco destinos del shell.

El Dashboard y el Drawer abren `/servicios` dentro del shell. Las tarjetas apilan `/servicios/:id` y el regreso recupera la vista de origen. Un perfil abierto directamente ofrece regreso al directorio. Un ID desconocido muestra una salida explícita al listado.

Al pie del Dashboard, «Pruebas de desarrollo» abre el registro y el ingreso con PIN. Registro abre `/auth/pin` sobre el formulario y permite volver a editar los datos. Tras confirmar la clave, «Ir al inicio» abre el Dashboard. El login muestra un aviso de verificación pendiente y ofrece un regreso explícito a la demo.

Publicar abre el selector dentro del shell. Detalles y vista previa ocupan toda la pantalla. Las entradas directas sin borrador o resumen regresan al selector. Los enlaces anteriores `/publicar` y `/publicar/confirmacion` conservan una redirección.

La aplicación comienza en `/inicio`. Las cinco pestañas conservan su navegador. El menú y las categorías de Inicio reemplazan destinos principales; las tarjetas apilan detalles secundarios. Las rutas profundas admiten entrada directa. El Dashboard implementado abre el directorio y el muro desde sus categorías. Cada tarjeta abre `/servicios/:id` con su identificador de demostración. Volver recupera la búsqueda local.

| Referencia en `design/references/screens/` | Destino | Ruta | Archivo previsto bajo `lib/` |
|---|---|---|---|
| 01_Menu_Lateral_SOS.png | Menú lateral | Drawer del shell | `shared/widgets/navigation/app_drawer.dart` |
| 02_Inicio_Dashboard.png | Inicio | `/inicio` | `features/home/presentation/screens/home_screen.dart` |
| 03_Directorio_Servicios.png | Servicios del Barrio | `/servicios` | `features/services/presentation/screens/services_screen.dart` |
| 04_Perfil_Proveedor.png | Perfil de proveedor | `/servicios/:id` | `features/services/presentation/screens/provider_detail_screen.dart` |
| 05_Muro_Colaborativo.png | Cadena de Favores | `/favores` | `features/solidarity/presentation/screens/solidarity_wall_screen.dart` |
| 06_Publicacion_Paso_1.png | Publicar | `/publicar/tipo` | `features/publications/presentation/screens/publication_type_screen.dart` |
| 07_Mapa_Geolocalizado.png | Mapa | `/mapa` | `features/maps/presentation/screens/neighborhood_map_screen.dart` |
| 08_Tablero_Emergencia.png | Modo SOS | `/sos/tablero` | `features/emergency/presentation/screens/emergency_dashboard_screen.dart` |
| 09_Grupos_y_Brigadas.png | Brigadas | `/sos/brigadas` | `features/emergency/presentation/screens/brigades_screen.dart` |
| 10_Confirmacion_Ayuda.png | Confirmación de ayuda | `/sos/confirmacion` | `features/emergency/presentation/screens/help_confirmation_screen.dart` |
| 11_Inicio_Sesion_PIN.png | Ingreso con PIN | `/auth/login` | `features/auth/presentation/screens/login_pin_screen.dart` |
| 12_Registro_DNI_Nombre.png | Registro | `/auth/registro` | `features/auth/presentation/screens/register_screen.dart` |
| 13_Registro_Crear_PIN.png | Crear PIN | `/auth/pin` | `features/auth/presentation/screens/create_pin_screen.dart` |
| 14_Tutorial_Accesible.png | Tutorial | `/tutorial` | `features/tutorial/presentation/screens/tutorial_screen.dart` |
| 15_Muro_Solidario_Ampliado.png | Muro ampliado | `/favores/ampliado` | `features/solidarity/presentation/screens/solidarity_wall_screen.dart` |
| 16_Publicacion_Paso_2_Confirmar.png | Detalles de publicación | `/publicar/detalles` | `features/publications/presentation/screens/publication_details_screen.dart` |
| 17_Publicacion_Confirmada.png | Vista previa lista | `/publicar/exito` | `features/publications/presentation/screens/publication_success_screen.dart` |
| 18_SOS_Acciones_Criticas.png | Acciones SOS | `/sos/acciones` | `features/emergency/presentation/screens/emergency_actions_screen.dart` |
| 19_Offline_Pendiente_Sync.png | Sincronización pendiente | `/offline/pendiente` | `features/offline/presentation/screens/pending_sync_screen.dart` |
| 20_Offline_Sincronizado.png | Sincronización | `/offline/sincronizado` | `features/offline/presentation/screens/synchronized_screen.dart` |
| 21_Accesibilidad.png | Accesibilidad | `/configuracion/accesibilidad` | `features/settings/presentation/screens/accessibility_screen.dart` |
| 22_Calificacion_Visto_Bueno.png | Nueva reseña | `/resenas/nueva` | `features/reviews/presentation/screens/create_review_screen.dart` |
| 23_Mapa_Alerta_Critica.png | Mapa SOS | `/sos/mapa` | `features/emergency/presentation/screens/emergency_map_screen.dart` |
| 24_Ayuda_Aceptada_Ruta_Chat.png | Seguimiento de ayuda | `/sos/seguimiento` | `features/emergency/presentation/screens/help_tracking_screen.dart` |
| — | Mensajes | `/mensajes` | `features/chat/presentation/screens/conversations_screen.dart` |
| — | Conversación | `/mensajes/:id` | `features/chat/presentation/screens/chat_screen.dart` |
| — | Perfil | `/perfil` | `features/profile/presentation/screens/profile_screen.dart` |
| — | Notificaciones | `/notificaciones` | `features/notifications/presentation/screens/notifications_screen.dart` |
| — | Configuración | `/configuracion` | `features/settings/presentation/screens/settings_screen.dart` |

La pestaña Mapa abre `/mapa` dentro del shell. Cada punto abre un panel de detalles. Ver proveedor apila el perfil existente del comercio y volver recupera el mapa con sus filtros.

Fase 9: `/sos/acciones` implementa el Centro de Ayuda Vecinal (referencia 18). Admite `?action=neighborAlert`, `?action=criticalSupport` y `?action=offerResources` para abrir un selector al entrar. Un valor ausente o desconocido muestra el centro sin panel. Solicitar ayuda usa `criticalSupport` y Ofrecer ayuda usa `offerResources`.

El tablero abre acciones con go(), reemplazando el destino. Acciones es una vista enfocada dentro de la rama Inicio del shell, sin barra inferior; usa el mismo controlador SOS y conserva el estado de las otras ramas. Atrás Android y el botón Atrás vuelven a `/sos/tablero` sin recorrer Servicios u otras secciones. Con un panel abierto, Atrás primero cierra el panel. Salir del Modo SOS desactiva el modo y abre `/inicio`. El tablero recupera su única barra inferior; Inicio y Mapa mantienen las reglas de la fase 8. Las categorías y los resúmenes son estados internos del panel, sin nuevas rutas.

Fase 10: `/sos/brigadas` reemplaza el placeholder 09 con BrigadesScreen dentro de la rama Inicio. «Grupos y Brigadas» desde el tablero abre este destino con go(). La ruta directa activa SOS. Atrás de interfaz o Android abre `/sos/tablero` incluso sin historial; nunca recupera Servicios ni Cadena de Favores. Conserva una sola barra inferior del shell. Inicio lleva al tablero, Mapa a `/sos/mapa` y las otras tres pestañas mantienen su funcionamiento. «Salir del Modo SOS» restaura Dashboard y mapa comunitario. Buscar, filtrar y abrir/cerrar el aviso de contacto son estados locales sin nuevas rutas.

Fase 11. `/sos/confirmacion` pertenece a la rama Inicio y activa SOS al entrar directamente. Sin selección presenta una necesidad de ejemplo. Desde el resumen de soporte crítico presenta la necesidad elegida. Atrás de Android, Atrás de la interfaz y «Regresar al inicio» vuelven a `/sos/tablero` conservando SOS. Los detalles y los tres controles de contacto abren diálogos locales.

`/sos/seguimiento` activa SOS y presenta un flujo enfocado dentro de la rama Inicio, sin barra inferior. Desde la confirmación, Atrás recupera la categoría o el ejemplo previo. Desde una entrada directa, vuelve al Tablero SOS. Salir del Modo SOS restaura el Dashboard. Chat y Llamar se cierran en el mismo destino.

El perfil apila `/resenas/nueva?providerId=demo-carpinteria` (o el ID del proveedor elegido) sobre el shell. Atrás recupera el perfil y el directorio conserva sus filtros. Una entrada directa sin ID o con ID desconocido muestra un mensaje y un acceso a `/servicios`. Sin historial, el botón Atrás también conduce al directorio.
