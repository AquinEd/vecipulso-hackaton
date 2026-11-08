# Fase 6.6 — Cierre técnico de mapa y geolocalización

## Resultado y alcance

Revisión del 2026-11-08. Se contrastaron los documentos 6.1–6.5, los archivos actuales, las pruebas, las rutas y el SQL del repositorio. Se mantuvo la rama encontrada **main**, distinta de `feat/mapa-geolocalizacion`, y todo el trabajo sin confirmar de subfases previas. No hubo staging, commit, push, merge, rebase ni cambios de rama. No se modificaron SQL, RLS, autenticación ni módulos ajenos al mapa.

El módulo cartográfico está implementado y tiene validación local. **El cierre integral es parcial:** faltan lectura geográfica/RLS con cuentas sintéticas remotas, revisión manual Android y detalles reales de otros módulos. El smoke cartográfico Android no valida Supabase ni sustituye la prueba de inicio de sesión/PIN en dispositivo. No se avanzó a Fase 7.

## Estado por subfase

| Subfase | Estado de cierre | Evidencia | Pendientes |
|---|---|---|---|
| 6.1 | Completa | Auditoría, contrato y roadmap contrastados con código/SQL | Confirmar contrato y permisos desplegados antes de producción |
| 6.2 | Completa | FlutterMap, atribución, gestos/cámara y smoke Android | Revisión manual, pinza/rotación y dispositivo físico |
| 6.3 | Parcial | Servicio puntual, permisos mínimos y 16 pruebas locales | Lectura nativa fallida por timeout y diálogo real conceder/denegar/aproximada; ver diagnóstico abajo |
| 6.4 | Parcial | Repositorio RPC, DTO, paginación/RLS por contrato y 15 pruebas locales | Lectura remota y aislamiento real entre zonas |
| 6.5 | Parcial | Cuatro filtros, búsqueda y fichas revalidadas; 15 pruebas locales | Destinos reales de Servicios, SOS, Recursos y Grupos |
| 6.6 | Parcial | Auditoría, corrección de ciclo de vida y tres pruebas adicionales | Recorridos remotos y manuales listados; no se certifica integración completa |

Los documentos históricos describen el estado de cada entrega; por ejemplo, filtros pendientes en 6.4 se implementaron en 6.5. Este informe no interpreta las cifras históricas como nuevas ejecuciones.

## Funcionalidades y recorridos

- `/mapa` y `/sos/mapa` usan `GeographicMapCanvas`, no el dibujo ilustrativo ni puntos demo. FlutterMap permite pan, zoom y recentrado. Los lienzos/catálogos anteriores permanecen como referencia; no se borraron.
- El origen prioriza la última lectura autorizada de la sesión; en su ausencia usa `mi_zona()` y `zonas.centro`, o una vista general neutral expresamente etiquetada. Sin origen válido no se inventan puntos ni se consulta desde una supuesta ubicación personal.
- Solo una pulsación explícita solicita ubicación. El resultado permanece en memoria para esa sesión; no hay stream, historial ni escritura automática de coordenadas.
- Los puntos muestran servicios, SOS abiertos, recursos disponibles y grupos según la proyección y RLS. El filtrado combina capas y texto normalizado sobre el conjunto acotado, sin nuevas consultas.
- La ficha fuerza una lectura autorizada antes de mostrar datos y antes de abrir un destino opcional. No incluye contactos, domicilios ni estadísticas inventadas.
- Errores de mosaicos, centro de zona, GPS y puntos son independientes y tienen mensajes/reintentos. No se ofrecen descargas offline ni se ocultan fallos con pines ficticios.

| Recorrido solicitado | Comprobación | Límite |
|---|---|---|
| A: inicio → mapa → cartografía/zoom/pan | Navegación local y smoke nativo cartográfico | El smoke usa el componente sin cuenta; PIN remoto en Android no repetido |
| B: permiso → posición → cámara | Unitarias del servicio, widgets y prueba nativa descrita abajo | Consentimiento real, precisión reducida y denegación manual pendientes |
| C: servicios → punto → detalle | Filtro/ficha local con UUID sintético | Detalle real no disponible en esta rama |
| D: SOS → alerta → detalle | Filtro/ficha, estados abiertos y retiro de punto bajo mocks | Detalle real y comprobación RLS remota pendientes |
| E: recursos → ficha | Marcador/ficha de proyección pública comprobados localmente | Sin detalle extendido por UUID ni lectura remota |
| F: sin red → error → reintento | Proveedor local fallido y repositorio simulado | Cortar/restaurar red Android real pendiente |
| G: denegar GPS → mapa utilizable | Tests locales de denegación y centro de zona/neutral | Diálogo Android y centro de zona remoto pendientes |

