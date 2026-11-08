# Fase 3.1 — Auditoría de Servicios de Proximidad y Visto Bueno Vecinal

Fecha: 2026-11-08 (America/Lima). Rama observada: `feat/servicios-visto-bueno`. Alcance: inspección del repositorio y documentación; no se consultó ni modificó el proyecto Supabase. «Contrato efectivo» significa el resultado de los SQL versionados, no una certificación del esquema desplegado. Estado inicial de Git: limpio.

## Estado actual y fuentes

El directorio, las fichas, el formulario de valoración y los enlaces desde Inicio y Mapa funcionan como demostración local. No existen repositorios, controladores de negocio, consultas Supabase ni escrituras de servicios/recomendaciones. La autenticación sí está integrada: se leyó su implementación para reutilizar convenciones; no se modificó.

Se leyeron todos los Dart de `lib/features/services/` y `lib/features/reviews/`, sus consumidores en home/maps, las tres pantallas de publications, sus modelos y plantillas, `lib/app/{app,app_router,app_routes,app_shell,app_navigation}.dart` como referencia de navegación, y los contratos/patrones de auth. El contrato SQL y las firmas literales están en [FASE_3_1_CONTRATO_SUPABASE.md](FASE_3_1_CONTRATO_SUPABASE.md); la secuencia de trabajo y pruebas está en [FASE_3_ROADMAP_IMPLEMENTACION.md](FASE_3_ROADMAP_IMPLEMENTACION.md).

## Inventario de pantallas y rutas reales

Las rutas se verifican en `lib/app/app_routes.dart` y en los builders de `lib/app/app_router.dart`. Directorio y detalle pertenecen a la rama Inicio de `StatefulShellRoute.indexedStack`; reseñas usa una ruta con Scaffold propio. Las guardas actuales de auth se conservan.

| Ruta | Archivo bajo `lib/features/` | Datos/origen actual | Acciones y limitación | Conexión mínima futura |
|---|---|---|---|---|
| `/inicio` | `home/presentation/screens/home_screen.dart` | `dashboardDemoData`, tres referencias a `demoServices`; nombre, resumen, estrellas, metros y sello | Búsqueda local con `matches`, abrir ficha, abrir directorio y favores. `HomeCategorySelector` cambia de sección, no filtra oficios | Inyectar listado real compartido con directorio y sus estados; mantener tarjetas y navegación |
| `/servicios` | `services/presentation/screens/services_screen.dart` | Cinco `demoServices`, sin consulta ni controlador | Búsqueda inmediata local; chips Todos, Hasta 500 m, 1 km y 4+; limpiar; abrir ficha. Todos elimina radio y desactiva 4+. Hay vacío, pero no carga/error | Controller, catálogo real, RPC con ubicación o consulta por zona sin GPS; conservar filtros al regresar del detalle; añadir selección mínima de categoría |
| `/servicios/:id` | `services/presentation/screens/provider_detail_screen.dart` | `firstOrNull` en catálogo por ID demo; proveedor, servicio, oficio, experiencia, distancia, promedio, contador, sello, trabajos y reseñas | Atrás, no encontrado, calificar abre reseña; Llamar y Solicitar solo muestran SnackBar | Resolver UUID de servicio desde backend aunque se abra por enlace directo; cargar trabajos, reseñas, contacto permitido y elegibilidad. Solicitar debe insertar; llamar requiere contacto visible y capacidad de plataforma |
| `/resenas/nueva?providerId=…` | `reviews/presentation/screens/create_review_screen.dart` | ID opcional resuelto en demoServices; rating local 0 inicialmente, comentario opcional hasta 300 grafemas | Selector 1–5, validación y diálogo Vista previa. No publica, no modifica media ni comprueba experiencia. Sin ID/inválido muestra retorno al directorio | Mantener ruta y clave `providerId`; su valor es **servicio.id**, no proveedor.id. Consultar elegibilidad real y publicar recomendación al confirmar; deshabilitar durante envío; refrescar ficha/listados |
| `/mapa` | `maps/presentation/screens/neighborhood_map_screen.dart` | `demoMapMarkers`, comercios de plumbing/carpentry en posiciones relativas | Búsqueda y filtros de capas, modal y Ver proveedor | El enlace al detalle puede reutilizarse con UUID real; no mezclar IDs demo con datos reales. Conectar cartografía completa corresponde a otra fase; no presentar lienzo ilustrativo como GPS |
| `/publicar/tipo` | `publications/presentation/screens/publication_type_screen.dart` | Cuatro `publicationTemplates` de `PostType`: necesito, ofrezco, donación, intercambio | Selección y Siguiente a detalles; solo borrador local | Es flujo del muro, no catálogo `servicios`. No llamar `publicar_rapido` para publicar un servicio |
| `/publicar/detalles` | `publications/presentation/screens/publication_details_screen.dart` | `PublicationDraft`: título hasta 80, detalle hasta 500, barrio fijo | Confirmar demostración copia borrador recortado | Puede inspirar campos visuales; faltan categoría de servicio real, contacto/consentimiento y experiencia. No reutilizar sus tipos de favor como categoría de oficio |
| `/publicar/exito` | `publications/presentation/screens/publication_success_screen.dart` | Copia local `preview`; etiqueta No enviada | Ver diálogo local y volver | No sirve como confirmación de persistencia de servicio sin un flujo separado |

