# Fase 6.1 — Auditoría del mapa y geolocalización

Auditoría del 2026-11-08, limitada a documentación y pruebas existentes. Rama encontrada: **main**, distinta de feat/mapa-geolocalizacion. El árbol estaba limpio al comenzar. No se cambió de rama ni se recuperaron implementaciones de otras ramas. Solo se crean los tres documentos de 6.1.

## Estado real del checkout

Flutter 3.47.9 stable y Dart 3.13.7, verificados con flutter --version. pubspec.yaml requiere Dart ^3.13.7 y declara Provider ^6.1.5+1, GoRouter ^18.1.3 y supabase_flutter ^2.18.3. No existen flutter_map, latlong2 ni geolocator en pubspec ni lockfile. No hay proveedor de mosaicos configurado.

main.dart inicializa un único cliente Supabase y construye SupabaseAuthRepository/AuthController. La autenticación y PIN están conectados; sus modelos Profile y Zone solo contienen userId e id/name respectivamente. No conservan zona del perfil ni coordenadas. El patrón reutilizable es repositorio con cliente inyectado, interfaz para tests y ChangeNotifier con Provider. Revisados main.dart, app/app.dart, app_router.dart, features/auth/data/auth_repository.dart, models/auth_models.dart y presentation/controllers/auth_controller.dart.

En esta rama Servicios, Favores y SOS conservan catálogos demostrativos. No existen ServicesRepository ni SosRepository ni documentos Fase 3/5 del trabajo en otras ramas. README, ARCHITECTURE, ROUTES y ASSETS describen etapas visuales históricas; AUTENTICACION_SUPABASE.md acredita únicamente la integración de autenticación, no el mapa. No se extrapola ninguna garantía de otras ramas.

## Inventario leído

Todas las rutas se verificaron en lib/app/app_routes.dart y app_router.dart, no se deducen de los nombres de pantalla.

| Pantalla/destino | Archivo bajo lib/ | Datos y acciones actuales | Cambio mínimo posterior |
|---|---|---|---|
| /mapa normal | features/maps/presentation/screens/neighborhood_map_screen.dart | Seis demoMapMarkers; búsqueda local normalizada, cuatro categorías independientes, ficha modal, navegación a proveedor solo para comercios | Reemplazar lienzo por mapa y modelo de RPC; conservar búsqueda, vacío, leyenda y regreso. Añadir carga/error/recarga |
| /sos/mapa; /mapa redirige aquí con SOS activo | features/emergency/presentation/screens/emergency_map_screen.dart | Seis marcadores demo: tres alertas, dos brigadas y un refugio; filtros Todos/urgentes/en revisión/recursos/brigadas, fichas de lectura, regreso y salir | Adaptar puntos reales con urgencia y estado separados; eliminar el óvalo ficticio del camino real. No inferir zona de peligro oficial |
| Ficha del marcador normal, sin ruta propia | neighborhood_map_screen.dart, método showMarker | Descripción demo, chip explícito y Ver proveedor | Consultar detalle autorizado por capa/UUID; puntos_mapa no devuelve descripción ni contacto |
| /servicios/:id | features/services/presentation/screens/provider_detail_screen.dart | Busca ID en demoServices; IDs reales devuelven Proveedor no encontrado | Integración de detalle real debe estar presente antes de habilitar el enlace desde un UUID del mapa |
| Fichas SOS, sin ruta propia | emergency_map_screen.dart y features/emergency/presentation/widgets/emergency_report_details.dart | Reporte, distancia simulada o grupo/refugio de catálogo | Detalles reales inyectados; no reutilizar IDs demo ni convertir una selección en ayuda aceptada |
| /sos/seguimiento | features/emergency/presentation/screens/help_tracking_screen.dart y widgets/help_route_preview.dart | Ruta dibujada entre dos Offset fijos, perfil/chat ilustrativos | Mantener marcada como demo y fuera del mapa real; no hay motor de rutas viales |
| /sos/brigadas | features/emergency/presentation/screens/brigades_screen.dart | Cuatro grupos demo; filtro, búsqueda y aviso contacto no disponible | Solo conectar si se dispone de lector autorizado de grupos; no asumirlo por existir ruta |
| /favores y /favores/ampliado | features/solidarity/presentation/screens/solidarity_wall_screen.dart | Muro demo, sin ruta de detalle UUID | Si se incluyen favores geográficos, usar ficha mínima de la RPC; el muro no resuelve IDs reales todavía |

AppModeDestination mantiene ambos mapas en IndexedStack. El modo SOS pertenece a AppModeController, no a la base de datos. StatefulShellRoute mantiene navegadores y una barra inferior; AppNavigation gestiona entrada/salida. Conservar esta estructura y las guardas AuthController. Las páginas ocultas del IndexedStack pueden seguir montadas: los futuros controladores no deben duplicar consultas, permisos ni localización al cambiar de pestaña.

