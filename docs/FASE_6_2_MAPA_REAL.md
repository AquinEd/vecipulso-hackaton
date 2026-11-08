# Fase 6.2 — Cartografía interactiva real

Entrega del 2026-11-08. Rama encontrada y conservada: **main**, distinta de feat/mapa-geolocalizacion. Al comenzar había únicamente tres documentos de auditoría 6.1 sin seguimiento; se preservaron sin cambios. No se hizo commit, push, merge, rebase ni cambio de rama.

## Implementación

Los mapas normal /mapa y SOS /sos/mapa utilizan ahora GeographicMapCanvas con FlutterMap. Se sustituyó el lienzo ilustrativo del recorrido productivo, sin superponer los marcadores ficticios ni el óvalo fijo de riesgo a cartografía geográfica. Se conservan encabezados, paleta, barra inferior, modo SOS, regreso y preferencias de accesibilidad.

El componente permite pan táctil, zoom mediante gestos nativos de flutter_map y botones Acercar/Alejar, más Centrar vista inicial. La cámara se conserva en el estado del widget mientras la navegación mantenga la pantalla montada. La altura está acotada para evitar un mapa sin límites dentro del scroll. Los controles se habilitan cuando la cámara está lista y el zoom queda entre 2 y 19. El centro se limita al rango de latitud representable por Web Mercator al dibujar.

No se conectó puntos_mapa ni se implementaron marcadores Supabase, detalles de entidades, GPS ni seguimiento. La búsqueda y selección de categorías se conservan como estado de interfaz preparado para conectar capas; el texto indica que los puntos comunitarios siguen pendientes. No afectan aún a entidades geográficas. No se presentan resultados ficticios como reales.

Los archivos anteriores de datos demo y los lienzos de referencia no se borraron: permanecen disponibles para diseño/tests, pero las dos pantallas productivas ya no los usan. HelpRoutePreview sigue siendo una demostración independiente de seguimiento y no fue modificado.

## Bibliotecas y composición

Dependencias directas fijadas:

- flutter_map 8.3.2: cartografía, cámara, tiles y caché nativa.
- latlong2 0.10.1: coordenadas LatLng del lienzo.
- url_launcher 6.3.3: enlace de atribución. Ya existía transitivamente y se declara directamente porque ahora se importa en este módulo.