No se encontró pantalla, ruta ni modelo de solicitudes de servicios. Las pantallas SOS de confirmación/seguimiento y los chats pertenecen a ayudas/favores: no completan `solicitudes_servicio`. Tampoco existe editor/publicación de servicios ni gestión de servicios propios. Los alias `/publicar` y `/publicar/confirmacion` redirigen al flujo de publicaciones, no crean servicios.

## Componentes y modelos inspeccionados

- `services/models/service_preview.dart`: modelo de presentación sin parser SQL; `ServiceCategory` enum de cinco oficios y `ProviderReview` record. Requiere descripción, rating y distancia no nulos, dos fragmentos de nombre; backend admite descripción/promedio/experiencia nulos. No tiene proveedor_id, categoria_id ni zona_id.
- `ServicePreview.matches`: busca servicio, proveedor, categoría, oficio, descripción y resumen mediante `normalizeSearch`, con límites inclusivos de distancia/4 estrellas. La RPC solo busca título, descripción y categoría. Mantener la búsqueda por profesional requiere consulta completa de zona + filtro local o una RPC futura revisada; no prometer equivalencia automática.
- `services/utils/provider_display_name.dart`: abrevia apellidos por grafemas. No debe intentar reconstruir nombres privados a partir de `nombre_publico`. Lo usan también SOS y solidaridad; conservar utilidad para esos consumidores.
- `services/presentation/widgets/service_list_card.dart`: icono por enum cerrado, texto de media/metraje y sello por booleano. Los semantics declaran explícitamente valoración de ejemplo/distancia ilustrativa; sustituirlos al integrar datos. Reutilizable con modelo/adaptador real y estado «Sin valoraciones»/sin distancia.
- `service_heading.dart`: encabezado y fallback; contiene `demoNotice`. No es capa de datos. Retirar aviso únicamente cuando esa vista use información real.
- `home/presentation/widgets/nearby_service_card.dart`: alias/export de `ServiceListCard`, no otra implementación. `dashboard_demo_data.dart` toma tres constantes del mismo catálogo.
- `reviews/presentation/widgets/review_star_selector.dart`: selector accesible 1–5, reutilizable tal cual en concepto. Validación de 300 caracteres es una regla de UI; SQL no limita comentario.
- `shared/widgets/{cards/app_card,buttons/app_button,common/app_text_field,common/app_section_header}.dart`: recursos reutilizables. `AppButton.onPressed` hoy es no nullable: para estados de envío deberá impedirse la acción con guarda de controller y, si se necesita estado visual disabled, una adaptación mínima posterior del botón o botón Material local. No hay bloqueo de red incorporado.
- Drawer/navegación compartida usa `AppRoute`; no define operaciones de servicios. Notificaciones contiene un aviso fijo «Directorio de servicios», no una notificación de solicitud.

## Clasificación de datos simulados

| Clase | Fuente | Tratamiento futuro |
|---|---|---|
| A: usados por app | `services/data/demo_services.dart` | Sustituir referencias de pantallas por repositorio. Cinco IDs `demo-*` no son UUID; estrellas 4.6–4.9, distancias 220–650, sellos manuales. Carpintería declara 98 reseñas pero solo tiene dos predefinidas de 5 estrellas: no representa agregación |
| A | `home/data/dashboard_demo_data.dart`, valores por defecto en HomeScreen | Compartir datos reales y refresco del directorio; no dejar portada demo con fichas reales |
| A | `maps/data/demo_map_markers.dart` y lienzo relativo | Mantener identificado como ilustración hasta integrar mapa; resolver enlace sin enviar IDs demo al backend |
| A | `publications/data/publication_templates.dart`, `PublicationDraft.neighborhood` | Textos de ejemplo/barrio se conservan en esta fase. El flujo es independiente del registro de servicios |
| A | `notifications/presentation/screens/notifications_screen.dart` (`demoNotices`) y demo de offline | No representan eventos reales del módulo ni cola de escrituras; no reutilizarlos como bandeja de solicitudes |
| B: solo tests | `test/support/auth_fixture.dart`, objetos `sample` en services_test y expectativas en services/reviews/dashboard/maps/navigation tests | Conservar; agregar futuros fakes de repositorio. Las constantes de lib importadas por tests siguen siendo clase A, no fixtures exclusivos |
| C: estáticos legítimos | Iconos Material, temas, `AppAssets`, etiquetas, `normalize_search.dart`, `ReviewStarSelector` | Reutilizar; el catálogo de categorías real debe venir de SQL, con mapa visual y fallback. No confundir enum de cinco categorías con catálogo completo |

