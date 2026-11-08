# Fase 5.5 — Recursos críticos y grupos de apoyo

Fecha: 2026-11-08. Alcance: consulta y detalle, sin administración, mapas, GPS ni escrituras remotas. Se conserva la rama encontrada `feat/servicios-visto-bueno` (distinta de `feat/modo-sos`) y el trabajo sin confirmar de las fases anteriores. No se realizó commit, cambio de rama ni modificación de SQL, autenticación, dependencias o rutas.

## Contrato efectivo y autorización

Se contrastaron los documentos 5.1–5.4 con `docs/database/001_esquema_base_v5.sql`, `002_complemento_v5.sql`, `003_correcciones_mvp.sql` y su consolidación en `INSTALACION_UNICA_VECIPULSO_MVP.sql`. El orden efectivo es 001 → 002 → 003; la semilla 004 no concede autorización adicional. No se comprobó el catálogo del proyecto remoto.

| Entidad | Campos utilizados y significado | Fuente |
|---|---|---|
| `recursos_criticos` | `id` UUID PK; `zona_id` UUID FK zonas, `propietario_id` UUID FK perfiles; `tipo` enum tipo_recurso; `cantidad` int NOT NULL DEFAULT 1 CHECK > 0; `descripcion` text nullable; `ubicacion_aprox` geography(Point,4326) nullable; `disponible` boolean NOT NULL DEFAULT true; `creado_local` timestamptz nullable; `creado_en` timestamptz NOT NULL DEFAULT now() | 001:261 |
| `grupos_apoyo` | `id` UUID PK; `zona_id` UUID FK zonas; `nombre` text y `tipo` tipo_grupo NOT NULL; `especialidad`, `sector`, `contacto` text nullable; `integrantes` int nullable CHECK >= 0; `ubicacion_aprox` geography(Point,4326) nullable | 001:308 |
| `zonas` | `id`, `nombre` para resolver la etiqueta del detalle. Catálogo con SELECT permitido | 001:108 |
| `grupo_miembros` | PK compuesta grupo_id/perfil_id, FKs a grupos/perfiles; `rol` integrante/lider y `estado` activo/inactivo. No se consulta ni modifica desde este directorio | 002:48 |

Tipos de recurso: agua, botiquin, herramientas, transporte, espacio_seguro, otro. Tipos de grupo: brigada, voluntarios. No hay columna de nombre en recursos: la interfaz usa el tipo como título. No hay descripción ni estado de disponibilidad del grupo: se muestra su especialidad cuando existe, sin inventar actividad o certificación.

`recursos_lectura` y `grupos_lectura` permiten SELECT a authenticated únicamente cuando `zona_id = public.mi_zona()` (001:1554–1565). Los grants de 001:1350 en adelante se evalúan junto con esas políticas. No se envía una zona elegida por el cliente como autorización ni se amplía la consulta mediante joins de perfiles. Una fila invisible y una inexistente se presentan como registro no disponible.

El SQL permite escrituras de recursos bajo propiedad y columnas limitadas, pero esta fase no expone ninguna. Los grupos son de solo lectura. Los índices incluyen GiST de ubicaciones (001:385–386), recursos por zona/disponibilidad y propietario (001:406–407) y grupos por zona (001:414). El trigger `tg_aproximar` se instala para ambas entidades (001:554); usa rejilla 0.0015 grados y centro de zona cuando corresponde. La interfaz no solicita coordenadas ni representa una posición exacta.

## Roles y privacidad

La versión 002 de `miembros_crear` comprueba usuario y zona, pero no obliga a `rol = 'integrante'`: aislada permitiría autoasignarse lider. La versión efectiva 003:115–118 revoca INSERT/DELETE a authenticated y elimina miembros_crear/miembros_borrar; no existe un grant de UPDATE de membresías. El instalador único incorpora esa corrección en 2220–2223. Por ello no se prepara una migración redundante: la corrección requerida ya está versionada. Si un entorno tiene solo 001+002, debe revisarse y aplicar 003 mediante el proceso de despliegue autorizado; esta fase no la aplica.