## Corrección dentro de 6.6

`GeographicMapCanvas` observa el ciclo de vida. Al pasar a hidden/paused/detached bloquea nuevas consultas coordinadas desde el lienzo. Al restaurar, solo el mapa visible revalida los puntos; las cargas iguales pendientes se comparten mediante el controlador existente. Se mantienen cámara/filtros y no se inicia una lectura GPS. Una lectura puntual previamente autorizada que termine mientras la app está pausada puede centrarse al restaurar; no se configura seguimiento.

El estado inactive no equivale a segundo plano: un diálogo de permisos puede producirlo y no debe provocar otra consulta ni romper el consentimiento. El observador se elimina en dispose. Se conservan los controles previos de sesión, generación y respuestas tardías.

Android puede detener el dibujo durante paused: no se afirma que un setState haya liberado inmediatamente las imágenes ni que se cancelen HTTP o un fix nativo ya en vuelo. La cámara/mapa se mantienen montados; la cartografía usa la caché existente al regresar. Esta corrección reduce consultas nuevas en segundo plano y actualiza los datos al volver, sin prometer consumo cero.

## Arquitectura, dependencias y SQL

Paquetes directos del mapa ya presentes: `flutter_map 8.3.2`, `latlong2 0.10.1`, `geolocator 14.1.2`, `url_launcher 6.3.3`. Se reutilizan Provider, GoRouter y supabase_flutter del proyecto; no se instalaron paquetes nuevos en 6.6. `http 1.6.0` es dependencia de tests de transporte. Flutter/Dart y configuración Android permanecen como en 6.2–6.3.

El único cliente Supabase se inicializa en `lib/main.dart`. Se inyectan repositorios de centro/puntos y controladores. Los widgets no consultan tablas directamente. AuthController y las guardas PIN de `lib/app/app_router.dart` no se modificaron.

Contrato efectivo revisado: `docs/database/001_esquema_base_v5.sql`, `002_complemento_v5.sql`, `003_correcciones_mvp.sql` y `INSTALACION_UNICA_VECIPULSO_MVP.sql`. La semilla opcional no se ejecutó.

```sql
-- 001:1271; instalador:1288; sin reemplazo posterior en 002/003
public.puntos_mapa(
  p_lat double precision,
  p_lng double precision,
  p_radio_m int default 3000
)
returns table (
  capa text, id uuid, titulo text, subtipo text, estado text, urgencia text,
  lat double precision, lng double precision, distancia_m int
)
```

SECURITY INVOKER implícito; las tablas servicios/categorias_servicio, recursos_criticos, alertas_sos y grupos_apoyo siguen sujetas a sus políticas. Las capas son comercio/recurso/alerta/brigada, no favores. SOS: sin_verificar/verificada, últimas 24 horas. Recurso disponible y brigada activo son etiquetas del contrato, no reserva ni disponibilidad en vivo. No hay parámetros de búsqueda, capa, viewport ni paginación SQL: order/range son modificadores PostgREST.

`mi_zona()` (001:432) obtiene la zona del usuario actual; SELECT nombre,centro de zonas resuelve el origen. `geography(Point,4326)` representa X=longitud/Y=latitud. La RPC devuelve números lat/lng; el centro directo necesita el decoder WKB/EWKB validado. Se validan finitud, rangos y UUID; formatos inválidos fallan, sin coordenadas de relleno. No se llama emitir_alerta, cerrar_alerta ni actualizar_ayuda desde el mapa.

## Privacidad y seguridad

- Sin service_role, clientes administrativos ni lecturas de contactos/perfiles ajenos. No hay logs de PIN, DNI, JWT o GPS en el código del mapa.
- SELECT por zona se sustenta en 001:1410 (servicios), 1523 (alertas), 1555 (recursos), 1565 (grupos); la autoridad sigue en PostgreSQL. El análisis estático y los mocks no acreditan RLS desplegada.
- El trigger de aproximación (001:457–478,550–562) usa una rejilla angular; reduce precisión pero no garantiza anonimato. La ficha indica ubicación aproximada y no publica direcciones exactas. Títulos libres todavía podrían contener datos sensibles; esto exige revisión de contenido, no ampliar campos desde Flutter.
- El GPS propio no es un punto comunitario. Se borra al cambiar identidad/dispose y no se sube como registro. Consultar puntos envía el origen a Supabase; los mosaicos revelan área/IP al proveedor. La app informa esta distinción.
- Los mosaicos en caché pueden revelar áreas consultadas en un dispositivo compartido; no contienen el GPS/UUID del visitante ni los marcadores privados. No se promete anonimato absoluto ni ausencia de datos cartográficos en disco.
- Manifest: INTERNET, ACCESS_COARSE_LOCATION y ACCESS_FINE_LOCATION. Sin BACKGROUND_LOCATION ni foreground service de seguimiento configurado. No se cambiaron permisos en 6.6. Preciso/aproximado se distinguen cuando el sistema informa el nivel.