### Lienzos, modelos y recursos

- features/maps/presentation/widgets/neighborhood_map_canvas.dart usa CustomPaint IllustratedStreetsPainter y Positioned; relativeX/relativeY son fracciones del dibujo, no coordenadas.
- features/emergency/presentation/widgets/emergency_map_canvas.dart comparte el pintor, sitúa Offset relativos y dibuja risk-oval fijo. No son un polígono geográfico ni un evento calculado.
- shared/widgets/common/illustrated_streets_painter.dart dibuja calles/parques escalados desde 740×920. No hay teselas, proyección, zoom, pan, GPS ni red en esos lienzos.
- features/maps/models/community_map_marker.dart mezcla presentación Material, colores/iconos y coordenadas relativas; no sirve directamente como DTO PostGIS.
- features/emergency/models/emergency_map_marker.dart incorpora EmergencyReport/CommunityBrigade de demo. Su enum mezcla clasificación visual y prioridad. No serializarlo como enum SQL.
- data/demo_map_markers.dart depende de demo_services.dart: dos comercios y cuatro recursos/ayudas/grupos ilustrativos. demo_emergency_map_markers.dart depende de demo_emergency_reports.dart y demo_brigades.dart. Nada se obtiene de Supabase.
- models de publicaciones y servicios tampoco proporcionan una ubicación geográfica real. El seguimiento usa _origin/_destination Offset constantes.
- ASSETS y design/references/screens/07_Mapa_Geolocalizado.png y 23_Mapa_Alerta_Critica.png son referencias visuales; assets/images/illustrations/Mapa_Cercano.png e iconos/pines existentes pueden reutilizarse como decoración, no como mapa de fondo georreferenciado.

Datos ficticios productivos (A): los cuatro catálogos demo anteriores, posiciones, metros, riesgo y recorrido. Fixtures de tests (B): datos construidos bajo test y repositorios falsos de autenticación. Recursos legítimos (C): iconos, paleta, ilustraciones y textos de categoría. No se eliminó ni modificó ninguno.

## Brechas y decisiones de producto

1. La RPC puntos_mapa devuelve cuatro capas, pero la leyenda normal tiene ayuda humanitaria en lugar de alertas y no representa favores. No hay que disfrazar una alerta o favor como comercio/recurso. Propuesta: ajustar el adaptador visual a esas cuatro capas y decidir por separado la composición opcional con buscar_publicaciones_cercanas.
2. Ni puntos_mapa ni la base contienen un área de riesgo para el óvalo dibujado. resumen_emergencia ofrece un booleano comunitario, no geometría de peligro ni certificado oficial.
3. No existe navegación de detalle real para las cuatro capas en este checkout. Los módulos de compañeros deben revisarse al integrar; alternativa mínima: ficha de solo lectura por repositorio del mapa, con datos autorizados y aviso de campos no disponibles. No crear rutas paralelas sin necesidad.
4. Falta resolver origen sin GPS: mi_zona() y zonas.centro lo permiten, pero requieren lector y decodificador; no hay RPC existente que proyecte directamente el centro a lat/lng.
5. No hay búsqueda por bounding box/zoom/capa ni orden global en puntos_mapa. El radio es del origen consultado, no el límite de zona. Evitar anunciar todos los puntos si se alcanza el límite API.
6. No hay administración, rutas viales, geocodificación, seguimiento, reservas de recursos ni información de stock en tiempo real dentro del alcance propuesto.

## Bibliotecas y mosaicos: evaluación, sin instalación

Consulta de documentación oficial realizada el 2026-11-08; las versiones y políticas pueden cambiar antes de 6.2.

| Candidato | Compatibilidad comprobada | Decisión propuesta |
|---|---|---|
| flutter_map 8.3.2 estable | Pubspec del tag exige Dart >=3.6 <4 y Flutter >=3.27; admite latlong2 >=0.9.1 <0.11. SDK instalado satisface esos mínimos | Candidato para mapa raster con TileLayer/MarkerLayer; resolver dependencias y compilar en 6.2 |
| latlong2 0.10.1 estable | Catálogo oficial indica Dart mínimo 3.0; rango permitido por flutter_map 8.3.2 | Declararla directamente al importar LatLng. No asumir compatibilidad completa sin pub solver |
| geolocator 14.1.2 | Catálogo indica Dart >=3.5. Documentación exige AndroidX y compileSdk 35; ubicación puntual y permisos requieren adaptación de plataforma | Añadir solo en 6.3, sin stream ni ubicación en segundo plano |

