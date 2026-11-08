# Fase 5.1 — Auditoría técnica de Modo SOS

La auditoría se realizó el 8 de noviembre de 2026 sobre la rama **feat/servicios-visto-bueno**, aunque el encargo identifica feat/modo-sos. El árbol estaba limpio al comenzar. Se mantiene la rama encontrada y se entregan exclusivamente los dos documentos de auditoría. No se hallaron repositorios/controladores SOS conectados ni indicios de implementación funcional adicional de la Fase 5 en este checkout. Esa conclusión se limita a la rama inspeccionada.

README, docs/ARCHITECTURE.md, docs/ROUTES.md y docs/ASSETS.md describen principalmente etapas históricas de demostración. docs/AUTENTICACION_SUPABASE.md y el código de auth/main reflejan la autenticación real. Servicios ya dispone de repositorios, formularios y pruebas, por lo que las menciones antiguas de Supabase pendiente en README no representan el estado general. El contrato literal y los permisos se detallan en [Contrato SOS](FASE_5_1_CONTRATO_SUPABASE_SOS.md).

## Frontend encontrado

Todos los archivos de las pantallas de la tabla están bajo lib/features/emergency/presentation/screens/. El router está en lib/app/app_router.dart y las rutas en app_routes.dart.

| Ruta | Archivo | Responsabilidad y datos actuales | Acciones | Integración mínima y dependencias |
|---|---|---|---|---|
| /sos/tablero, alias /sos | emergency_dashboard_screen.dart | Cabecera de riesgo simulada y cinco reportes de demo_emergency_reports, tres visibles inicialmente | Expandir/contraer, ficha modal, solicitar/ofrecer, centro, mapa, brigadas, salir | Resumen y alertas de zona por repositorio. Estado loading/empty/error/retry. Sustituir tarjetas demo por datos tipados y conservar diseño y advertencia comunitaria |
| /sos/acciones?action=… | emergency_actions_screen.dart | Tres definiciones demoEmergencyActions, trece categorías y ubicación fija | Selector modal con guarda de reapertura, resumen; criticalSupport retorna categoría y navega a confirmación | Formulario de emisión usa emitir_alerta. Ofrecer recurso usa INSERT recursos_criticos. Ofrecer ayuda a una alerta necesita contexto de su UUID, distinto de ofrecer recurso general |
| /sos/confirmacion | help_confirmation_screen.dart | Selección de necesidad por extra, fallback a primer ejemplo si falta, perfil y méritos ficticios | Llamar/Chat/Ubicar/Detalles abren avisos. Simulación de seguimiento pasa ConfirmationOrigin | Mostrar confirmación solo tras UUID persistido. Cargar alerta y ayuda concreta por ID, no inferir aceptación a partir de categoría. Usar contraparte_ayuda cuando exista respuesta y permisos |
| /sos/seguimiento | help_tracking_screen.dart | Categoría en origin, nombre y cifra de ayudas ilustrativos, plano de ruta relativa | Atrás reconstruye origen o tablero; Llamar muestra aviso; Chat abre dos mensajes de lectura; salir | Estados reales de sos_respuestas por RPC y relectura, contraparte autorizada. El plano sigue orientativo hasta tener mapa autorizado. Depende de alerta y respuesta reales |
| /sos/mapa | emergency_map_screen.dart | Seis marcadores relativos de demoEmergencyMapMarkers con reportes, brigadas y refugio | Filtros urgentes/en revisión/recursos/brigadas, fichas modales, volver y salir | Mapear capas de puntos_mapa solo con origen disponible. Lienzo actual no proyecta lat/lng ni sirve como ruta vial. Alternativa mínima es listado de zona, sin distancias falsas |
| /sos/brigadas | brigades_screen.dart | Cuatro demoBrigades, cuadras, integrantes e iconos fijos | Búsqueda normalizada, filtro Todos/Brigadas/Voluntarios, vacío, diálogo Contacto no disponible | SELECT grupos_apoyo por RLS, sector textual libre y contacto público de zona. Mantener consulta sin altas de membresía. Depende de zona de perfil |

Las rutas de acciones y seguimiento poseen su Scaffold y AppShell les cede el espacio. Tablero y mapa usan AppModeDestination/IndexedStack y AppModeController (normal/sos), que solo conserva modo de navegación. AppNavigation gestiona salida y destinos. El router activa SOS por entradas directas y conserva guardas AuthController. No sustituir el controlador de modo por un controlador de datos ni duplicar barras inferiores.

