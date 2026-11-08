# Fase 5.2 — Capa de datos SOS

La implementación incorpora modelos tipados, una interfaz de repositorio inyectable, un adaptador Supabase y controladores ChangeNotifier. La rama encontrada es feat/servicios-visto-bueno. Se conservan los dos documentos de 5.1 que ya estaban sin confirmar y se mantiene la rama por la restricción del encargo.

## Archivos nuevos

| Archivo | Responsabilidad |
|---|---|
| lib/features/emergency/models/sos_models.dart | SosAlert, HelpResponse, CriticalResource, SupportGroup, NearbyAlert, SosSummary, SosPoint y enums del contrato PostgreSQL |
| lib/features/emergency/data/sos_repository.dart | SosRepository, SupabaseSosRepository y SosFailure |
| lib/features/emergency/presentation/controllers/sos_controllers.dart | SosController, AlertsController, AlertDetailController, HelpResponsesController, ResourcesController y BrigadesController |
| test/sos_data_test.dart | Pruebas de modelos, transporte HTTP simulado y controladores |
| docs/FASE_5_2_CAPA_DATOS_SOS.md | Diseño, métodos, validación y limitaciones de la entrega |

SosRepository se inyecta en los controladores. SupabaseSosRepository recibe el SupabaseClient existente mediante constructor y no lo inicializa ni crea sesiones. Siguiendo auth, el adaptador concentra acceso a tablas/RPC, timeout de 20 segundos y traducción de fallos. Su responsabilidad de ciclo de vida corresponde a la composición futura, compartiendo el cliente de main. No se añadió un Provider productivo para esta fase.

## Modelos y geografía

Los modelos de tabla conservan las columnas de alertas_sos, sos_respuestas, recursos_criticos y grupos_apoyo. Cada modelo dispone de fromJson/toJson con nombres de columna SQL, UUID validados, fechas UTC y opcionales NULL. NearbyAlert representa exclusivamente alertas_cercanas y SosSummary representa resumen_emergencia. Los enums conservan sus literales SQL para transmitir nombre sin traducciones ambiguas. La excepción localizada de estilo constant_identifier_names está documentada en el archivo de modelos.

SosPoint valida finitud y límites de latitud/longitud. Reconoce GeoJSON Point de dos coordenadas, WKT Point con SRID 4326 opcional y WKB/EWKB hexadecimal 2D con endian explícito y SRID 4326 cuando está presente. Un tipo, SRID, tamaño o coordenada incompatible produce FormatException. toJson devuelve GeoJSON con longitud antes de latitud. Para INSERT de ayuda el adaptador usa WKT con SRID 4326, construido exclusivamente desde doubles validados. En emisión se envían dos doubles como parámetros RPC. Son ubicaciones aproximadas sujetas al trigger de PostgreSQL.

## Métodos y firmas efectivas

| Método | Consulta y parámetros |
|---|---|
| alerts(mine,offset) | SELECT alertas_sos bajo RLS, orden creado_en DESC e id, página de 50. mine filtra autor_id por UID de sesión |
| detail(id) | SELECT alertas_sos por UUID y single |
| emit(id,kind,type,urgency,description,point,createdLocal) | emitir_alerta(p_id uuid,p_clase clase_alerta,p_tipo tipo_emergencia,p_urgencia urgencia_alerta,p_descripcion text DEFAULT NULL,p_lat double precision DEFAULT NULL,p_lng double precision DEFAULT NULL,p_creado_local timestamptz DEFAULT NULL), retorna uuid |
| cancel(id) | cancelar_alerta(p_alerta uuid), retorna void, seguida por detail para obtener estado persistido |
| nearby(origin,radius) | alertas_cercanas(p_lat double precision,p_lng double precision,p_radio_m int DEFAULT 5000), retorna List de NearbyAlert |
| summary() | resumen_emergencia(), retorna SosSummary o null cuando no hay fila de zona |
| responses(alertId) | SELECT sos_respuestas por alerta_id, orden creado_en e id. RLS limita participantes/admin |
| offer(id,alertId,resourceId,message,point) | INSERT sos_respuestas con voluntario_id de sesión, UUID estable y estado predeterminado ofrecida. Retorna fila confirmada |
| updateHelp(id,status) | actualizar_ayuda(p_resp uuid,p_estado estado_ayuda), retorna void. Relee sos_respuestas por id después de la RPC |
| resources(offset) | SELECT recursos_criticos por RLS, orden creado_en DESC e id, página de 50. Incluye disponible para que el consumidor distinga estado |
| groups(offset) | SELECT grupos_apoyo por RLS, orden nombre e id, página de 50. Incluye contacto público de zona |

