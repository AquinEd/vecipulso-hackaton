# Fase 6.5 — Filtros y navegación del mapa

## Alcance y estado real

Se implementaron filtros sobre puntos autorizados, selección con ficha pública revalidada y una interfaz inyectable de navegación por capa. Se conservaron cartografía, ubicación puntual, Provider, GoRouter y protección de sesión/PIN.

La rama encontrada es `main`, no `feat/mapa-geolocalizacion`. No se cambió de rama. El árbol ya contenía cambios de 6.1–6.4 y archivos sin seguimiento; se preservaron. No se modificaron SQL, autenticación, dependencias ni rutas productivas durante 6.5. No se realizaron commit, push, merge, rebase ni escrituras remotas.

**Los detalles reales de otros módulos no están integrados en esta rama. No se activó ningún enlace productivo a un detalle demostrativo.** La navegación con UUID se comprobó solamente con un destino de prueba inyectado. Los filtros y las fichas son utilizables con el repositorio geográfico existente; los recorridos entre módulos quedan sujetos a las dependencias indicadas abajo. No se avanzó a 6.6.

## Contrato y filtros

Se mantiene `public.puntos_mapa(p_lat double precision, p_lng double precision, p_radio_m integer DEFAULT 3000)`, en `docs/database/001_esquema_base_v5.sql:1271`, función `puntos_mapa` (sin redefinición posterior en 002/003). Véase el contrato efectivo y referencias detalladas de `FASE_6_1_CONTRATO_GEO_SUPABASE.md` y `FASE_6_4_MARCADORES_SUPABASE.md`.

La proyección usada es `capa, id, titulo, subtipo, estado, urgencia, lat, lng, distancia_m`. No incluye zona, descripción, teléfono, propietario ni estadísticas. El origen/radio siguen enviándose a la RPC; no existen parámetros de categoría, búsqueda textual ni viewport en esa función.

| Literal backend | Filtro visual | Origen |
|---|---|---|
| comercio | Servicios | servicios y categorias_servicio |
| alerta | Alertas SOS | alertas_sos abiertas de las últimas 24 horas |
| recurso | Recursos críticos | recursos_criticos disponibles |
| brigada | Grupos de apoyo | grupos_apoyo con ubicación |

No se agrega Favores: `puntos_mapa` no devuelve esa capa. La existencia de `buscar_publicaciones_cercanas` no significa que sus resultados ya formen parte del mapa. Incorporarla requeriría un alcance explícito y su propio contrato/modelo.

El mapa normal conserva búsqueda y leyenda con casillas; el SOS usa chips compactos. Ambos admiten combinar categorías, excluir todas, mostrar todas y restaurar. En SOS, tocar una categoría desde Todos la aísla; después se pueden combinar. `Mostrar todos` conserva el texto de búsqueda; `Restaurar filtros` limpia búsqueda y vuelve a habilitar todas las capas.

Se busca por título y subtipo, ignorando mayúsculas y tildes. Es un filtrado local sobre el conjunto autorizado ya cargado, limitado por el repositorio a 500 puntos, con aviso de truncamiento. No se descargan nuevas tablas ni datos privados para filtrar; no se promete una búsqueda exhaustiva de toda la comunidad. Cambiar filtros no dispara RPC ni GPS. Se distinguen consulta vacía, ausencia de coincidencias, carga y error; la actualización manual/reintento mantiene los filtros.

Cada pantalla posee su controlador de filtros; el mapa normal y el SOS no mezclan selecciones. La actualización conserva filtros y cámara. Se corrigió un recentrado involuntario al regresar de una ruta: solo una nueva lectura de ubicación pendiente o la acción explícita de centrado mueve la cámara.

## Selección y ficha

Los marcadores se filtran antes de agrupar puntos coincidentes. La ficha conserva claves `capa:id`, no una copia permanente de datos. Al abrirla fuerza la consulta actual del repositorio usando el origen/radio capturados y muestra carga hasta obtener respuesta. Así, una alerta cerrada, un registro eliminado o una denegación dejan de presentarse como puntos disponibles.