Fuentes: [pubspec estable de flutter_map](https://raw.githubusercontent.com/fleaflet/flutter_map/v8.3.2/pubspec.yaml), [versiones latlong2](https://pub.dev/packages/latlong2/versions), [versiones geolocator](https://pub.dev/packages/geolocator/versions), [guía geolocator](https://pub.dev/packages/geolocator). No se recomienda una versión prerelease ni se ejecutó pub get/solver para estos paquetes.

Android usa Java 17, AndroidX y compileSdk/minSdk/targetSdk delegados al plugin Flutter (android/app/build.gradle.kts, android/gradle.properties). El manifiesto principal solo declara INTERNET. Confirmar los niveles efectivos al compilar, no inferirlos de un ejemplo. En 6.3 se añadirá permiso de ubicación de primer plano acorde a precisión necesaria; no BACKGROUND_LOCATION. Info.plist no incluye descripción de uso de ubicación: iOS requeriría configuración WhenInUse y pruebas propias si entra al MVP.

Proveedor actual: ninguno. Propuesta para demo de bajo tráfico: mosaicos raster OSM solo si se cumple su política, o proveedor alternativo con condiciones acordadas. Mantener URL/atribución configurables. No enviar JWT ni datos vecinales al servidor de mosaicos; las solicitudes revelan IP y área de visualización. No prometer disponibilidad para emergencias.

OSM exige HTTPS, atribución visible, identificación de aplicación y respeto de caché HTTP (o siete días si no se interpreta); prohíbe descarga masiva/offline por anticipado y no garantiza servicio. [Política oficial](https://operations.osmfoundation.org/policies/tiles/). flutter_map requiere configurar userAgentPackageName o cabecera propia en clientes nativos; un identificador genérico com.example no es apropiado. [Guía del mantenedor](https://docs.fleaflet.dev/tile-servers/using-openstreetmap-direct). La app actualmente tiene applicationId com.example.hackaton_veci_pulso: acordar identificación real antes de activar teselas. No cambió durante esta auditoría.

## Privacidad y riesgos

puntos_mapa es SECURITY INVOKER implícita: las políticas de cada tabla restringen zona. No usar service_role ni ampliar visibilidad por GPS/zoom. Los puntos son aproximados por rejilla, no domicilios exactos. Una rejilla no anonimiza automáticamente títulos/descripciones; no publicar detalles sensibles. Recursos, SOS y voluntarios tienen permisos distintos: sos_respuestas, respuestas y vecinos_vulnerables no son capas públicas.

El SQL permite catálogo de centros de zonas a anon/authenticated; son centros comunitarios, no posiciones de personas. El GPS del propio usuario debe permanecer en memoria y no escribirse en perfil ni logs por abrir el mapa. Un origen de centro de zona debe etiquetarse como tal; sus distancias no son distancia real desde el teléfono.

Bloqueos preexistentes: falta evidencia de esquema desplegado/RLS real; ausencia de detalles funcionales en esta rama; proveedor sin seleccionar; límite/orden de RPC por resolver; defecto crítico independiente de cerrar_alerta por autorización NULL y fuga limitada de confirmaciones_de, descritos en el contrato geográfico. No se corrigieron ni se explotaron.

## Pruebas existentes y validación

test/maps_test.dart: tres pruebas de catálogo, búsqueda/leyenda a 320 px y detalle/regreso a proveedor demostrativo. test/emergency_map_test.dart: cinco casos, independencia de filtros normal/SOS y cuatro combinaciones 320/412 px × texto 1.5/2.0, marcadores, fichas y regreso. app_mode_navigation_test, navigation_test, accessibility_test y auth_test cubren shell, modo, guardas y PIN. help_tracking_test cubre la ruta ilustrada. No hay pruebas de GPS, PostGIS ni tiles reales.

| Comprobación ejecutada | Resultado |
|---|---|
| flutter analyze | Sin incidencias, exit 0 |
| flutter test --concurrency=1 | 122 aprobadas, 0 fallidas, sin omisiones locales; 2 min 22 s, exit 0 |
| git diff --check | Correcto |
| git status | Solo tres documentos nuevos de 6.1 sin seguimiento; ningún archivo funcional modificado |
| Lecturas RPC geográficas y RLS reales | No ejecutadas |
| Android/GPS/teselas reales | No ejecutados |

No se ejecutó la integración remota existente de autenticación, que crea cuentas/perfiles y no es parte de esta auditoría. No se solicitaron permisos de ubicación ni se probaron servicios reales del mapa. Las pruebas demuestran el estado actual, no la futura integración geográfica. No hubo errores de análisis ni pruebas fallidas preexistentes; los riesgos SQL y las simulaciones descritas sí son limitaciones preexistentes. Una primera consulta de versión dentro del sandbox no completó y se interrumpió; la ejecución posterior fuera del sandbox obtuvo la versión y completó análisis y tests.

Puede comenzar 6.2 tras acordar proveedor, identificación y centro inicial; mantener la conexión de marcadores en 6.4 y no habilitar detalles reales inexistentes. Arquitectura y aceptación por subfase: FASE_6_ROADMAP_IMPLEMENTACION.md. Contrato exacto: FASE_6_1_CONTRATO_GEO_SUPABASE.md.
