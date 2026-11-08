# Fase 6 — Roadmap de mapa y geolocalización

Plan derivado de la auditoría 6.1 del checkout main, 2026-11-08. No se implementó ninguna clase, dependencia, permiso, ruta ni SQL en esta entrega. Las rutas de archivos propuestas abajo son diseño, no evidencia de archivos ya existentes. La rama solicitada feat/mapa-geolocalizacion no es la rama activa; coordinar integración sin cambiarla automáticamente.

## Arquitectura mínima propuesta

Mantener features/maps y los adaptadores SOS existentes. No crear un segundo árbol de mapas ni cambiar Provider/GoRouter/auth. Reutilizar estilos, AppCard, AppSectionHeader, accesibilidad y shell.

| Archivo propuesto bajo lib/ | Responsabilidad |
|---|---|
| features/maps/models/geo_coordinate.dart | Coordenada inmutable lat/lng, validación numérica finita, rangos y conversión geográfica; sin widgets |
| features/maps/models/map_point.dart | DTO de puntos_mapa: capa,id,titulo,subtipo,estado,urgencia nullable,lat,lng,distancia_m. No añadir rating, propietario, contacto ni campos de tabla no retornados |
| features/maps/models/map_origin.dart | Modelo derivado de presentación: coordenada, origen GPS/centro de zona y etiqueta. Nunca columna SQL inventada |
| features/maps/data/map_repository.dart | Interfaz y adaptador Supabase, mismo cliente de main. mi_zona + zonas para centro; puntos_mapa y, solo si se acuerda, buscar_publicaciones_cercanas; consultas mínimas de detalle si módulos reales faltan |
| features/maps/data/geography_decoder.dart | Decode de zonas.centro, Point 2D SRID4326 WKB/EWKB verificado. Si no hay muestra compatible, error explícito y decisión SQL pendiente; no adivinar ejes |
| features/maps/data/location_service.dart | Interfaz injectable y adaptador geolocator; comprobar servicio/permiso, petición explícita y una lectura puntual con timeout. No escuchar stream |
| features/maps/presentation/controllers/map_controller.dart | ChangeNotifier con repo/location inyectados, origen, filtros, carga/éxito/vacío/error, generación de lectura y limpieza por cambio de sesión/modo |
| features/maps/presentation/widgets/geographic_map_canvas.dart | FlutterMap, teselas, atribución, marcadores y estado de fallo de mapa base. MapController de flutter_map es cámara, no el controlador Provider de negocio |
| features/maps/presentation/widgets/map_point_marker.dart | Icono/color/semántica por capa y estado. Clave compuesta capa+UUID; puntos distintos pueden coincidir en una celda |
| features/maps/presentation/widgets/map_point_details.dart | Ficha mínima, reconsulta autorizada, carga/error/ausente y enlaces solo a destinos reales comprobados |

Archivos existentes a adaptar posteriormente: neighborhood_map_screen.dart/canvas.dart, community_map_marker.dart, emergency_map_screen.dart/canvas.dart, main.dart para composición. Los modelos demo se preservan para fixtures/referencia y no entran como fallback productivo. Iconos/categorías se quedan en presentación, no en el DTO.

La capa de datos no depende de widgets, LatLng de biblioteca ni PIN. El adaptador de lienzo convierte GeoCoordinate a LatLng(lat,lng). Auth sigue proporcionando la sesión y el cliente; mapa obtiene su zona por mi_zona(), sin reconstruir auth ni modificar su contrato Profile.

## Origen y ciclo de vida

Sin GPS: consultar zona propia y su centro real, etiquetar «Centro de tu zona», sin fabricar ubicación ni elegir el primer catálogo. Con GPS: acción explícita «Usar mi ubicación», precisión suficiente para barrio, aceptación de ubicación aproximada, solo memoria y sin envíos de seguimiento. Permiso denegado/denegado permanentemente, servicio apagado o timeout no impiden usar un centro válido. Si tampoco hay centro, mostrar estado bloqueado con reintento.

No confundir radio_m de zona con p_radio_m de búsqueda. Propuesta MVP: valor inicial compatible de 3000 m con validación positiva, límites de UI acordados y sin afirmar restricción del backend que no existe. El radio de búsqueda no amplía RLS.

Separar error de tiles de error de datos, y permiso GPS denegado de sesión denegada. Un mapa base sin red no debe ocultar que la consulta de puntos también falló. Mantener datos propios previos solo si claramente marcados como antiguos, nunca una lista de otro usuario; propuesta inicial más simple: vaciar datos durante recarga/error. No implementar cola offline ni descarga masiva de teselas.

Cada lectura captura usuario, zona, centro, radio y modo; descartar resultados si cambia cualquiera o si fue dispose. Generación monotónica para respuestas fuera de orden y debounce de cámara/búsqueda. Las vistas ocultas del IndexedStack no deben emitir permisos ni duplicar localización. Resetear datos privados al cambio de sesión y conservar filtros normal/SOS separadamente.