La ficha muestra únicamente título, capa, subtipo, estado, urgencia cuando existe y distancia devuelta por la RPC **desde el origen de consulta**. No se inventan direcciones, zona, descripciones, tiempos de viaje, disponibilidad en tiempo real ni distancias de recorrido. El estado SOS `verificada` se expresa como confirmación vecinal. Se aclara que la ubicación es aproximada y que la disponibilidad registrada no reserva recursos.

Antes de invocar un destino también se revalida el punto. Si desapareció, falló la red o se perdió autorización, no navega. Se ofrecen actualización y cierre; se impiden aperturas repetidas mientras hay una operación pendiente. Un error de callback se muestra como mensaje seguro, sin exponer la excepción original. El indicador de GPS propio no intercepta pulsaciones sobre un marcador público coincidente.

La revalidación vuelve a usar la consulta acotada de puntos, no una RPC inventada de detalle. Añade lecturas deliberadas al seleccionar/abrir; el controlador comparte cargas idénticas pendientes y descarta respuestas antiguas. La consulta paginada no constituye un snapshot transaccional. Un punto ausente del conjunto acotado se trata como no disponible en esa consulta, sin afirmar que fue eliminado de la base.

## Rutas disponibles y bloqueos entre módulos

Verificación: `lib/app/app_router.dart`, `lib/app/app_routes.dart` y las implementaciones actuales de cada destino.

| Módulo | Situación en esta rama | Integración desde el mapa |
|---|---|---|
| Servicios | Existe `/servicios/:id`, pero `features/services/presentation/screens/provider_detail_screen.dart` busca en `demoServices` | Bloqueada para UUID de Supabase; no convertir UUID en ID demostrativo |
| SOS | `/sos/confirmacion` y `/sos/seguimiento` usan categorías/datos demostrativos, no detalle por UUID | Falta ruta estable de detalle autorizado de alerta |
| Recursos | No hay detalle real por UUID en el router | Falta pantalla/ruta de detalle real |
| Grupos | `/sos/brigadas` es directorio demostrativo, no detalle de un grupo por UUID | Falta detalle público real |
| Favores | `/favores` y `/favores/ampliado` son muros demostrativos; tampoco hay capa en esta RPC | Sin integración de puntos ni detalle por UUID |

Cuando no hay destino registrado, la ficha indica que el detalle del módulo no está disponible y no ofrece un botón engañoso. No se copiaron carpetas de otras ramas ni se reconstruyeron módulos.

`MapPointNavigation` permite inyectar callbacks `service`, `alert`, `resource` y `group`, todos opcionales. Cada callback recibe `BuildContext` del mapa y el `MapPoint` recién validado; el UUID de entidad es `point.id`, no un ID de perfil. Su valor por defecto no registra destinos. Cuando se integre una ruta real, proporcionar esta dependencia por Provider y navegar con el GoRouter ya protegido. El destino deberá volver a comprobar su acceso y resolver registro inexistente, porque la autorización puede cambiar después de consultar el mapa. No se debe registrar el callback solo porque exista una ruta demostrativa.

La prueba `/fixture/:id` existe exclusivamente dentro del test; no se agregó al router de la aplicación. Demuestra transporte de UUID y regreso con cámara/filtros/GPS conservados, no integración real con Servicios o SOS.

## Archivos de esta subfase

Nuevos:

- `lib/features/maps/presentation/controllers/map_filters_controller.dart`: filtros y búsqueda reactivos.
- `lib/features/maps/presentation/navigation/map_point_navigation.dart`: destinos opcionales por capa.
- `lib/features/maps/presentation/widgets/map_filters_panel.dart`: casillas/chips y búsqueda reutilizables.
- `lib/features/maps/presentation/widgets/map_point_style.dart`: estilos comunes extraídos de marcadores.
- `lib/features/maps/presentation/widgets/map_point_summary.dart`: ficha revalidada y navegación opcional.
- `test/map_filters_navigation_test.dart`: pruebas deterministas con repositorio, ubicación y destino simulados.
- `docs/FASE_6_5_FILTROS_NAVEGACION.md`: este documento.

Adaptados (algunos ya eran archivos sin seguimiento de fases anteriores):