No hay botones de unirse, nombrar líder, editar roles o administrar grupos. La lectura de miembros que permite 002:347 no se usa para exponer integrantes individuales. Se conserva únicamente el conteo descriptivo `integrantes`, que no implica una consulta de personas ni presencia en tiempo real.

`grupos_apoyo.contacto` es un campo público para vecinos de la zona según su política SELECT, sin vínculo con `perfiles.telefono` ni `compartir_telefono`. Solo se muestra ese contacto publicado por el catálogo. Si falta, se muestra «Contacto no publicado». No se consultan teléfonos de perfiles, DNI, puntajes, roles, líderes ni datos de voluntarios. El propietario UUID del recurso queda en el modelo existente y no se renderiza. La ubicación se expresa como publicada/no publicada y la zona por nombre; no se muestran coordenadas numéricas ni se crean mapas.

## Pantallas y navegación

- `/sos/tablero`: `LiveSosDashboard` añade accesos a Recursos críticos y Grupos y Brigadas.
- Recursos críticos: diálogo de catálogo desde el tablero, con detalle por UUID en otro diálogo. Regresar cierra el catálogo y conserva el tablero.
- `/sos/brigadas`: `BrigadesScreen` reutiliza la ruta existente y abre el catálogo real cuando existe el repositorio inyectado. Tanto el botón de regreso como Android regresan a `/sos/tablero`.
- `SosCatalogScreen`: listado paginado, filtros por tipo, búsqueda de grupo por nombre, detalles, carga, vacío, mensajes seguros y actualización/reintento.

La rama histórica sin repositorio conserva los datos visuales existentes con el aviso explícito «Grupos de demostración · Contactos no disponibles» para las pruebas y el modo demostrativo. Con el repositorio Supabase configurado se consulta exclusivamente el backend; un error o lista vacía nunca activa esos datos como sustituto. No se añadieron registros ficticios a Supabase. Si el proyecto remoto contiene la semilla de grupos demostrativos, su revisión editorial queda pendiente: no existe un indicador SQL que permita al cliente distinguirlos de otros registros.

`disponible` y `cantidad` describen el dato almacenado: la pantalla dice «según el registro» y advierte que fue publicado por un vecino. No hay reserva, consumo, seguimiento, garantías de stock, suscripción Realtime ni promesa de disponibilidad actual. Actualizar vuelve a consultar al servidor.

## Arquitectura y consultas

Se reutilizan `CriticalResource`, `SupportGroup`, `SosRepository`, `SupabaseSosRepository`, `SosFailure` y `SosController`. El repositorio usa el cliente ya inicializado, nunca service_role. No existen consultas Supabase dentro de widgets.

| Método añadido | Consulta y parámetros |
|---|---|
| `resourcePage(offset, type)` | SELECT recursos_criticos; filtro opcional `tipo = type.name`; orden creado_en descendente, id; range offset…offset+49 |
| `groupPage(offset, type, query)` | SELECT grupos_apoyo; tipo opcional; nombre ILIKE con texto escapado para %, _ y barra inversa; orden nombre,id; range offset…offset+49 |
| `resourceDetail(id)` | SELECT recursos_criticos WHERE id = UUID, single |
| `groupDetail(id)` | SELECT grupos_apoyo WHERE id = UUID, single |
| `zoneName(id)` | SELECT nombre FROM zonas WHERE id = UUID, maybeSingle |

No es necesaria una RPC para estas lecturas: RLS determina las filas accesibles. Se mantienen los métodos resources/groups de 5.2 por compatibilidad. Offsets negativos y UUID malformados se rechazan. Los detalles vuelven a consultar el registro, sin asumir que sigue existiendo o visible después del listado. Un error al resolver la zona también muestra error y reintento; no confirma un detalle incompleto como si toda su consulta hubiese funcionado.