Las firmas se contrastaron con docs/database/001_esquema_base_v5.sql, 002_complemento_v5.sql, 003_correcciones_mvp.sql y los cuerpos efectivos en INSTALACION_UNICA_VECIPULSO_MVP.sql. 003 reemplaza emitir_alerta y actualizar_ayuda. La creación de alertas se realiza exclusivamente por RPC. La identidad del autor la obtiene emitir_alerta desde auth.uid(). El modelo de lectura completo no debe utilizarse como DTO genérico de escritura.

Sin GPS, emit envía p_lat/p_lng nulos y PostgreSQL utiliza el centro de zona. alerts y summary permiten consulta por zona sin GPS. nearby requiere un origen validado. El listado directo incluye historial de alertas mientras que la RPC cercana aplica estados abiertos y ventana de 24 horas. La presentación futura debe elegir deliberadamente la consulta apropiada.

## Estado y concurrencia

SosController representa initial, loading, success, empty, error, offline y denied. SosFailure distingue sesión, permisos, registro ausente, validación, duplicado, cuota de emisión, transición/conflicto, red y servidor. Cada carga limpia los datos anteriores. Una generación invalida respuestas fuera de orden y actualizaciones tras dispose. clear invalida resultados y borra datos privados del controlador. Una escritura pendiente conserva su exclusión hasta finalizar, aunque se invoque clear.

AlertsController consulta alertas propias o visibles. AlertDetailController carga detalle, emite con relectura y cancela con relectura. HelpResponsesController ofrece, actualiza y vuelve a consultar la lista de respuestas de la alerta. ResourcesController y BrigadesController gestionan las listas paginadas. Los consumidores futuros pueden usar SosController con summary/nearby o ampliar controladores según las pantallas de 5.3.

La composición futura debe ejecutar clear o destruir controladores ante cambio de sesión. Una escritura aceptada por el servidor cuya respuesta se pierde tiene resultado incierto. Mantener el mismo UUID para el reintento y consultar el registro antes de generar uno nuevo. emitir_alerta devuelve el mismo UUID si ya existe del autor, sin comparar contenido. Las respuestas usan restricciones de unicidad y no se sobreescriben silenciosamente.

## Seguridad y límites

El repositorio no expone cerrar_alerta. El riesgo crítico de NULL y SECURITY DEFINER descrito en 5.1 sigue pendiente de revisión SQL autorizada. Omitir este método evita introducirlo en la interfaz futura pero el permiso remoto existente continúa requiriendo corrección.

Las reglas de actor, transición, zona y aceptación única se delegan a RLS y a la RPC efectiva. Los controladores no confieren privilegios y no utilizan PIN como autorización. El adaptador no consulta perfiles ajenos ni teléfonos de perfiles. SupportGroup.contacto es público de zona conforme al contrato. Los campos geográficos leídos proceden de ubicacion_aprox. Los errores públicos omiten detalles SQL, payloads y credenciales. No se imprime información personal.

responses y nearby están sujetos al límite de filas del servidor. alerts/resources/groups disponen de desplazamiento para carga progresiva. La capa no incorpora matching, chat, membresías, push, suscripciones Realtime ni cierre administrativo. Estas operaciones se revisarán cuando la presentación las requiera. El parche 003 debe estar desplegado para garantizar aceptación única y cancelación individual segura.

## Validación

Las pruebas usan HTTP simulado con el SDK real y una implementación de SosRepository sin cliente para verificar la inyección en todos los controladores. Cubren serialización de tablas/RPC, NULL, UUID, UTC, GeoJSON/WKT/EWKB, parámetros de emisión y ayuda, identidad del voluntario, listas vacías, errores remotos/red/permisos/sesión/cuota, reintento, concurrencia, clear y dispose.

Las integraciones remotas existentes de auth y servicios, la explotación controlada del hallazgo SQL y las pruebas Android quedan sin ejecutar. Esta entrega termina en la capa de datos de 5.2.

### Resultados finales

flutter analyze terminó sin incidencias. flutter test --concurrency=1 aprobó 157 pruebas en 2 min 48 s, incluidas 11 pruebas SOS nuevas. La suite SOS aislada aprobó también sus 11 casos. Cero fallos pendientes. Se formatearon exclusivamente los cuatro archivos Dart nuevos. git diff --check terminó con exit 0 y se revisaron explícitamente los archivos nuevos sin añadir al índice.

El estado Git final contiene los dos documentos previos de 5.1 y los cinco archivos nuevos de 5.2. No existen modificaciones de archivos versionados ni cambios de rama.
