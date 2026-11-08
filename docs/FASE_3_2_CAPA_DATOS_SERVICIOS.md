# Fase 3.2 — Capa de datos de servicios

Los tres repositorios reciben por constructor el mismo SupabaseClient inicializado en main. Cada operación se ejecuta al invocar su método y usa la sesión del cliente. Las pantallas actuales continúan usando ServicePreview. Los nombres de las columnas, las proyecciones y los estados proceden del [contrato de la instalación v5](FASE_3_1_CONTRATO_SUPABASE.md).

## Archivos y modelos

- `lib/features/services/models/service_rows.dart` contiene los modelos inmutables de lectura. Validan el formato UUID, convierten fechas ISO a UTC y conservan los campos opcionales como null.
- `lib/features/services/data/services_repository.dart` contiene ServicesRepository, RequestsRepository, RecommendationsRepository, el acceso común con timeout de 20 segundos y ServicesFailure.
- `lib/features/services/presentation/controllers/services_controllers.dart` contiene los ChangeNotifier inyectables.
- `test/services_data_layer_test.dart` prueba la capa sin red con el SDK real y MockClient. En pubspec.yaml y pubspec.lock se declaró como dependencia de desarrollo http, ya resuelto en la misma versión, para poder importar su transporte de pruebas.

| Modelo | Campos de la proyección SQL |
|---|---|
| ServiceCategoryRow | id entero, nombre, icono opcional |
| ServiceRow | id, proveedor_id, categoria_id, titulo, descripcion, anios_experiencia, zona_id, activo, creado_en |
| PublicProvider | id, nombre_publico, avatar_url, zona_id, vecino_confiable |
| ServiceContact | servicio_id, telefono, autorizado |
| ServiceWork | id, servicio_id, titulo, creado_en |
| ServiceRequest | id, servicio_id, solicitante_id, estado, mensaje, creado_en |
| SentRequest y ReceivedRequest | id, servicio_id, servicio, estado, creado_en. Enviadas incluye proveedor y puedo_recomendar. Recibidas incluye solicitante y mensaje |
| ServiceReview | id, autor público, puntaje, comentario, creado_en |
| NearbyService | id, titulo, categoria, descripcion, proveedor, anios_experiencia, distancia_m, promedio nullable, recomendaciones, visto_bueno, lat, lng |

Los campos Dart se expresan en camelCase. El enum RequestStatus usa solicitada, contactado, completada y cancelada. Las consultas de tabla seleccionan solo campos necesarios. Para el punto geográfico se utilizan los dos números devueltos por PostGIS en la búsqueda y se validan sus rangos. La consulta de directorio omite el binario geography.

## Operaciones

| Repositorio | Métodos y contrato |
|---|---|
| ServicesRepository | categories lee categorias_servicio. directory devuelve servicios activos de la zona permitida por RLS, con categoryId opcional. nearby invoca buscar_servicios_cercanos(p_lat, p_lng, p_radio_m, p_texto, p_min_estrellas) y permite seleccionar categoría por nombre exacto sobre la respuesta. detail lee servicios por UUID. provider filtra perfiles_publicos_de_mi_zona() por id. works consulta servicio_trabajos. contact filtra servicio_contacto por servicio_id y autorizado=true. |
| ServicesRepository | publish obtiene mi_zona(), envía el UID de sesión y un UUID de operación a servicios y devuelve la fila confirmada. Omitir ubicacion_aprox permite al trigger aplicar el centro de zona. update envía título, descripción, años y activo como edición completa de los campos permitidos. |
| RequestsRepository | create inserta con el estado inicial por defecto. sent y received leen mis_solicitudes_enviadas() y mis_solicitudes_recibidas(). transition invoca actualizar_solicitud_servicio(p_solicitud, p_estado) y relee la fila por ID para devolver el estado persistido. |
| RecommendationsRepository | reviews invoca resenas_de_servicio(p_servicio). recommend valida el entero 1–5, inserta autor_id de sesión, servicio_id, puntaje, comentario y UUID de operación. Devuelve el ID que confirma PostgreSQL. |

Sin GPS, directory utiliza directamente la política servicios_lectura. La distancia solo se conoce en nearby. La RPC busca en título, descripción y categoría. Los agregados disponibles son promedio, recomendaciones y vistoBueno de NearbyService. El distintivo y puedoRecomendar de SentRequest se leen del servidor. PostgreSQL comprueba experiencia completada, zona, autor y unicidad incluso si cambian después de consultar la elegibilidad.

## Estado, errores y seguridad

DirectoryController carga por zona y NearbyController por coordenadas. ServiceDetailController compone servicio, perfil público, contacto, portafolio y reseñas. SentRequestsController y ReceivedRequestsController exponen las bandejas. RequestController crea solicitudes y realiza transiciones. RecommendationController registra una reseña. ServiceEditorController publica un servicio.

ServiceController representa initial, loading, loaded, empty, error, denied y offline. Una generación invalida las lecturas anteriores y clear limpia los datos al salir o cambiar de sesión. dispose invalida respuestas pendientes. Durante una escritura el controlador ignora un segundo envío. La confirmación se publica después de que el repositorio devuelve la respuesta del servidor.

ServicesFailure diferencia conexión, sesión, permisos, referencia ausente, conflicto de estado, duplicado, datos inválidos y error del servidor. La presentación puede usar failure.message. Los repositorios conservan RLS y evitan registrar payloads o excepciones privadas. Tras pérdida de conexión durante una escritura, consultar la fila o bandeja antes de reintentar con el mismo UUID. Esto también aplica si falla la lectura posterior a una transición ya confirmada.

## Conexión prevista en 3.3

1. En la composición de la app, construir los tres repositorios con el cliente de la sesión ya inicializada. Proveerlos por encima del directorio. En pruebas inyectar fakes o un cliente con transporte simulado.
2. Crear DirectoryController mediante ChangeNotifierProvider, llamar refresh al abrir y aplicar categoryId del catálogo cuando cambie el filtro. Renderizar stage, data y failure. Crear NearbyController solo cuando se disponga de un origen válido.
3. Para abrir la ficha, pasar ServiceRow.id o NearbyService.id. Releer enviadas para mostrar elegibilidad y refrescar búsqueda y reseñas tras una escritura confirmada. Al cambiar de usuario liberar los controladores del anterior.

La RPC omite la búsqueda por nombre del proveedor y el filtro por ID de categoría. Los resultados están sujetos al límite de filas de PostgREST. En un directorio grande habrá que paginar antes de ofrecer filtros locales sobre el conjunto completo. Las fichas abiertas por ID disponen de reseñas pero carecen de una RPC de agregados independiente del radio. Estas limitaciones deben conservarse visibles al conectar los filtros y el detalle.

## Validación local

La suite usa respuestas HTTP simuladas para comprobar la ruta, el método y los parámetros de búsqueda cercana, inserción de recomendación, duplicado y transición de solicitud con relectura posterior. También comprueba UUID, nulos, fecha, punto geográfico, errores de red/permisos y el ciclo de vida del controlador con respuestas fuera de orden.

Se ejecutó flutter pub get. El comando dart format . encontró una ruta inaccesible en build de Android bajo Windows. Se aplicó dart format directamente a los cuatro archivos Dart nuevos. Las escrituras de prueba se ejecutaron exclusivamente en MockClient.

Resultado final: flutter analyze sin incidencias. flutter test --concurrency=1 terminó con 129 pruebas aprobadas (122 anteriores y 7 nuevas). git diff --check pasó.