La semilla SQL 004 añade zona, siete categorías, contactos y brigadas; **no añade servicios ni reseñas**. Cocina/Jardinería no caben en el enum visual actual. Catálogos en Supabase no implican proveedores reales disponibles. No se ejecutó esa semilla.

## Compatibilidad y brechas por requisito

| RF | Situación | Integración mínima y dependencia |
|---|---|---|
| M06 | Listado demostrativo | SELECT/RPC real, UUID y aislamiento de zona; estados carga/vacío/error |
| M07 | Texto, metros y rating locales; no selector de oficios | Categorías reales; radio 500/1000 y mínimo 4 mediante RPC. No existe p_categoria ni modo sin radio; decidir Todos = zona completa. No buscar proveedor con p_texto esperando que SQL lo soporte |
| M08 | Detalle/trabajos/reseñas predefinidos | SELECT servicio y trabajos, perfil público por RPC y resenas_de_servicio. No usar join directo a perfiles ajenos, RLS lo impide |
| M09 | Booleanos demo | Usar `visto_bueno` real de búsqueda o helper/regla SQL verificada sobre todas las recomendaciones visibles del servicio |
| M10 | Solo vista previa | INSERT recomendación + elegibilidad por enviadas; RLS y UNIQUE como autoridad, refresco tras persistencia |
| M11 | No hay publicación de servicio | Formulario mínimo propio dentro del directorio/modal, inserción de servicios; contacto optativo separado, consentimiento explícito; no confundir con publicaciones |
| M12 | No implementado | Solicitar desde ficha; bandeja proveedor; completar solo proveedor por RPC; recomendar desde solicitud completada |

## Recomendaciones y sello: hallazgos

Un vecino autenticado con perfil en la misma zona, distinto del proveedor y con al menos una solicitud propia completada del servicio puede insertar una recomendación. Solo el proveedor puede completar; el solicitante puede cancelar una solicitud viva. No hay verificación externa de que el trabajo ocurrió: es una confirmación del proveedor.

`recomendaciones` no referencia una solicitud concreta. UNIQUE(servicio_id, autor_id) permite **una recomendación por vecino y servicio**, aunque tenga varias experiencias completadas. Una completada habilita la inserción, no múltiples reseñas. El autor puede editar puntaje/comentario o borrar su reseña; una nueva inserción sigue requiriendo experiencia completada. No impedir duplicados solo con UI.

Puntaje entero 1–5. Búsqueda calcula count(r.id), avg(puntaje), media mostrada redondeada a un decimal; sin reseñas: count=0, promedio=NULL, visto_bueno=false. El filtro 4+ y el sello usan promedio **sin redondear**. `tiene_visto_bueno` exige count>=3 y avg>=4.0. Es cálculo existente, no columna persistida ni propuesta de producto. «Vecino confiable» deriva de puntaje_confianza>=80 y es un concepto separado.

Con dos usuarios A (proveedor) y B (cliente) solo se crea una reseña en ese servicio: no alcanza para probar encendido real del sello. Se requieren tres autores clientes distintos (A proveedor + B/C/D clientes) o fixtures unitarias para el umbral; documentar por separado la validación real pendiente. No falsificar tres experiencias del mismo usuario.

## Privacidad y geolocalización

Servicios y reseñas se restringen por zona mediante RLS; activo solo se exige en búsqueda y al solicitar, no en todo SELECT de servicios. La lectura pública de perfiles ajenos usa `perfiles_publicos_de_mi_zona`: solo ID, nombre_publico, avatar_url, zona_id, vecino_confiable. No copiar nombre completo, DNI/hash, teléfono privado, preferencias ni puntaje de confianza a modelos públicos.

`servicio_contacto` separa teléfono y autorización: propietario lo ve; vecinos de la zona solo si autorizado=true. No derivar acceso de `perfiles.compartir_telefono`. Si no llega fila, tratar como contacto no disponible y ocultar acción; no distinguir hacia terceros entre inexistente y denegado. El SQL no incluye RPC para solicitar revelación del teléfono ni autorización por solicitud individual.