### Modelos, componentes y datos

- EmergencyReport contiene título, descripción, EmergencyCategory, EmergencyPriority, distanceLabel e isDemo. EmergencyPriority mezcla Crítica/Urgente con En revisión, mientras SQL separa urgencia de estado. No serializar estos enums por índice o nombre.
- EmergencyActionType (neighborAlert,criticalSupport,offerResources) y EmergencyActionCategory son selecciones visuales. Mapear medicalHelp y health a salud según clase, foodAndWater a agua_alimentos, transportOrShelter a traslado_refugio y firstAid a botiquin. No enviar nombres Dart como enums PostgreSQL.
- CommunityBrigade usa startBlock/endBlock y memberCount obligatorios. grupos_apoyo tiene sector text y integrantes nullable, sin rango numérico de cuadras. El filtro por cuadras actual es lógica local de demo.
- EmergencyMapMarker usa Offset relativo y referencias a reportes/brigadas. ConfirmationOrigin solo conserva categoría. Ninguno contiene UUID real de alerta o ayuda.
- emergency_report_card/details, emergency_action_card/selector/summary, brigade_card, emergency_map_canvas, help_route_preview y help_demo_chat_sheet son presentación local. Reutilizan AppCard/AppButton/AppTextField, el tema y IllustratedStreetsPainter. No invocan Supabase.
- demo_emergency_reports.dart, demo_emergency_actions.dart, demo_emergency_map_markers.dart y demo_brigades.dart alimentan pantallas productivas con datos identificados como ejemplos. Los IDs demo-* no sirven para columnas uuid. Los nombres, mérito del voluntario, chat, metros y ruta del seguimiento son constantes adicionales dentro de presentación.
- Tests de SOS usan fakes de auth y escenarios locales. Son fixtures de pruebas únicamente los creados en test/. Los catálogos de lib siguen siendo datos demo aunque también los importen los tests.

Recursos existentes incluyen Banner_Modo_SOS_Sin_Texto, Fondo_Emergencia_Oscuro_Sin_Texto, Icono_Modo_SOS, Icono_Brigadas, Icono_Ofrecer_Ayuda, Icono_Solicitar_Ayuda, Pin_Brigada y Pin_Ayuda_Humanitaria en PNG/SVG. Alerta_Barrio, Sirena_Emergencias y Donacion_Recursos son ilustraciones PNG. AppAssets y AppAssetImage ya proporcionan acceso. docs/ASSETS.md documenta las referencias de design/references/screens. Los dibujos actuales no dependen de GPS ni de un proveedor cartográfico.

## Seguridad y riesgos

| Gravedad | Hallazgo estático | Impacto y siguiente comprobación |
|---|---|---|
| Crítica | cerrar_alerta SECURITY DEFINER usa IF NOT(mi_rol()='admin' OR EXISTS ayuda autorizada). Una sesión authenticated sin perfil produce NULL OR false y el IF omite el rechazo | Un UUID de alerta abierta ajena puede alcanzar el UPDATE, incluso fuera de zona, su cierre, confianza y cancelación de ayudas. 001:961–985 e instalador:978. Confirmar en entorno autorizado con usuario sin perfil. Proponer corrección explícita de sesión/perfil y condición IS NOT TRUE en tarea SQL posterior |
| Alta de despliegue | El parche 003 determina la seguridad efectiva | Sin él, actualizar_ayuda de 001 permite varias selecciones y cancelar una oferta cancela las otras. Con él, bloqueo de alerta + índice único parcial serializan selección, y cancelación individual conserva el resto. Verificar catálogo instalado antes de conectar acciones |
| Media | confirmaciones_de(p_alerta) cuenta por UUID sin visibilidad de zona | Fuga limitada de conteo a authenticated. Añadir comprobación de alcance en futura revisión SQL. No cargar conteos de alertas que la UI no haya obtenido por RLS |
| Media | Recursos se asocian sin reserva de stock/disponibilidad | El mismo recurso puede respaldar varias ayudas, incluso si ya no está disponible. No prometer asignación exclusiva ni disponibilidad confirmada por el mero matching |
| Media | Precisión y texto libre | Se aplica rejilla aproximada, pero puntos de zona escasa y descripciones pueden revelar información. No hay garantía de anonimato absoluto. Reducir campos de proyección y no publicar ubicaciones privadas en logs |
| Media | Cuotas y concurrencia de INSERT directo | preparar_alerta sí bloquea perfil para su cuota. El limitador genérico de recursos cuenta filas por creado_en y el INSERT permite aportar ese campo; no equivale a una cuota imposible de eludir. Probar concurrencia por separado |
| Media | Falta de confirmación remota en Flutter SOS | Todas las acciones actuales son demostraciones. La interfaz de confirmación no acredita persistencia, aceptación ni llegada de ayuda. En 5.3/5.4 vincular éxito a RPC y relectura |
| Baja | Documentación general histórica y rama distinta | Riesgo de diseñar sobre un estado equivocado. Usar los cuerpos SQL efectivos y preparar la rama de integración con el equipo después de esta auditoría |