Defectos SQL preexistentes documentados en 6.1: `cerrar_alerta` (001:961) puede omitir una comprobación por lógica NULL de mi_rol en sesión sin perfil; `confirmaciones_de` (001:1331) no comprueba visibilidad por zona. No se explotan ni se usan en el mapa, pero impiden afirmar seguridad general de SOS. La autoasignación de lider de grupo_miembros se corrige revocando INSERT/DELETE en 003:116–118; falta confirmar que ese parche esté desplegado. Cualquier cambio requiere migración autorizada fuera de este cierre; no se alteró SQL para superar tests.

## Proveedor cartográfico

Se revisó nuevamente la [política oficial de OSM](https://operations.osmfoundation.org/policies/tiles/) el 2026-11-08. Se mantiene HTTPS `tile.openstreetmap.org/{z}/{x}/{y}.png`, atribución visible enlazada, User-Agent nativo `VeciPulso/0.1 (community-map; Android)`, panBuffer 0 y caché nativa de hasta 64 MiB. El SDK interpreta cabeceras HTTP y su fallback es siete días (`flutter_map 8.3.2`, CachedMapTileMetadata.fromHttpHeaders). No se fuerza no-cache, no se descargan ciudades ni se implementan tareas de precarga.

La prueba Android es un smoke breve, no un ensayo de carga contra OSM. Las pruebas de 500 puntos usan capas locales sin HTTP. OSM no garantiza servicio de emergencia; una vista cacheada no acredita disponibilidad offline. Falta acordar proveedor/capacidad/contacto de la publicación y validar web si entra al alcance; en navegador User-Agent/Referer tienen reglas distintas. El endpoint está centralizado pero cambiarlo requiere reconstruir la app actual.

## Rendimiento y límites

- Un controlador compartido para puntos, caché de consulta por origen/radio y coalescencia de solicitudes iguales. Las generaciones/identidad impiden publicar respuestas antiguas; no se mantiene una segunda copia pública de datos sensibles.
- Lecturas ordenadas por capa/id y paginadas de hasta 100 filas; tope de 501 filas brutas para devolver como máximo 500 y avisar truncamiento. Si el servidor limita aún más cada página, habrá más viajes. No existe snapshot entre páginas ni garantía de exhaustividad durante cambios concurrentes.
- Filtros y búsqueda actualizan capa/estado mediante listenables, sin volver a obtener el GPS ni consultar Supabase. Hay agrupación de coordenadas coincidentes y deduplicación por capa+UUID.
- Se añadieron pruebas con 500 puntos coincidentes, 500 posiciones distintas y 100 cambios rápidos de filtro. Comprueban identidad, cardinalidad y consulta única, no FPS ni memoria de producción.
- La selección revalida deliberadamente el conjunto acotado; añade lecturas y puede no recuperar un punto fuera del límite. No se afirma que tal punto haya sido borrado globalmente.
- El smoke acredita apertura/carga/gestos en debug Android; no es un benchmark. No se midieron latencia Supabase, pico de memoria, consumo energético ni FPS profile/release. Quedan pendientes con datos sintéticos controlados; no se inventan cifras.

## Pruebas ejecutadas y pendientes

| Comprobación final | Resultado |
|---|---|
| flutter pub get | Correcto; 13 avisos de versiones nuevas fuera de restricciones, sin actualizar paquetes |
| Formato exclusivo de los tres Dart intervenidos en 6.6 | Correcto |
| flutter analyze | Sin incidencias |
| flutter test test/map_closure_test.dart --concurrency=1 | 3 aprobadas, 0 fallidas |
| flutter test --concurrency=1 | 177 aprobadas, 0 fallidas, 0 omisiones locales; 2 min 45 s |
| git diff --check | Correcto; solo avisos CRLF de registrantes nativos preexistentes |
| git status | Rama main con trabajo previo y cuatro archivos intervenidos en 6.6; sin staging/commit |

Durante el desarrollo se corrigió el uso de await sobre una API síncrona del binding de test y una aserción que suponía que Android renderizaba frames mientras estaba pausado. Los tres casos finales verifican el comportamiento efectivo sin ocultar fallos ni prometer cancelación de HTTP. Una suite intermedia coincidió con la restauración de la prioridad experimental y conservó código de prioridad alta compilado, produciendo tres discrepancias con la expectativa medium en location_test. Esa ejecución se descartó como validación final y se repitió con el código estable, sin modificar las expectativas originales: build/phase_6_6_validacion_final.log confirma 177 aprobadas y 0 fallidas en 2 min 45 s. El análisis estático se repitió después de la última modificación del harness nativo y terminó sin incidencias.

### Android efectivamente ejecutado

Emulador Pixel_6 / emulator-5554, Android 17 API 37, android-x64. Se arrancó el emulador disponible y se construyó/instaló el APK de prueba.

| Ensayo nativo separado de la suite local | Resultado |
|---|---|
| `map_tiles_test.dart`, ALLOW_MAP_TILE_CHECK=true | 1 aprobado: mosaico decodificado, atribución, zoom, drag y recentrado; 14 s de test, más compilación/instalación |
| `map_device_location_test.dart`, ALLOW_NATIVE_MAP_LOCATION_CHECK=true | 1 fallido: se esperaba LocationStage.ready y se obtuvo LocationStage.timeout; no se confirmó posición ni centrado GPS nativo |
| RLS/puntos Supabase reales | No ejecutado; sin cuentas sintéticas autorizadas/configuración de ensayo |

Comandos de ejecución:

```powershell
flutter test integration_test/map_tiles_test.dart -d emulator-5554 --dart-define=ALLOW_MAP_TILE_CHECK=true
flutter test integration_test/map_device_location_test.dart -d emulator-5554 --dart-define=ALLOW_NATIVE_MAP_LOCATION_CHECK=true
```

La prueba GPS usa el servicio Geolocator real y el mismo lienzo, sin cuentas ni Supabase ni tráfico de mosaicos. Su precondición es ubicación global habilitada y permisos concedidos externamente **solo al emulador de pruebas**. Flutter puede reinstalar el paquete y restablecerlos: el harness anuncia WAITING_FOR_TEST_LOCATION_PERMISSION y espera hasta 30 s a que el responsable configure esos permisos; no los concede ni abre un diálogo automáticamente. Se usó adb pm grant para COARSE/FINE del paquete com.example.hackaton_veci_pulso en emulator-5554 y una referencia sintética mediante emu geo fix (longitud -77, latitud -12, altitud 0, ocho satélites). Se repitió la inyección durante unos segundos desde el host, no desde la app; no constituye seguimiento implementado en Flutter.

El primer intento GPS falló por permisos aún no preparados; después de resolver esa precondición, la lectura agotó el límite de 20 s. Se investigó el proveedor Android y se repitió con la referencia sintética inyectada durante la adquisición. También se ensayó temporalmente prioridad alta: persistió el timeout. Esa hipótesis se descartó y **se conservó LocationAccuracy.medium y las pruebas originales**; no se modificó su expectativa para aceptar un resultado falso. La causa nativa no quedó confirmada: no se atribuye sin evidencia exclusivamente al emulador ni se certifica que otro dispositivo vaya a funcionar.

El caso opt-in sigue fallando en este entorno y conserva la exigencia de obtener una posición válida. El error seguro fue observado; no equivale a aprobar el recorrido GPS. Hace falta repetirlo en un emulador/proveedor configurado y dispositivo físico, revisar Google Play Services/proveedor y, si persiste, corregir el adaptador con evidencia antes del cierre integral. No se aumenta la prioridad/potencia en producción sin un beneficio demostrado.

**Balance actual de casos únicos:** 177 locales aprobados + 1 cartográfico Android aprobado = **178 aprobados**; **1 caso nativo GPS fallido**, repetido durante el diagnóstico (no contar cada repetición como un caso nuevo). Las comprobaciones remotas y manuales de abajo no se ejecutaron. Los avisos de JDK/Gradle no impidieron construir e instalar el APK; no son la causa confirmada del timeout GPS.

La suite local incluye autenticación/PIN, persistencia simulada, navegación general, modos, servicios/favores demostrativos y todos los tests geográficos. Los tests de transporte usan el SDK real contra MockClient, no internet ni credenciales. No se eliminaron ni debilitaron pruebas anteriores. La ejecución de suites dirigidas está incluida en la cifra de la suite completa y no debe sumarse dos veces.

Pendientes no confundidos con aprobaciones: `integration_test/supabase_map_points_test.dart` de lectura remota con dos sesiones sintéticas y zonas distintas; integración remota de auth; diálogo real Android (denegar/permanente/aproximada); corte/recuperación de red en dispositivo; pinza/rotación/accesibilidad manual; minimizar/restaurar mediante sistema Android real; dispositivo físico; perfiles de rendimiento. No se leyeron credenciales locales ni se ejecutaron escrituras de datos remotos para esta fase.

La integración geográfica sigue cerrada por defecto. Requiere entorno autorizado, cuentas preexistentes y config local ignorado según 6.4:

```powershell
flutter test integration_test/supabase_map_points_test.dart -d emulator-5554 --dart-define-from-file=config/supabase.maps.local.json --dart-define=ALLOW_MAP_READ_CHECK=true
```

No usar credenciales administrativas ni crear una alerta real para probar el mapa. Los recorridos reales de detalle también dependen de integrar primero sus módulos.

## Android: ejecución y procedimiento manual

```powershell
flutter devices
flutter emulators --launch Pixel_6
flutter run -d emulator-5554 --dart-define-from-file=config/supabase.dev.json
```

No versionar ni mostrar el JSON. En la app: iniciar/restaurar sesión sintética, desbloquear PIN y entrar a Mapa. Verificar centro de zona o vista neutral; sin GPS debe seguir habiendo pan/zoom. Pulsar ubicación y comprobar aproximada, precisa, denegada/permanente, GPS apagado y timeout. Actualizar solo mediante acción explícita; cambiar referencia del emulador sin pulsar no debe seguir el movimiento.

Con puntos sintéticos autorizados, combinar/restaurar filtros, seleccionar cada capa y comprobar estado/ficha. No enviar UUID de Supabase a detalles demo. Cortar red y mover a una zona sin tiles cacheados; comprobar aviso y reintentar tras recuperar red. Pausar/restaurar y cambiar normal/SOS manteniendo cámara/filtros. Probar Atrás y revocación de sesión sin datos de la cuenta anterior. Estos pasos siguen pendientes donde no existe evidencia nativa expresa arriba.

## Dependencias entre ramas y revisión Git

La ruta `/servicios/:id` existe pero ProviderDetailScreen busca demoServices. SOS confirmación/seguimiento no admiten detalle de alerta por UUID. Recursos no tiene detalle real y `/sos/brigadas` muestra catálogo demo. Favores muestra muro demo y no figura en puntos_mapa. No se hizo merge ni se copiaron módulos de compañeros.

Después de integración autorizada: revisar rutas y repositorios reales, registrar callbacks MapPointNavigation por capa con UUID de entidad y GoRouter existente, verificar acceso/registro inexistente en el destino y regresar conservando cámara/filtros. Hasta entonces no se muestra Ver detalles falso. La ruta fixture usada en tests nunca se registra en producción.

Archivos intervenidos exclusivamente en 6.6:

- `lib/features/maps/presentation/widgets/geographic_map_canvas.dart`: observador y restauración segura.
- `test/map_closure_test.dart`: tres pruebas locales de cierre/carga acotada/ciclo de vida.
- `integration_test/map_device_location_test.dart`: prueba opt-in de lectura nativa sin Supabase.
- `docs/FASE_6_6_CIERRE_MAPA.md`: este cierre.

El árbol además conserva los archivos de 6.1–6.5 listados en esos documentos: main/composición, manifiesto Android, pubspec/lock, registrantes nativos, pantallas del mapa normal/SOS, modelos/repositorios/controladores, widgets, pruebas e integraciones geográficas. No atribuir todo git diff a esta subfase ni descartar cambios anteriores. Los archivos de autenticación, router, Servicios, Favores y SQL no muestran modificaciones por esta entrega. Avisos LF/CRLF de registrantes generados no son errores de espacios.

**Recomendación:** apto para revisión y propuesta de commit/PR del alcance cartográfico, tras revisar íntegramente el árbol y resolver la rama de entrega con el responsable. No ejecutar un commit indiscriminado en main. No presentar como integración comunitaria completamente validada ni recomendar merge de cierre integral hasta resolver la prueba GPS nativa fallida, comprobar RLS/lectura remota y dependencias de destinos. Los riesgos SQL de SOS requieren revisión separada antes de una liberación que use esas operaciones.

## Preparación para Fase 7, sin implementarla

Entregar este informe, inventario de cambios y pendientes al equipo; acordar alcance de release, entorno sintético y proveedor cartográfico; resolver integración de módulos y evidencias de privacidad/RLS. No se presupone contenido funcional de Fase 7 ni se desarrolla esa fase en esta ejecución.
