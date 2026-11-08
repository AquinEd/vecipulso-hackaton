# Fase 6.3 — Ubicación puntual y permisos Android

Entrega del 2026-11-08 sobre la rama encontrada **main**, conservada sin cambiar a feat/mapa-geolocalizacion. Se preservó todo el trabajo sin confirmar de 6.1/6.2. Alcance: ubicación del propio dispositivo, sin marcadores comunitarios Supabase, seguimiento ni escrituras remotas.

## Arquitectura implementada

Dependencia directa geolocator 14.1.2, estable y compatible con el SDK Flutter 3.47.9/Dart 3.13.7. Se resolvieron sus dependencias transitivas, incluidas las implementaciones de plataforma. Se mantienen Provider, GoRouter y el único cliente Supabase de la aplicación. [Guía oficial del paquete](https://pub.dev/packages/geolocator).

Nuevos:

- lib/features/maps/data/location_service.dart: LocationService inyectable; adaptador GeolocatorLocationService; DeviceLocation, PositionPrecision y LocationFailure.
- lib/features/maps/presentation/controllers/location_controller.dart: ChangeNotifier compartido por los dos mapas, con estado y una sola operación en curso.
- test/location_test.dart: plataforma geográfica simulada, pruebas de servicio/controlador e integración de ubicación con el lienzo.
- docs/FASE_6_3_GEOLOCALIZACION.md.

Modificados en esta subfase:

- lib/main.dart: composición de LocationController con GeolocatorLocationService, ligado a la identidad observada por auth. No modifica autenticación.
- lib/features/maps/presentation/widgets/geographic_map_canvas.dart: acción de ubicación, mensajes, centrado y marcador propio; reusa el centro de zona/vista general de 6.2.
- android/app/src/main/AndroidManifest.xml: permisos de ubicación aproximada y precisa en primer plano.
- pubspec.yaml/lock: dependencia geolocator y sus transitivas.
- test/geographic_map_test.dart: la aserción histórica «sin GPS en 6.2» pasa a verificar permisos solo de primer plano y ausencia de permiso de segundo plano. Los demás casos se conservan.
- macos/Flutter/GeneratedPluginRegistrant.swift y windows/flutter/generated_plugin_registrant.cc/generated_plugins.cmake: actualizaciones mecánicas generadas por Flutter al registrar los plugins. No se editaron a mano ni se configuraron permisos de esas plataformas.

Los demás archivos visibles en git status ya tenían cambios de 6.1/6.2. No se restauraron ni sobrescribieron. No se cambiaron SQL, rutas, auth, servicios, favores ni pantallas ajenas al mapa.

## Flujo y estados

Abrir app/mapa o desbloquear el PIN no solicita permisos ni realiza lecturas GPS. Solo el botón **Usar mi ubicación** invoca el servicio. Después de una lectura satisfactoria cambia a **Actualizar mi ubicación**; cada pulsación inicia una nueva consulta puntual y vuelve a comprobar permisos/servicio.

El servicio comprueba ubicación habilitada, permiso actual y, únicamente si está denegado, solicita permiso. Acepta acceso whileInUse o un acceso ya concedido always, sin pedir ni configurar este último. Si se concede, llama getCurrentPosition una sola vez con LocationAccuracy.medium y timeLimit de 20 s. Existe además una protección Dart de 22 s para esa llamada. No usa getPositionStream ni getLastKnownPosition como éxito silencioso.

Las consultas de estado de servicio/permiso tienen límite de 10 s; la señal complementaria de precisión tiene límite de 5 s. El diálogo de consentimiento no tiene un vencimiento que elija por el usuario: espera su decisión. Si se abandona/dispose el controlador mientras ese diálogo está abierto, no se inicia una lectura GPS al volver la respuesta. Una lectura nativa ya iniciada puede continuar hasta obtener el único fix o alcanzar su timeout; se descarta si su operación dejó de estar activa.

LocationStage distingue initial, loading, ready, denied, permanentlyDenied, disabled, timeout, unavailable y session. Los mensajes son seguros y no incluyen excepciones internas ni coordenadas. Durante una operación se deshabilita el botón y se muestra carga. Una segunda pulsación o entrada desde el otro mapa no inicia otra consulta simultánea.

| Situación | Resultado |
|---|---|
| Permiso concedido | Lectura puntual, indicador propio y centrado |
| Acceso aproximado | Etiqueta explícita de ubicación aproximada; no exige precisión mayor |
| Acceso preciso | Etiqueta «con permiso preciso», sin afirmar exactitud absoluta |
| Precisión del permiso no informada | Etiqueta «precisión no determinada» |
| Permiso denegado | Mensaje comprensible; mapa sigue utilizable sin indicador propio |
| Denegado permanentemente | Indicación de habilitarlo manualmente en Ajustes; no bucle de diálogos |
| Servicios apagados | Aviso; no intenta obtener una posición |
| Timeout, error o coordenadas inválidas | Sin éxito ni coordenadas inventadas, mensaje y reintento mediante el mismo botón |
| Sesión cambia | Se descarta la respuesta y se limpia la referencia de la sesión anterior |

getLocationAccuracy distingue reduced/precise/unknown cuando la plataforma lo informa. [API oficial de precisión](https://pub.dev/documentation/geolocator/latest/geolocator/Geolocator/getLocationAccuracy.html). Esto describe el nivel autorizado, no el error real: se muestra también el radio estimado del sensor y la fecha de la lectura. Si hasAccuracy es falso, no se presenta 0 m como precisión perfecta. La ubicación aproximada no se convierte artificialmente en precisa.

La pérdida de internet no se diagnostica como permiso denegado. El posicionamiento puede funcionar sin red, pero puede demorarse o fallar según proveedor/señal. En caso de fallo se muestra unavailable/timeout y se conserva el mapa. Los errores de descarga de teselas siguen separados; no se agregó una biblioteca de conectividad ni se promete cartografía offline.

## Permisos y alcance Android

Manifest de la app:

- android.permission.INTERNET, preexistente.
- android.permission.ACCESS_COARSE_LOCATION.
- android.permission.ACCESS_FINE_LOCATION.

Se declaran juntos coarse/fine para que Android permita elegir aproximada/precisa. No se declara ACCESS_BACKGROUND_LOCATION, cámara, contactos ni permisos de notificación o de servicio de ubicación en primer plano. No se inicia un foreground service ni se proporciona foregroundNotificationConfig. El plugin registra internamente su servicio Android, pero no se utiliza para seguimiento.

compileSdk/minSdk/targetSdk siguen delegados a Flutter; no se copiaron valores de otro proyecto ni se cambió Gradle por el mero hecho de instalar el paquete. El alcance validado es Android. No se configuraron descripciones de uso ni permisos GPS de iOS/macOS: no se certifica ubicación en esas plataformas.

## Indicador, cámara y fallback

La ubicación es un MarkerLayer exclusivamente local, con icono y etiqueta accesible «Tu última lectura de ubicación, visible solo en este dispositivo». No se obtiene de puntos_mapa ni representa otro vecino. La cámara centra el último resultado autorizado, con zoom de barrio, y mantiene los controles de desplazamiento/zoom. El botón Centrar vista inicial ahora prioriza esa lectura puntual si existe.

El origen de zona de 6.2 sigue cargándose de forma independiente. Una respuesta tardía del centro no reemplaza la posición obtenida por acción explícita: el origen visible prioriza LocationController.location. Al iniciar otra consulta se limpia el resultado anterior; si falla, desaparece el indicador y el mapa vuelve a su centro de zona o vista general neutral, sin presentar una coordenada fija como ubicación personal.

Normal y SOS comparten una única lectura en memoria para la misma sesión, no dos GPS independientes. Las respuestas fuera de orden se descartan por generación y se comprueba la identidad antes de aceptar coordenadas. clear no libera prematuramente el bloqueo de una operación nativa pendiente; dispose impide notificaciones posteriores. El widget escucha Provider y solo convierte los datos a cámara/marcador; la lógica de permisos y adquisición vive fuera del lienzo.

## Privacidad

- No hay escrituras Supabase, RPC geográficas ni publicación de coordenadas desde el servicio/controlador de ubicación.
- No se registra latitud/longitud, PIN, JWT ni datos personales en logs.
- Solo se conserva la última lectura en memoria; se reemplaza al actualizar y se limpia ante cambio de sesión o dispose. No hay historial ni persistencia en disco.
- No se rastrea al vecino al moverse, cambiar de pantalla o pausar la app. La etiqueta y fecha dejan claro que es una lectura puntual que puede quedar antigua.
- Al centrar el mapa, el proveedor de teselas conoce el área visualizada y la IP. Se informa junto al botón: no equivale a publicar el punto en Supabase ni a compartirlo con vecinos. No se envían las coordenadas como payload al proveedor ni se añaden a logs.
- Las reglas de publicar ubicaciones/SOS pertenecen a otros flujos y no se activan al usar este botón.

## Pruebas

test/location_test.dart contiene 16 casos locales:

1. Tres variantes de precisión: precise, reduced y unknown, sin consulta ni permiso inicial.
2. Tres decisiones después de pulsar: conceder, denegar y bloquear permanentemente.
3. Permiso permanentemente bloqueado y servicio apagado, sin iniciar GPS.
4. Cuatro fallos de lectura: timeout, error genérico, servicio desactivado y permiso revocado; recuperación al reintentar.
5. Doble pulsación/clear con lectura pendiente: solo una llamada nativa.
6. Dispose durante el diálogo: no empieza GPS ni notifica tarde.
7. Cambio de identidad: descarta coordenadas y limpia estado.
8. Ausencia de streams y acceso Supabase en la capa de ubicación.
9. Widget: solo lee al pulsar, centra en el resultado, muestra indicador aproximado y permite seguir sin GPS después de denegación permanente.

Son pruebas con GeolocatorPlatform simulado, no permiso real del sistema ni RLS. Se conservan las regresiones de autenticación/PIN, navegación, servicios y mapa. Los fixtures sintéticos solo están en test, nunca como fuente de coordenadas productivas.

| Validación | Resultado |
|---|---|
| flutter pub get | Correcto; sin dependencias ajenas a geolocator y sus transitivas |
| Formato de Dart intervenido | Correcto |
| flutter analyze final | Sin incidencias |
| flutter test test/location_test.dart --concurrency=1 | 16 aprobadas, 0 fallidas |
| Ubicación + mapa, ejecución dirigida | 22 aprobadas, 0 fallidas |
| flutter test --concurrency=1 | 144 aprobadas, 0 fallidas, sin omisiones locales; 2 min 28 s |
| Android: map_tiles_test en emulator-5554, API 37 | 1 aprobada; APK construido e instalado con geolocator |
| git diff --check y git status | Revisados, sin commit ni cambio de rama |
| Diálogo real Android y fix del emulador Pixel | Pendiente de ejecución manual |
| Integración remota de autenticación/centro Supabase | No ejecutada |

El smoke Android ejecutado usa el harness de cartografía de 6.2 y no pide ubicación: acredita compilación/render con el plugin, no que se haya obtenido un fix ni concedido permiso real. Comando: flutter test integration_test/map_tiles_test.dart -d emulator-5554 --dart-define=ALLOW_MAP_TILE_CHECK=true.

También se inspeccionó el manifiesto Android fusionado: INTERNET, COARSE y FINE, sin BACKGROUND_LOCATION ni permisos de foreground service location. Aparece además el permiso interno de receptor no exportado generado por AndroidX, que no concede acceso a recursos del vecino. El servicio del plugin queda registrado como se describe arriba.

Se corrigieron un constructor const inválido y un catch redundante detectados durante desarrollo; el análisis final quedó limpio. Los avisos de Gradle/JDK y de Java 8 de código transitivo del plugin no impidieron la compilación. Las advertencias Git de conversión LF/CRLF de registradores generados no son errores de diff --check. No se modificaron pruebas de autenticación ni se descartaron fallos para obtener este resultado.

## Procedimiento manual Pixel — preparado, pendiente

1. Seleccionar el emulador Pixel con flutter devices. Usar una sesión de prueba ya registrada y la configuración local ignorada; ejecutar flutter run -d emulator-5554 --dart-define-from-file=config/supabase.dev.json.
2. Abrir app, desbloquear PIN y entrar al mapa sin pulsar ubicación: no debe aparecer diálogo del sistema ni lectura.
3. En Extended Controls → Location del emulador establecer una posición sintética. Esto configura el proveedor del emulador, no una coordenada fija en Dart. No usar datos personales reales.
4. Pulsar Usar mi ubicación, elegir aproximada y Solo mientras se usa la app/solo esta vez. Verificar etiqueta aproximada, fecha, marcador y centro.
5. Cambiar la referencia sintética del emulador sin pulsar Actualizar: el marcador no debe seguir el movimiento. Pulsar Actualizar y verificar una única lectura nueva.
6. En Ajustes → Apps → VeciPulso → Permisos revocar ubicación. Pulsar otra vez y denegar; comprobar mensaje, ausencia de indicador y mapa utilizable. Repetir bloqueo permanente y recuperación manual en Ajustes.
7. Habilitar permiso preciso y repetir: la etiqueta debe describir el permiso y el radio estimado, sin afirmar exactitud absoluta.
8. Apagar ubicación global y pulsar: mensaje de servicio desactivado. Volver a encender y reintentar. Sin señal suficiente debe aparecer timeout/error, no una ubicación ficticia.
9. Desactivar red: comprobar que ubicación y tiles manejan sus errores por separado. Si GPS funciona sin red, no debe rechazarse artificialmente; si no hay fix, el mapa sigue disponible con su referencia inicial/caché sin prometer offline.
10. Probar normal → SOS → regreso y salir de sesión/cambiar cuenta. La lectura nunca debe aparecer atribuida al otro usuario; no debe haber permisos nuevos al abrir otra pantalla. No emitir SOS ni publicar datos para probar GPS.

Estos pasos requieren interacción con el diálogo Android; no se presentan como ejecutados por mocks. El smoke de cartografía existente puede comprobar build/render con el plugin instalado, pero no acredita permiso ni posicionamiento real.

## Preparación para 6.4

LocationController.location puede servir como origen autorizado para futuras búsquedas, manteniendo zona/neutral como alternativa. La Fase 6.4 deberá respetar RLS, distinguir distancias desde GPS/centro y revisar qué datos se mandan en cada RPC. No se llamó puntos_mapa ni se añadieron capas de proveedores, favores o SOS en esta entrega.

No se hizo ninguna operación Git de escritura. La Fase 6.3 termina aquí, sin iniciar 6.4.