Los perfiles ajenos solo se exponen por proyección pública. contraparte_ayuda devuelve teléfono únicamente a participantes con compartir_telefono y estado aceptada/en_camino, y el punto de voluntario puede ser NULL. Ese consentimiento no se hereda de servicio_contacto. grupos_apoyo.contacto es público dentro de la zona por diseño SQL. El rol lider de grupo_miembros no puede autoasignarse por API con 003, porque se revocaron INSERT/DELETE y no existe UPDATE concedido.

No hay UPDATE directo concedido sobre alertas_sos ni sos_respuestas. El solicitante acepta o cancela, ambos participantes pueden completar una ayuda aceptada/en camino y solo el voluntario puede pasar a en_camino. Una segunda aceptación concurrente se serializa y rechaza. Completar una ayuda cancela ofertas competidoras deliberadamente. Cancelar la alerta completa también cancela ayudas, distinto de retirar una oferta individual.

Sin GPS, emitir_alerta admite ambas coordenadas omitidas y utiliza centro de zona aproximado. Para consultar, resumen_emergencia y SELECT de alertas por RLS permiten el tablero de zona. alertas_cercanas no acepta un origen omitido como fallback. El centro es geography, no columnas lat/lng. No fabricar coordenadas de Lima ni mostrar metros desde el dispositivo sin un origen autorizado.

## Arquitectura y plan de implementación posterior

El patrón actual reutilizable es interfaz/repositorio inyectado con SupabaseClient, errores de dominio, ChangeNotifier y Provider. main.dart inicializa un solo cliente, auth gestiona sesión/PIN y el router se refresca con AuthController. Mantener esa infraestructura. Los archivos propuestos quedan bajo lib/features/emergency/ y no se crean en 5.1.

| Subfase | Archivos propuestos y existentes | Dependencias y alcance | Aceptación y riesgos |
|---|---|---|---|
| 5.2 Capa de datos | models/sos_models.dart para filas/enums/RPC; data/sos_repository.dart, data/help_repository.dart, data/resources_repository.dart; presentation/controllers/sos_controller.dart, help_controller.dart, resources_controller.dart; core/errors/sos_failure.dart | Parsear UUID, fechas, numeric, campos nulos y puntos aproximados. Inyectar cliente y repositorios. Lecturas de zona, RPC de emisión/estado, INSERT de respuesta/recurso y catálogos | Unitarias de parámetros exactos, errores, UUID estable, red, cancelación/dispose y respuestas fuera de orden. No mapear prioridad demo como enum SQL. La vulnerabilidad de cerrar_alerta necesita seguimiento explícito |
| 5.3 Emisión y consulta | emergency_dashboard_screen.dart, emergency_actions_screen.dart, emergency_report_card/details y controllers de SOS | 5.2. Mostrar resumen de zona y alertas últimas 24h. Formularios con clase/tipo/urgencia, descripción y UUID estable. Sin GPS usar centro de perfil en emisión y listado de zona en consulta | Éxito solo tras RPC, límite tres/hora, no doble envío, reconsulta tras timeout, nulos y catálogo vacío. Probar autor/otro usuario/otra zona. Cierre sensible sujeto a resolución SQL autorizada |
| 5.4 Gestión de ayuda | help_confirmation_screen.dart, help_tracking_screen.dart, controller/repositorio de ayuda y modelos ConfirmationOrigin | 5.3. Ofrecer sobre alerta concreta, recibir listas privadas, aceptar, en_camino, completar/cancelar por RPC y cargar contraparte. Transportar IDs reales mediante rutas/extra revisados cuando se implemente | Prueba con autor A y voluntarios B/C para carrera de aceptación. Cancelar B no cancela C. Completar cierra alerta. Probar acceso tercero, nulos de ubicación/teléfono y reconexión. No mostrar confirmación antes del servidor |
| 5.5 Recursos y brigadas | brigades_screen.dart, brigade_card.dart, formularios compactos de recurso sobre acciones; repositorio/controller de recursos | 5.2/5.3. SELECT grupos por zona; ofrecer y administrar recurso propio, matching sugerido para autor mediante RPC. Membresías en solo lectura | Tipos reales/cantidad positiva, nullable integrantes/contacto y sector libre. Sin autopromoción a lider. Probar recurso ajeno, no disponible, zona y sugerencia sin asignación automática |
| 5.6 Integración | test/sos_models_test.dart, sos_repository_test.dart, help_controller_test.dart, widgets SOS y futuro integration_test/supabase_sos_test.dart | 5.2–5.5. Rutas actuales/guardas, estados loading/empty/error/retry, refresco explícito y suscripciones Realtime pertinentes con dispose | Suite anterior y nuevas verdes. E2E autorizado A/B/C, cuotas, privacidad y concurrencia; Android 320/412 y texto 150–200%. Evidencia de backend separada de mocks. Aún requiere catálogo remoto y resolución del riesgo crítico |

