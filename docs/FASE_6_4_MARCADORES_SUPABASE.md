# Fase 6.4 — Marcadores geográficos Supabase

Entrega del 2026-11-08, sobre la rama encontrada **main**. Se conservan los cambios pendientes de 6.1–6.3, sin cambiar a feat/mapa-geolocalizacion ni hacer commit/push/merge/rebase. **La integración está implementada; su verificación remota permanece pendiente.**

## Contrato efectivo y módulos presentes

Se contrastaron los documentos 6.1–6.3 con el código y los scripts docs/database/001_esquema_base_v5.sql, 002_complemento_v5.sql, 003_correcciones_mvp.sql e INSTALACION_UNICA_VECIPULSO_MVP.sql.

La definición de puntos_mapa sigue siendo 001:1271–1304, consolidada en el instalador:1288; 002/003 no la reemplazan. Firma:

```sql
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

Es SQL STABLE, SECURITY INVOKER implícito, search_path public,extensions. Las tablas leídas son servicios/categorias_servicio, recursos_criticos, alertas_sos y grupos_apoyo. SELECT y EXECUTE requieren la sesión y políticas existentes. No hay escrituras.

| Capa | Filtro del SQL, además de RLS | Estado/urgencia |
|---|---|---|
| comercio | Servicio activo dentro del radio | activo; urgencia NULL |
| recurso | Disponible, punto no nulo y dentro del radio | disponible; urgencia NULL |
| alerta | sin_verificar/verificada, últimas 24 horas, radio | Estado real y urgencia critica/urgente/normal |
| brigada | Punto no nulo y radio; también incluye grupos voluntarios | activo constante de la RPC; urgencia NULL |

La RPC no devuelve descripción, zona, propietario/proveedor, teléfono ni valoración. El UUID identifica la entidad de esa capa: un comercio refiere al servicio, no al perfil proveedor. No se inventaron esos atributos ni un segundo identificador relacionado. No devuelve favores; buscar_publicaciones_cercanas existe pero no se compone en esta fase.

En este checkout Servicios, Favores y SOS siguen siendo interfaces demo. No se incorporó código de otras ramas ni se enviaron UUID reales a sus detalles demostrativos. Solo se agregó una ficha de lectura de la proyección pública del punto; la navegación completa corresponde a 6.5.

## Archivos y arquitectura

Nuevos:

- lib/features/maps/models/map_point.dart: MapPoint, MapPointLayer, MapPointUrgency, MapPointsResult.
- lib/features/maps/data/map_points_repository.dart: interfaz/adaptador Supabase y errores seguros.
- lib/features/maps/presentation/controllers/map_points_controller.dart: ChangeNotifier de consulta compartido por ambos mapas.
- lib/features/maps/presentation/widgets/map_points_layer.dart: marcadores agrupados, ficha mínima y estados de consulta.
- test/map_points_test.dart: 15 pruebas con fakes y transporte HTTP simulado del SDK real.
- integration_test/supabase_map_points_test.dart: ensayo remoto de solo lectura, deshabilitado por defecto.
- docs/FASE_6_4_MARCADORES_SUPABASE.md.

Ampliados en 6.4:

- lib/main.dart: composición de repositorio y Provider del controlador, usando el mismo SupabaseClient de autenticación.
- lib/features/maps/models/map_origin.dart: metadato local isNeutral, para no consultar desde un centro general ficticio.
- lib/features/maps/presentation/widgets/geographic_map_canvas.dart: coordinación del origen/consulta y capa de puntos.
- neighborhood_map_screen.dart y emergency_map_screen.dart: textos actualizados del mapa conectado. La pantalla normal aclara que búsqueda/filtros aún no aplican a estas capas.
- pubspec.yaml/lock: http 1.6.0 pasa de transitiva a dependencia de desarrollo directa para MockClient. No cambia la versión ni añade una biblioteca de red productiva.
- test/maps_test.dart y test/emergency_dashboard_test.dart: textos de mapas actualizados, sin eliminar casos.

No se modificaron autenticación, GoRouter, SQL, RLS, permisos Android ni otros flujos. Los cambios de esos archivos que ya existían de fases anteriores se preservan.

## Modelos y coordenadas

MapPoint conserva exactamente capa,id,titulo,subtipo,estado,urgencia,lat,lng,distancia_m mediante atributos Dart tipados y toJson con los nombres SQL. Solo cuatro capas y las tres urgencias verificadas. Valida estados retornables según capa, urgencia nullable solo fuera de alertas, UUID, textos obligatorios y distancia int no negativa. Los subtipos son texto: en servicios son nombres del catálogo, no un enum inventado.

GeoCoordinate de 6.2 valida números finitos, latitud [-90,90] y longitud [-180,180]. La RPC ya proyecta ST_Y como lat y ST_X como lng desde geography(Point,4326): el DTO no decodifica WKB ni acepta cadenas numéricas en lugar de números. FlutterMap recibe LatLng(lat,lng). Coordenadas faltantes/malformadas hacen fallar la consulta completa, sin rellenarlas ni conservar una lista parcial.

MapPointsResult.points es inmutable y truncated es metadato calculado por el cliente, no columna SQL. La clave de identidad deriva de capa+UUID, evitando mezclar entidades de distintas tablas. No se conservan campos extra accidentales como PIN/DNI/teléfono en el modelo ni se renderizan.

## Repositorio y rendimiento

SupabaseMapPointsRepository.load(origin, radiusMeters:3000, isActive) ejecuta únicamente puntos_mapa con p_lat,p_lng,p_radio_m. Usa el cliente actual, captura su usuario y comprueba que no cambie antes/después de cada página. Sin sesión rechaza antes de consultar. El radio debe ser positivo y compatible con int de PostgreSQL.

Orden PostgREST explícito por capa ascendente e id ascendente, con nullslast. No depende del orden no garantizado del UNION ALL ni de los valores por defecto del SDK. offset/limit son modificadores de respuesta, no argumentos SQL inventados.

Lee páginas de hasta 100 filas, avanzando por cantidad real recibida, para tolerar un límite API inferior. Acota la lectura a 501 filas brutas: muestra hasta 500 y usa la adicional para señalar resultado incompleto. Deduplica por capa+UUID; una fila repetida sustituye a la anterior. No descarga toda la zona para filtrarla en Flutter. Ante error de página posterior descarta la lista completa.

Cada página tiene timeout de 15 s. Al cambiar consulta, sesión o dispose del controlador, el repositorio descarta la respuesta y no inicia páginas adicionales. Una petición HTTP que ya salió no tiene cancelación nativa garantizada. No hay snapshot transaccional entre páginas: cambios concurrentes pueden producir omisiones o repeticiones; se deduplican y el usuario puede recargar.

El alcance es un radio de 3000 m desde el origen. No se consulta automáticamente por cada pan/zoom ni se inventó bbox. Hay máximo de marcadores y agrupación por coordenada, sin clustering complejo ni infraestructura offline.

## Controlador y origen

El controlador se reutiliza entre mapa normal/SOS. Dos consultas simultáneas con mismo usuario/coordenadas/radio comparten la operación pendiente. Si ya existe éxito o vacío de esa misma consulta, no se repite automáticamente; Actualizar puntos fuerza relectura. Una consulta distinta incrementa generación y evita que una respuesta antigua sobrescriba la actual.

La prioridad del origen es la lectura puntual autorizada de 6.3 y después la referencia de zona/sesión válida de 6.2. Una vista neutral no ejecuta una consulta alrededor de 0,0: muestra originRequired. Si no hay GPS pero sí centro de zona autorizado, carga normalmente. No se pide permiso GPS para consultar.

La ubicación puntual se envía como argumento de lectura cuando es el origen de búsqueda: no se inserta como registro ni se publica a vecinos. El aviso de privacidad junto al botón se actualizó para distinguir consulta de publicación. Los mosaicos continúan recibiendo solo el área visualizada, sin JWT Supabase.

Estados: initial, originRequired, loading, ready, empty, offline, denied, invalid y error. MapPointsFailure convierte fallos de red/timeout, sesión/permiso, formato/coordenadas y servidor a mensajes sin detalles internos. Se limpia el dataset en cada carga/error/cambio de usuario. Las fichas también escuchan el controlador y eliminan títulos antiguos si se descarta el resultado.

## Presentación e interacción

- Servicios: icono storefront azul.
- Recursos: inventario verde.
- Alertas: advertencia roja, urgencia y estado comunitario.
- Grupos: icono groups turquesa.

Las coordenadas coincidentes se agrupan en un marcador con contador, conservando sus coordenadas exactas de la RPC. La ficha enumera cada entidad autorizada de esa celda. No se separan pines con desplazamientos geográficos ficticios. Puntos cercanos que se solapan pueden distinguirse haciendo zoom; no se implementó clustering multiescala.

La ficha muestra título, subtipo, capa, estado/urgencia y distancia desde el origen de consulta. verificada se presenta como Confirmada por vecinos. La disponibilidad no implica reserva ni actualización de stock en tiempo real. No muestra autor, teléfono, domicilio, descripción inexistente o certificación oficial.

MapPointsLayer y MapPointsStatus observan al controlador mediante ListenableBuilder. Recibir datos no reemplaza la cámara ni recrea el proveedor de tiles. Se conservan zoom, navegación y atribución. No hay enlaces a otros módulos todavía. Los filtros/búsqueda visuales preexistentes quedan para 6.5; por ahora se muestran las cuatro capas de la consulta.

## Privacidad y alcance RLS

Según 001:1409,1522,1554,1564 las cuatro tablas tienen SELECT de zona_id=mi_zona(); 1338–1376 establece grants/EXECUTE, 1381–1391 activa RLS. puntos_mapa no es SECURITY DEFINER: cambiar origen o radio no amplía esa autorización. Las restricciones del SQL sobre estado/radio se suman a RLS, no la sustituyen.

Las ubicaciones son ubicacion_aprox, preparadas por aplicar_aproximacion/tg_aproximar mediante rejilla de 0.0015 grados y centro de zona cuando corresponde. No se sustituye una ubicación del proveedor por GPS del visitante ni se aumentan coordenadas autorizadas con datos externos. El redondeo no anonimiza títulos o textos que los usuarios hayan publicado.

No se consulta perfiles completos, contactos, respuestas privadas, vecinos vulnerables ni service_role. El PIN sigue siendo bloqueo de interfaz, no autorización de PostgreSQL. La lectura usa la sesión del vecino y la autoridad final es RLS. La aplicación no asegura seguridad de todo SOS por esta integración: los riesgos SQL previos de cerrar_alerta/confirmaciones_de continúan fuera de alcance.

## Pruebas locales

test/map_points_test.dart verifica:

1. DTO exacto, cuatro tipos, NULL permitidos y descarte de columnas sensibles.
2. Rangos, finitud, orden de ejes, UUID y proyecciones inválidas.
3. SDK real con MockClient: nombre RPC, POST, parámetros exactos, sesión, orden y offset/limit.
4. Respuesta vacía y rechazo previo sin sesión/radio inválido.
5. Red, autorización y JSON inválido con errores seguros.
6. Tope de 500 y detección de truncamiento con una fila más.
7. Fallo de página posterior sin lista parcial.
8. Cargas, caché, actualización, vacío, error y reintento.
9. Dedupe de consulta simultánea y descarte fuera de orden.
10. Cambio de sesión/dispose sin publicación tardía.
11. Sin GPS: marcadores de las cuatro capas, ficha y recarga desde el lienzo.
12. Origen neutral sin consulta, error de red y recuperación sin puntos demo.
13. Coincidencia geográfica sin posiciones inventadas y limpieza de la ficha al descartar datos.

Son 15 casos al desplegar las variantes parametrizadas. Los puntos y JWT de prueba son sintéticos del transporte MockClient; nunca se conectan a Supabase. No se eliminaron tests anteriores ni se confundió esa simulación con RLS real.

| Validación ejecutada | Resultado |
|---|---|
| Formato exclusivo de Dart intervenido | Correcto |
| flutter analyze | Sin incidencias |
| flutter test test/map_points_test.dart --concurrency=1 | 15 aprobadas, 0 fallidas |
| flutter test --concurrency=1 | 159 aprobadas, 0 fallidas, sin omisiones locales; 1 min 46 s |
| git diff --check | Correcto |
| git status | Cambios de esta fase y trabajo anterior preservados; sin staging/commit ni cambio de rama |
| Integración real de puntos/RLS | Pendiente, no ejecutada |
| Android cartográfico/GPS en esta subfase | No repetido; resultados históricos en 6.2/6.3 no acreditan marcadores remotos |

Durante el desarrollo se corrigió una notificación del origen síncrono durante montaje, el orden por defecto del SDK y aserciones del transporte simulado. El orden ahora es explícitamente ascendente y la notificación se difiere fuera del montaje. También se corrigieron avisos de estilo; no quedan incidencias ni pruebas fallidas. No se eliminaron casos para ocultar fallos.

## Lectura remota preparada — integración real pendiente

integration_test/supabase_map_points_test.dart queda deshabilitado por defecto. Requiere dos cuentas Auth sintéticas preexistentes de rol vecino en zonas distintas y puntos sintéticos previamente preparados por el responsable del entorno. No crea usuarios, zonas ni puntos; no llama RPC de escritura.

Configuración en config/supabase.maps.local.json (ya ignorado por el patrón gitignore): SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, MAP_READ_PROJECT_URL igual a la URL autorizada, MAP_READ_ENVIRONMENT=synthetic-read-only, MAP_READ_EMAIL_A/B y MAP_READ_PASSWORD_A/B. No se creó ni se leyó un archivo de credenciales reales para este test.

Después de autorización de esas sesiones, ejecutar:

```powershell
flutter test integration_test/supabase_map_points_test.dart -d <dispositivo> --dart-define-from-file=config/supabase.maps.local.json --dart-define=ALLOW_MAP_READ_CHECK=true
```

El test inicia sesiones de usuario con clave publicable, lee solo su propio perfil para precondiciones, consulta centros y puntos de A/B y repite la consulta de B desde el centro de A. Comprueba resultados no vacíos de los fixtures, UUIDs sin duplicados y ausencia de puntos de A en B. No usa conexión administrativa para acreditar RLS. Las cuentas requieren ser preaprovisionadas; no representa recuperación por email de cuentas anónimas de la app.

Sin autorización/credenciales sintéticas disponibles no se ejecutó este test. No se ejecutaron escrituras remotas, pruebas geográficas reales ni la integración remota de auth. Los escenarios de todas las capas y de denegación requieren fixtures/roles adecuados; el ensayo de dos zonas no certifica por sí solo todas las políticas.

Comprobación manual posterior: desbloquear PIN, abrir mapa sin GPS y verificar origen de zona; recargar, seleccionar cada tipo, revisar fichas y regresar; probar sin puntos, sin red, permiso revocado y coordenadas inválidas con fixtures controlados; confirmar la actualización de estado sin llamadas a funciones de escritura. No crear SOS para probar el mapa en un proyecto compartido.

## Preparación para 6.5

Conectar búsqueda/filtros a contratos disponibles y navegación a detalles reales solo cuando esos módulos estén efectivamente incorporados. El DTO identifica la capa y entidad necesarias, sin convertir ID de servicio en ID de proveedor. Revisar truncamiento, agrupaciones y visibilidad al volver de un detalle. Mantener el orden lat/lng, la referencia de distancias y las diferencias entre datos públicos/privados.

No se avanzó a 6.5 ni se modificó Supabase remoto.