flutter pub get resolvió las versiones con Flutter 3.47.9/Dart 3.13.7. Se incorporaron las dependencias transitivas requeridas, como path_provider y proyección. No se añadieron geolocator, PowerSync ni otra biblioteca de estado. [Pubspec estable flutter_map](https://raw.githubusercontent.com/fleaflet/flutter_map/v8.3.2/pubspec.yaml).

main.dart agrega un Provider de MapEnvironment alrededor de la aplicación. Reutiliza el cliente Supabase ya inicializado para construir SupabaseMapOriginRepository, sin cambiar AuthController, registro, PIN, persistencia ni GoRouter. El repositorio solo resuelve el centro de zona; no administra sesión ni crea usuarios.

MapEnvironment es la frontera de inyección de configuración/fábrica de TileProvider y origen. Los tests pueden suministrar imágenes locales, centro diferido o errores sin HTTP. Si se instancia la aplicación fuera de main sin ese Provider, el widget indica Cartografía sin proveedor configurado y no ejecuta tráfico silencioso ni devuelve tiles falsos.

El MapController de flutter_map gestiona la cámara; no sustituye Provider ni introduce una arquitectura de negocio nueva. El estado de presentación de esta fase permanece dentro del widget: carga de centro, carga inicial de mosaicos, error y reintento. No se crean repositorios/controladores vacíos para las futuras fases.

## Posición inicial y seguridad

Orden de preferencia implementado:

1. MapEnvironment.sessionOrigin, si una composición futura proporciona una referencia ya autorizada de la sesión actual. En producción 6.2 no hay una fuente GPS y ese valor es nulo; no se adquiere ubicación.
2. mi_zona() y SELECT nombre,centro de zonas para el UUID retornado, con la sesión del cliente actual. Se muestra Centro de tu zona y se aclara que no es posición GPS.
3. Vista general neutral: latitud 0, longitud 0 y zoom 2, explícitamente rotulada «Vista general · no es tu ubicación». Es un encuadre general, no una afirmación de posición del vecino.

Se verifica que el usuario no cambie durante las lecturas. Sin sesión, zona o fila, se usa vista general; un fallo de red, permisos o formato muestra aviso seguro y Reintentar centro, conservando esa vista neutral. No se toma la primera zona del catálogo ni una coordenada de Lima. No se consultan perfiles privados para obtener el centro.

GeoCoordinate valida rangos/finitud y decodifica Point WKB/EWKB hexadecimal 2D en ambos endian; valida SRID 4326 cuando está presente. Interpreta X como longitud y Y como latitud. Rechaza Z/M, tamaños incorrectos, SRID ajeno o estructuras no soportadas; no adivina coordenadas ante datos malformados. El contrato SQL fija geography(Point,4326); no se modificó SQL.

Las operaciones tienen timeout y las respuestas tardías se descartan por generación/dispose. Las lecturas de centro y tiles no se inician para el mapa normal/SOS oculto ni para ramas cuyo TickerMode está inactivo. TileLayer gestiona la liberación de sus proveedores; el widget libera el controlador de cámara.

La lectura real del centro de un perfil registrado no se comprobó contra Supabase remoto en esta fase: el fallback y la decodificación sí se probaron localmente. Se deberá comprobar el formato del proyecto desplegado antes de certificar ese recorrido remoto.

## Mosaicos y atribución

Proveedor seleccionado para el MVP de bajo tráfico: OpenStreetMap raster, sin claves ni contratación.

- Endpoint centralizado: https://tile.openstreetmap.org/{z}/{x}/{y}.png.
- User-Agent nativo explícito: VeciPulso/0.1 (community-map; Android). No depende del applicationId genérico del proyecto. En web aplican las restricciones del navegador para User-Agent/Referer.
- Texto © OpenStreetMap contributors siempre sobre el borde inferior del mapa, con fondo legible y enlace a https://www.openstreetmap.org/copyright. No se oculta en una leyenda desplegable.
- BuiltInMapCachingProvider de flutter_map, máximo blando 64 MiB, sin sobrescribir la edad de caché: respeta cabeceras HTTP. panBuffer 0 limita peticiones a las necesarias para la vista. No hay precarga de ciudades, lotes offline ni descargas masivas.

Estas decisiones se contrastaron con la [política oficial de mosaicos](https://operations.osmfoundation.org/policies/tiles/) y la [documentación de caché del mantenedor](https://docs.fleaflet.dev/layers/raster-tile-layer/caching.md). La caché puede ser eliminada por el sistema y no garantiza funcionamiento offline. Los servidores públicos no tienen SLA para emergencias; cambiar de proveedor exige revisar atribución y condiciones. No se incorporaron servicios de pago.

Las peticiones de tiles llevan coordenadas de tesela/IP, nunca JWT, DNI, teléfono ni datos de marcadores. No se registra ni publica GPS del usuario.

## Carga, errores y reintento

Se muestra Cargando cartografía hasta que se confirma al menos un mosaico decodificado. Esto no declara que toda la vista esté descargada. Si falla cualquier tile, se muestra un mensaje de carga parcial y Reintentar cartografía. El reintento reconstruye esa capa y conserva cámara/origen; no escribe datos ni simula cobertura offline. El error se conserva hasta el reintento explícito.

El fallo de centro se diferencia del fallo cartográfico. Siempre puede verse la referencia neutral si no hay un centro válido. No se ocultan errores bajo datos demo.

## Archivos de esta subfase

Nuevos:

- lib/features/maps/models/map_origin.dart: GeoCoordinate y MapOrigin.
- lib/features/maps/data/map_origin_repository.dart: interfaz/adaptador de lectura del centro.
- lib/features/maps/data/map_environment.dart: configuración/inyección de tiles.
- lib/features/maps/presentation/widgets/geographic_map_canvas.dart: lienzo geográfico y cámara.
- test/geographic_map_test.dart: seis pruebas unitarias/widgets sin internet.
- integration_test/map_tiles_test.dart: smoke de cartografía real en dispositivo, cerrado por defecto.
- docs/FASE_6_2_MAPA_REAL.md.

Modificados:

- lib/features/maps/presentation/screens/neighborhood_map_screen.dart.
- lib/features/emergency/presentation/screens/emergency_map_screen.dart, únicamente su mapa.
- lib/main.dart, composición de dependencias del mapa.
- pubspec.yaml y pubspec.lock.
- test/maps_test.dart, test/emergency_map_test.dart y test/emergency_dashboard_test.dart.

Las pruebas anteriores de mapa se adaptaron al comportamiento solicitado: ahora comprueban FlutterMap, ausencia de óvalo/pines demo, atribución, filtros conservados y regreso con cámara/búsqueda. No se eliminaron casos. El test del regreso desde proveedor abre explícitamente el detalle demostrativo que ya existe en esta rama; no afirma que se haya conectado un marcador real. No se modificaron pruebas de auth ni su implementación.

## Validación ejecutada

| Comprobación | Resultado |
|---|---|
| flutter pub get | Correcto; 11 avisos informativos de versiones superiores fuera de restricciones, sin error |
| Formato de Dart modificado | Correcto |
| flutter analyze final | Sin incidencias |
| flutter test test/geographic_map_test.dart --concurrency=1 | 6 aprobadas, 0 fallidas |
| Mapas + navegación, suite dirigida | 19 aprobadas, 0 fallidas |
| flutter test --concurrency=1 | 128 aprobadas, 0 fallidas, sin omisiones locales; 2 min 53 s |
| Android real del emulador | 1 caso aprobado por ejecución; se repitió sobre la integración final |
| git diff --check y git status | Correctos; cambios limitados al mapa, composición, dependencias, tests y documentación; sin commit ni cambio de rama |

Se corrigieron durante el desarrollo dos fallos de sincronización del decoder de imágenes del fake y avisos de estilo/deprecación. No se ocultaron fallos ni quedan regresiones locales. El aviso de JVM sobre acceso nativo emitido por Gradle no impidió construir el APK.

### Comprobación Android automatizada — efectivamente ejecutada

Dispositivo emulator-5554, Android 17/API 37, arquitectura android-x64. Compilación assembleDebug e instalación correctas. El test abrió el mismo GeographicMapCanvas con proveedor OSM, confirmó un tile decodificado sin error, atribución y etiqueta neutral, acercó con control de cámara, realizó drag táctil y recentró. El harness no necesita credenciales ni desbloquea cuentas: valida el componente real en Android, no el recorrido remoto de autenticación/centro.

Comando ejecutado:

```powershell
flutter test integration_test/map_tiles_test.dart -d emulator-5554 --dart-define=ALLOW_MAP_TILE_CHECK=true
```

Sin esa bandera, el smoke queda omitido para no depender de internet en la suite local. No es una descarga masiva ni una prueba de carga; consulta una vista y realiza un gesto breve. La segunda ejecución captura el lienzo en caché temporal del harness, sin datos personales; no se entrega como inspección manual exportada. El entorno de prueba puede eliminar esa caché al terminar.

No se ejecutaron la integración remota de autenticación ni lecturas de centro reales contra Supabase. No se emitieron alertas ni se modificaron registros.

### Procedimiento manual Android preparado — pendiente

1. En un dispositivo autorizado, ejecutar flutter run -d <id> --dart-define-from-file=config/supabase.dev.json. No mostrar ni versionar el JSON.
2. Restaurar sesión y desbloquear el PIN por el flujo existente. Abrir Mapa y comprobar centro de zona o aviso neutral, atribución y ausencia de permisos GPS.
3. Probar arrastre horizontal/vertical, pinza con dos dedos, zoom/recentrado, rotación de pantalla y texto 150–200 %. Confirmar que no aparecen pines demo ni riesgo ficticio.
4. Cambiar a SOS y volver; revisar barra inferior única, filtros/cámara y Atrás Android.
5. Desactivar red y mover a una vista no cacheada. Comprobar error sin promesa offline; recuperar conexión y reintentar. Tiles existentes pueden seguir visibles desde caché y no prueban cobertura offline.
6. Abrir la atribución y volver a la app; revisar que el mapa mantiene su estado. No emitir SOS ni publicar datos para probar cartografía.

La interacción manual por una persona, dispositivo físico y el centro remoto siguen pendientes; no se confunden con el smoke automatizado.

## Preparación para 6.3 y límites

La referencia de sesión es un punto de extensión, sin solicitar GPS en 6.2. La Fase 6.3 podrá inyectar una lectura puntual autorizada, ligada a identidad y ciclo de vida, conservando fallback de zona/neutral. No incorporar stream ni permisos en segundo plano.

La conexión de puntos/capas y detalles corresponde a fases posteriores. La aplicación actual no muestra servicios, favores, emergencias o brigadas reales sobre el mapa. No se cambia RLS ni se trata la cartografía como prueba de seguridad de las RPC SOS. Las limitaciones SQL identificadas en 6.1 permanecen pendientes.

La Fase 6.2 entrega mapa real con prueba Android aprobada y pruebas locales verdes; no certifica integración geográfica completa con Supabase. Se detiene antes de 6.3.