## 6.2 — Mapa interactivo real

**Dependencias:** auditoría 6.1, seleccionar proveedor y política de atribución/caché, revisar rama y SDK. Candidatos flutter_map 8.3.2 y latlong2 0.10.1; verificar solver antes de fijar versiones. No geolocator todavía.

**Archivos:** pubspec.yaml/lock, geographic_map_canvas.dart, geo_coordinate.dart, map_origin.dart, map_repository.dart con lectura mínima de zona, geography_decoder.dart, neighborhood_map_screen.dart/canvas.dart y emergency_map_screen.dart/canvas.dart. Inyectar el repositorio desde main.dart con el cliente existente. No tocar auth.

**Implementación:** tiles HTTPS configurables, zoom/pan, atribución legible, identificación propia de cliente y estado de error. Centrar en zona real mediante mi_zona+centro decodificado. Si todavía no puede obtenerse centro, mostrar estado pendiente y no un mapa fingido de Lima. No superponer marcadores demo ni óvalo de riesgo en el camino real. Sustituir el fondo de mapa conservando encabezados, filtros y navegación.

**Pruebas:** canvas con proveedor de imágenes simulado, centro validado, zoom/pan, atribución visible, error de teselas, centro ausente/malformado, orientación, 320/412 px, escalas 1.5/2 y regreso. Evitar que tests locales soliciten teselas públicas.

**Riesgos:** identificación genérica de Android, caché persistente no garantizada por defaults de biblioteca, dependencia de red, múltiples lienzos montados, centro raw malinterpretado.

**Cierre:** mapa geográfico real con centro autorizado, sin datos demo en producción; analizar y suite anterior verdes. Documentar proveedor y configuración; si no se cumplen sus condiciones, no activar su endpoint.

## 6.3 — Ubicación puntual y permisos

**Dependencias:** mapa 6.2 y fallback de centro validado. Añadir geolocator después de comprobar requisitos de plataforma y solver.

**Archivos:** location_service.dart, map_controller.dart, pantallas y control «Usar mi ubicación», android/app/src/main/AndroidManifest.xml; revisar build.gradle.kts sin fijar valores por copia. iOS Info.plist y ajustes WhenInUse únicamente si se soporta esa plataforma.

**Implementación:** solicitar permiso tras acción explícita, una lectura con timeout, precisión aproximada aceptada y botón recarga opcional. No seguimiento, segundo plano, geocodificación ni persistencia GPS. Fallback a centro y etiqueta correcta; no distancia desde teléfono cuando se usa centro.

**Pruebas:** LocationService fake para granted, aproximado, denied, deniedForever, servicio desactivado, timeout, error, vuelta desde ajustes, doble toque, dispose y cambio de usuario. Android real: primera solicitud, rechazo, reingreso y permiso revocado con app pausada. No pedir ubicación en initState o al desbloquear PIN.

**Riesgos:** permisos permanentes, límites nativos/SDK, demora de precisión coarse, mapa oculto intentando solicitar permisos.

**Cierre:** adquisición puntual y alternativa sin GPS funcionan, no hay permisos de ubicación continua/segundo plano añadidos por la app y no se publican coordenadas privadas.

## 6.4 — Marcadores autorizados desde Supabase

**Dependencias:** origen validado de 6.2/6.3 y contrato desplegado comprobado mediante lecturas autorizadas.

**Archivos:** map_point.dart, map_repository.dart, map_controller.dart, map_point_marker.dart, geographic_map_canvas.dart; futuros tests de DTO, HTTP simulado y controlador. Reutilizar modelos geográficos de compañeros solo si están presentes y son compatibles, sin importarlos desde una rama inexistente.

**Implementación:** llamar puntos_mapa con p_lat,p_lng,p_radio_m exactos; claves capa+UUID; tratar urgencia nullable y subtipos heterogéneos. Paginar con orden estable PostgREST y detectar límite/truncamiento, sin prometer todos los puntos. No enviar parámetros de filtros no existentes. Sobreposición por rejilla: mostrar selección/lista de puntos en la misma ubicación, sin dispersarlos con coordenadas falsas.

**Favores:** decisión explícita. El contrato no tiene capa favor. MVP mínimo conecta cuatro capas existentes; si se requiere favores, componer buscar_publicaciones_cercanas con DTO propio y etiqueta visual derivada, no alterar puntos_mapa ni fingir que devuelve esa capa. No mezclar estado/urgencia ni promediar datos incompletos.

**Pruebas:** cuatro capas, NULL de urgencia, coordenadas numéricas/UUID válidos y malformados, orden de ejes, lista vacía, permisos, sesión expirada, timeout, errores de páginas posteriores, límite de API y respuestas fuera de orden. Integra prueba de dos zonas con sesiones de usuario si existe entorno autorizado, sin service_role.

**Riesgos:** funciones instaladas distintas, respuestas truncadas y cambios durante paginación, campo estado activo derivado en brigadas, muchos puntos coincidentes en centro de zona.