- `lib/features/maps/presentation/controllers/map_points_controller.dart`: refrescar consulta vigente.
- `lib/features/maps/presentation/widgets/map_points_layer.dart`: filtrado, selección y conteos.
- `lib/features/maps/presentation/widgets/geographic_map_canvas.dart`: recibir filtros, conservar cámara y permitir pulsar puntos bajo el indicador propio.
- `lib/features/maps/presentation/screens/neighborhood_map_screen.dart`: conectar controles al mapa normal.
- `lib/features/emergency/presentation/screens/emergency_map_screen.dart`: conectar controles al mapa SOS, sin alterar emisión/ayuda.
- `test/maps_test.dart`, `test/emergency_map_test.dart`, `test/map_points_test.dart`: adaptar controles y revalidación sin eliminar casos anteriores.

Los cambios existentes en `lib/main.dart`, Android, pubspec y registrantes nativos pertenecen a subfases previas, no se agregaron en 6.5.

## Privacidad y seguridad

Se usa el cliente y la sesión existentes. La RPC conserva RLS por zona de cada tabla; Flutter no concede permisos ni evita políticas. Los modelos retienen solamente la proyección pública; no se leen perfiles ni contactos adicionales. No se muestran DNI, PIN, JWT o teléfonos. La ficha no publica la posición GPS local ni un historial.

Las posiciones del contrato están aproximadas por triggers SQL; la UI no las presenta como domicilios exactos. La distancia no identifica necesariamente la ubicación del vecino: sin GPS parte del centro autorizado de su zona. El radio no permite saltarse RLS. No se añade service_role ni se cambia la autenticación/PIN.

## Pruebas y validación

Las 15 pruebas nuevas cubren las cuatro capas, combinaciones, Todos/restauración, búsqueda, vacío, cambios rápidos sin RPC, ficha pública, destino ausente, registro retirado, sesión denegada, red/reintento, UUID real sintético, regreso, actualización sin duplicados y superposición con GPS. Los repositorios/ubicación están simulados y no utilizan internet. Las pruebas anteriores cubren concurrencia de consultas, coordenadas, autenticación y permisos puntuales.

| Comprobación | Resultado |
|---|---|
| Formato exclusivo de los 14 archivos Dart intervenidos | Correcto |
| `flutter analyze` | Sin incidencias |
| `flutter test test/map_filters_navigation_test.dart --concurrency=1` | 15 aprobadas, 0 fallidas |
| Suite dirigida de mapas y marcadores anteriores | 23 aprobadas, 0 fallidas |
| `flutter test --concurrency=1` | 174 aprobadas, 0 fallidas, sin omisiones locales; 2 min 43 s |
| `git diff --check` | Correcto; avisos CRLF de registrantes nativos preexistentes, sin errores de espacios |
| `git status` | Árbol con trabajo previo y cambios de esta fase preservados, rama main; sin staging ni commit |
| Integración real de puntos/RLS y revisión manual Android | Pendientes, no ejecutadas |

Durante la implementación se corrigieron dos avisos de estilo de las pruebas, una aserción de URI del GoRouter simulado y el recentrado al regresar al mapa. La ejecución final no presenta incidencias de análisis ni fallos nuevos. No se eliminaron casos para obtener ese resultado.

No se ejecutaron lecturas reales de puntos/RLS ni pruebas manuales Android en esta subfase. Permanece preparado `integration_test/supabase_map_points_test.dart` según 6.4, deshabilitado por defecto y con cuentas sintéticas autorizadas como requisito. No se ejecutaron escrituras remotas. Tampoco se ejecutaron recorridos reales hacia módulos que no están integrados.

Comprobación manual Android pendiente: desbloquear PIN, abrir mapa con/sin GPS, combinar/restaurar filtros, tocar puntos coincidentes y comprobar fichas, desconectar red/reintentar, volver entre modo normal y SOS. Cuando los módulos estén integrados, probar UUID existente/inexistente y sesión revocada en cada destino, luego regresar sin perder filtros/cámara. No emitir alertas para esta comprobación.

## Preparación para 6.6

Integrar únicamente destinos reales autorizados cuando sus ramas se incorporen por el responsable; verificar sus pantallas y repositorios antes de activar callbacks. Ejecutar la lectura sintética remota de dos zonas y la revisión manual Android. Revisar límites y estado de puntos al regresar de detalles. Estos pendientes impiden afirmar un recorrido real completo entre módulos, pero no requieren inventar rutas ni eludir RLS. La presente ejecución se detiene en 6.5.