En las escrituras no poner offline_demo_controller como cola real ni incorporar PowerSync. Mantener IDs de operación para reconciliar respuestas perdidas, no cambiar autor en reintentos y no anunciar éxito sobre un resultado incierto. Los errores PostgREST/PLpgSQL deben traducirse sin exponer payloads, DNI, PIN, JWT ni detalles SQL. La búsqueda/lista debe paginarse y descartar resultados antiguos. Los contactos y otras lecturas privadas se limpian ante cambio de usuario.

### Pruebas a preparar en las siguientes subfases

- Unitarias de enums exactos, formatos de coordenadas según proyección, fechas UTC, UUID, urgencia/estado separados y filtros de 24 horas.
- Repositorios con HTTP simulado para firma de emitir_alerta/actualizar_ayuda, errores de cuota/perfil/no autorizado/transición, confirmación y duplicados.
- Widgets de carga/vacío/error/reintento, selección obligatoria y datos reales por UUID. Conservar las suites emergency_dashboard, emergency_actions, help_confirmation, help_tracking, emergency_map, brigades, app_mode_navigation, accessibility y auth.
- Integración controlada con A autor, B/C voluntarios y D de otra zona. Verificar aceptar a la vez, completar/cancelar/cerrar a la vez, retirar una oferta, cuotas, confirmar tres veces desde tres vecinos, no confirmar propia/cerrada, ausencia de perfil, privacidad de contraparte y lectura de grupos. Requiere autorización de escrituras y datos sintéticos. No se ejecutó en esta auditoría.

## Preparación para 5.2

Puede comenzar el diseño y las pruebas con fakes de los contratos de lectura/emisión/ayuda. Antes de habilitar cierre de alertas, atender el hallazgo crítico mediante una revisión SQL autorizada y confirmar la instalación de 003. La discrepancia de rama necesita coordinación del equipo para integrar los documentos en feat/modo-sos. Esta ejecución conserva la rama y termina en la Fase 5.1.


## Validación ejecutada

flutter analyze terminó con exit 0, sin incidencias, en 9,0 s. flutter test --concurrency=1 aprobó las 146 pruebas locales con exit 0 en 2 min 36 s. No hubo pruebas fallidas ni errores nuevos detectados. Los riesgos SQL son hallazgos de inspección estática y no se corrigieron durante esta fase.

git diff --check terminó con exit 0. Como los documentos son nuevos y no están en el índice, también se comprobaron explícitamente finales de línea, espacios finales, delimitadores Markdown y ausencia de marcadores de conflicto. git status confirma que solo se crearon docs/FASE_5_1_AUDITORIA_SOS.md y docs/FASE_5_1_CONTRATO_SUPABASE_SOS.md.

No se ejecutaron las dos integraciones remotas existentes de autenticación y servicios, ni nuevas pruebas SOS contra Supabase. Requieren escrituras y no corresponden a esta auditoría. Tampoco se verificó manualmente Android. La suite local acredita las demostraciones y las demás funcionalidades cubiertas por los tests, no la explotación o mitigación remota de los hallazgos SOS.