`SosCatalogController` vive en controllers/sos_controllers.dart, depende de la interfaz inyectable y combina listas tipadas mediante CatalogData. Hereda las generaciones de lectura, limpieza durante cada carga y protección tras dispose. La pantalla usa ListenableBuilder sobre el ChangeNotifier, coherente con los controladores Provider existentes. Un filtro nuevo invalida resultados anteriores; búsqueda con debounce 250 ms. Anterior/Siguiente navegan páginas de 50; se presenta página vacía si la página siguiente ya no tiene registros. No se calculan totales inexistentes.

## Archivos de esta subfase

Creado:

- `lib/features/emergency/presentation/screens/sos_catalog_screen.dart`.
- `test/sos_catalog_test.dart`.
- `docs/FASE_5_5_RECURSOS_BRIGADAS.md`.

Ampliados, respetando el trabajo previo:

- `lib/features/emergency/data/sos_repository.dart`: lecturas paginadas, detalles y nombre de zona.
- `lib/features/emergency/presentation/controllers/sos_controllers.dart`: controlador del catálogo.
- `lib/features/emergency/presentation/screens/sos_alert_views.dart`: accesos desde el tablero real.
- `lib/features/emergency/presentation/screens/brigades_screen.dart`: selección de catálogo real mediante repositorio inyectado.

`main.dart`, emergency_actions_screen.dart, emergency_dashboard_screen.dart y el resto de archivos SOS ya tenían cambios de fases anteriores; no se atribuyen a 5.5 ni se descartan. Git muestra los archivos nuevos de esas fases todavía sin seguimiento.

## Pruebas y límites de verificación

`test/sos_catalog_test.dart` contiene seis pruebas locales con repositorios simulados y transporte HTTP simulado del SDK:

1. Respuestas fuera de orden y ausencia de notificaciones después de dispose.
2. Contacto público del grupo, ruta /sos/brigadas y navegación de regreso al tablero autenticado.
3. Recursos, detalle por UUID, cantidad/disponibilidad registrada, ubicación aproximada sin coordenadas y filtro por tipo.
4. Vacío, errores de red/autorización, reintento y detalle no disponible con recuperación.
5. Grupos sin datos opcionales, contacto ausente, búsqueda, filtro y ausencia de controles de liderazgo.
6. GET a tablas exactas, parámetros de filtros y paginación, sin consultas de perfiles/membresías ni escrituras.

La protección efectiva de roles se verificó por lectura de SQL y ausencia de operaciones de administración en la capa conectada; una prueba de widgets no demuestra que RLS esté desplegada. Pendientes en un entorno autorizado: dos cuentas reales de zonas iguales/distintas, lecturas denegadas, aislamiento por zona y rechazo real de INSERT/UPDATE de roles. No se realizaron lecturas ni escrituras remotas en esta subfase. No se comprobó Android físicamente.

## Resultado de validación

| Comprobación | Resultado |
|---|---|
| dart format sobre los seis Dart modificados | Correcto, sin cambios pendientes de formato |
| flutter analyze | Sin incidencias |
| flutter test test/sos_catalog_test.dart --concurrency=1 | 6 aprobadas, 0 fallidas |
| flutter test --concurrency=1 | 180 aprobadas, 0 fallidas, sin pruebas locales omitidas |
| git diff --check | Correcto |
| Revisión adicional de archivos sin seguimiento | Sin espacios finales ni marcadores de conflicto |
| git status | Trabajo anterior conservado; archivos de esta subfase listados arriba, sin commit |

No quedan errores nuevos en análisis ni en la suite local. No se ejecutaron los dos tests remotos existentes en integration_test (autenticación/servicios), ni la comprobación manual de SOS con sesiones reales; esta validación no demuestra RLS remota. Las limitaciones de seguridad de otras RPC SOS documentadas en 5.1 permanecen fuera del alcance de esta lectura de catálogos. La Fase 5.5 queda implementada y validada localmente, pendiente de comprobación remota autorizada y Android. No se avanza a 5.6.