**Cierre:** solo puntos autorizados, estados precisos de error/vacío y sin fallback a demo; firma/retorno compatibles con el SQL efectivo.

## 6.5 — Filtros y navegación

**Dependencias:** cuatro capas reales y decisión de favores. Comprobar qué detalles reales de Servicios/Favores/SOS están integrados en la rama actual.

**Archivos:** pantallas normales/SOS, map_controller.dart, map_point_details.dart, adaptadores visuales de categorías. app_navigation.dart/router solo si fuera imprescindible; mantener rutas actuales preferentemente.

**Implementación:** filtros de capas, búsqueda textual local claramente limitada a puntos cargados; urgencia y sin_verificar separados para SOS. Conservar filtros al visitar un detalle y al salir/entrar de SOS. Reconsultar entidad por UUID antes de mostrar detalle; inexistente/oculta implica no disponible. Si el detalle de proveedor sigue siendo demo, no enviar allí UUID reales: usar ficha mínima autorizada hasta integrar el módulo.

No hay ruta actual de publicación individual ni detalle de recurso/alerta UUID en esta rama. La ficha mínima evita rutas duplicadas; decidir con el equipo antes de registrar destinos nuevos. No incluir botones de llamar, aceptar o ayudar si la operación real no está implementada.

**Pruebas:** combinación filtros/búsqueda, cero resultados, filtros independientes, UUID desconocido, permiso revocado tras cargar punto, rápido cambio de selección, entrar directo a /mapa y /sos/mapa, Android Atrás, cierre ficha, proveedor real si existe, conservación de cámara y autenticación.

**Riesgos:** enlaces a demos, confundir tipo comercio con proveedor, obtener datos privados para rellenar ficha, query local presentada como búsqueda completa.

**Cierre:** cada marcador abre el registro correcto o informa su ausencia; regreso conserva estado y no existe falsa confirmación ni acción simulada presentada como real.

## 6.6 — Integración y pruebas finales

**Dependencias:** 6.2–6.5 implementadas, entorno/escenario autorizado y evidencia de correcciones SQL críticas antes de producción.

**Archivos:** test de modelo/repositorio/controlador/widgets bajo test/maps*, integración futura integration_test/supabase_maps_test.dart y documento de cierre. Solo prepararlos cuando corresponda, sin borrar tests actuales.

**Implementación y verificación:** recorrer PIN→mapa→centro, GPS permitido/denegado, carga de puntos, filtros, detalle, SOS, regreso y pérdida/recuperación de red. Separar base cartográfica caída de Supabase caído. Revisar licencias/identificación/caché con proveedor; no emitir SOS ni crear publicaciones en proyecto compartido.

**Pruebas reales propuestas:** A/B en zonas distintas con puntos sintéticos previamente autorizados: A solo ve zona A aunque centre cámara en B; B solo B; una sesión sin perfil no recibe capas; anon no ejecuta RPC; cero teléfonos privados/vulnerables; cambios de visibilidad; comparar lat/lng proyectados con fixtures de SRID4326. Datos de dos zonas y pruebas de escritura requieren autorización. Si no existe entorno, preparar test deshabilitado y marcar pendiente; mocks no prueban RLS.

**Regresiones:** ejecutar flutter analyze, flutter test --concurrency=1, git diff --check y git status; comprobar auth/PIN, shell, servicios/favores/SOS presentes, tamaños y accesibilidad. Probar Android físicamente con una ubicación puntual sin logs personales. No depender de cambios solo disponibles en otras ramas.

**Riesgos:** resultado remoto desconocido, credenciales administrativas, API de proveedor bloqueada, faltas de atribución, cierre_alerta vulnerable no solucionado por mapa. No atribuir el arreglo de una vulnerabilidad SQL a una comprobación Flutter.

**Cierre:** pruebas locales aprobadas, integraciones reales documentadas por separado, sin bloqueos críticos de privacidad ni flujos esenciales pendientes; revisión de equipo antes de cualquier merge. No realizar operaciones Git de escritura automáticamente.

## Decisiones previas a comenzar

1. Coordinar rama de trabajo y qué implementaciones de Servicios/SOS/Favores se integrarán; main actual no las tiene.
2. Elegir proveedor, identificación y estrategia de caché conforme a sus políticas; validar compatibilidad con resolver de dependencias, todavía no ejecutado.
3. Aprobar centro registrado como fallback y etiqueta de distancias; verificar lectura/decoder de centro sin modificar auth.
4. Definir capas normales/SOS, inclusión de favores y política de truncamiento. No inventar un polígono de riesgo ni bbox SQL.
5. Confirmar esquema efectivo y plan de corrección del defecto SQL cerrar_alerta antes de desplegar el MVP. No bloquea una implementación de lienzo en pruebas, sí la certificación de seguridad del proyecto.

La Fase 6.1 termina con estos documentos y la validación del estado existente. No se instalaron paquetes ni se inició 6.2.
