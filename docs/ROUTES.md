# Navegación

«Cadena de Favores» apila `/favores` desde el Dashboard o el Drawer. «Explorar economía solidaria» abre su ruta hija existente `/favores/ampliado` con la misma pantalla en modo ampliado. Volver recupera la selección anterior. Ambas vistas comparten el encabezado, el Drawer y la barra de cinco destinos del shell.

El Dashboard y el Drawer abren `/servicios` dentro del shell. Las tarjetas apilan `/servicios/:id` y el regreso recupera la vista de origen. Un perfil abierto directamente ofrece regreso al directorio. Un ID desconocido muestra una salida explícita al listado.

Al pie del Dashboard, «Pruebas de desarrollo» abre el registro y el ingreso con PIN. Registro abre `/auth/pin` sobre el formulario y permite volver a editar los datos. Tras confirmar la clave, «Ir al inicio» abre el Dashboard. El login muestra un aviso de verificación pendiente y ofrece un regreso explícito a la demo.

Publicar abre el selector dentro del shell. Detalles y vista previa ocupan toda la pantalla. Las entradas directas sin borrador o resumen regresan al selector. Los enlaces anteriores `/publicar` y `/publicar/confirmacion` conservan una redirección.

La aplicación comienza en `/inicio`. Las cinco pestañas conservan su navegador. El menú y los accesos de Inicio abren destinos secundarios sobre la pestaña actual. Las rutas profundas admiten entrada directa. El Dashboard implementado abre el directorio y el muro desde sus categorías. Cada tarjeta abre `/servicios/:id` con su identificador de demostración. Volver recupera la búsqueda local.

| Referencia en `design/references/screens/` | Destino | Ruta | Archivo previsto bajo `lib/` |
|---|---|---|---|
| 01_Menu_Lateral_SOS.png | Menú lateral | Drawer del shell | `shared/widgets/navigation/app_drawer.dart` |
| 02_Inicio_Dashboard.png | Inicio | `/inicio` | `features/home/presentation/screens/home_screen.dart` |
| 03_Directorio_Servicios.png | Servicios del Barrio | `/servicios` | `features/services/presentation/screens/services_screen.dart` |
| 04_Perfil_Proveedor.png | Perfil de proveedor | `/servicios/:id` | `features/services/presentation/screens/provider_detail_screen.dart` |
| 05_Muro_Colaborativo.png | Cadena de Favores | `/favores` | `features/solidarity/presentation/screens/solidarity_wall_screen.dart` |
| 06_Publicacion_Paso_1.png | Publicar | `/publicar/tipo` | `features/publications/presentation/screens/publication_type_screen.dart` |
| 07_Mapa_Geolocalizado.png | Mapa | `/mapa` | `features/maps/presentation/screens/neighborhood_map_screen.dart` |
| 08_Tablero_Emergencia.png | Modo SOS | `/sos` | `features/emergency/presentation/screens/emergency_dashboard_screen.dart` |
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