El trigger ajusta ubicacion_aprox a rejilla 0.0015 grados (~166 m como aproximación del comentario SQL), usa centro de zona si falta. No garantiza anonimato absoluto ni distancia caminable. La inserción de servicios no valida cercanía al centro de zona, a diferencia de RPC de publicaciones/SOS; riesgo de puntos fuera de barrio aunque zona_id sea propia. No modificar SQL aquí.

La RPC de búsqueda requiere lat/lng, no necesariamente GPS: también admite un origen elegido. No hay proveedor de ubicación, dependencia GPS ni permisos de ubicación en manifiestos inspeccionados. No hay manejo actual de denegación porque solo se usan metros ficticios.

Propuesta mínima sin GPS: leer perfil propio (zona_id) en repositorio de servicios y consultar servicios activos de esa zona bajo RLS; obtener categorías, perfiles públicos y recomendaciones visibles para agregación. Omitir distancia y desactivar filtros métricos con explicación. Así se cumple consulta por zona sin inventar RPC ni columnas. Si se requiere proximidad desde el centro, leer `zonas.centro` exige decodificar geography (no existen columnas lat/lng en zonas) o añadir posteriormente una RPC revisada que entregue coordenadas del centro. No pasar NULL a p_lat/p_lng esperando fallback: la RPC no lo implementa. «Todos» debe ser zona completa, no el default 3000 que omite servicios distantes. No instalar ubicación en 3.1/3.2; la integración de plataforma requiere decisión posterior.

## Riesgos y decisiones pendientes

| Prioridad | Hallazgo/impacto | Tratamiento planificado |
|---|---|---|
| Alta | Esquema versionado no prueba definición desplegada | Verificación de catálogo/firmas/RLS de solo lectura antes de integración real; nunca reinstalar SQL existente |
| Alta | No hay bandeja ni publicación de servicios | Propuesta para 3.5: secciones Enviadas/Recibidas en directorio o modal; para 3.6 formulario modal Publicar servicio. Reutilizan rutas actuales; no crear aún |
| Alta | Promedio del detalle no tiene RPC por ID | SELECT recomendaciones (puntaje) visibles, agregación completa + helper; no depender de que búsqueda con radio incluya ese ID. Si crece el volumen o hay paginación, se requerirá RPC de detalle/agregados revisada |
| Alta | Publicar servicio/contacto/trabajos son operaciones separadas | UUID estable + verificación de existencia tras timeout; informar éxito parcial y reintentar solo paso pendiente; no asumir transacción entre llamadas HTTP |
| Media | RPC no filtra categoría por ID ni nombre profesional, sin LIMIT/paginación | Filtro local sobre conjunto completo por categoria_id usando consulta auxiliar, o flujo de zona completo. No usar texto como igualdad de categoría. Revisar escalabilidad antes de paginar |
| Media | Sin GPS ni centro convertido para Flutter | Fallback por zona desde 3.2; resolver política visual de métricas y alcance de GPS antes de 3.3 |
| Media | Nombres/rating/category del modelo demo no coinciden con SQL | Modelo real independiente y adaptación deliberada del UI; no fabricar apellidos, ocupaciones o reseñas |
| Media | Dispositivo sin conexión puede perder respuesta de escritura confirmada | Reconciliar por UUID/UNIQUE; no anunciar pendiente como publicada; sin cola offline demo ni PowerSync |
| Media | No hay notificación/Realtime de servicios/solicitudes/recomendaciones en scripts | Releer al volver, al completar y al recomendar; botón actualizar en bandejas. No prometer actualización push |
| Media | SQL permite completar desde solicitada, sin contactado | Respetar transiciones reales; no añadir estado aceptada/en_progreso. Estado terminal no se reabre |

Decisiones de producto para próximas fases: ubicación GPS o solo zona para primer MVP; política de «Todos» y búsqueda por proveedor; modalidad de bandeja/formulario mínimo; mantener límite visual de 300 sin atribuirlo a SQL; visualización de servicio inactivo por enlace; alcance de llamada (no hay dependencia de lanzamiento telefónico), imágenes de trabajos (no hay columna URL), tratamiento de éxito parcial. El sello **no** requiere una nueva regla de producto.

## Continuidad y validación

Se puede comenzar 3.2 con el contrato versionado y el diseño propuesto, implementando capas probables y pruebas con fakes. 3.3–3.6 necesitan resolver las decisiones anteriores y verificar que el backend desplegado coincide. La continuidad no significa que el módulo esté probado contra Supabase real.

Los resultados concretos de los comandos locales de esta auditoría se registran en el cierre del roadmap. No se ejecuta `integration_test/supabase_auth_test.dart`: crea usuarios, registra perfiles y provoca bloqueo PIN, por lo que supone escrituras fuera del alcance. No se cambió código, SQL, autenticación, rutas, dependencias ni pantallas; no se hizo commit, push ni cambio de rama.
