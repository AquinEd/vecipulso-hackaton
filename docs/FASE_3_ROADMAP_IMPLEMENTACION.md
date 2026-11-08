# Fase 3 — Roadmap de implementación posterior a la auditoría

Fecha: 2026-11-08. Este archivo es un plan: no crea clases, pantallas, migraciones ni pruebas nuevas. Contrato y brechas: [contrato SQL](FASE_3_1_CONTRATO_SUPABASE.md) y [auditoría](FASE_3_1_AUDITORIA_SERVICIOS.md).

## Arquitectura mínima propuesta para 3.2

Seguir la implementación efectiva de auth: interfaz abstracta y adaptador Supabase en `data/auth_repository.dart`, constructor que recibe SupabaseClient, modelos con parseo explícito y ChangeNotifier con dependencias inyectadas. `docs/ARCHITECTURE.md` contiene descripciones históricas de auth demo y sugiere data/repositories; para este módulo se sigue el patrón **actual del código** `data/…_repository.dart`, sin directorio paralelo redundante. Mantener `provider` y `go_router`.

Todos los archivos siguientes son propuestos, no existentes salvo donde se indique. Un archivo puede agrupar pequeños tipos relacionados para evitar clases/archivos triviales.

| Archivo bajo `lib/` | Responsabilidad y operaciones |
|---|---|
| `features/services/models/service_model.dart` | ServiceCategoryModel(id,nombre,icono), ServiceModel (campos reales de tabla), ServiceSummary (resultado RPC con promedio nullable, distancia/origen y sello), ServiceDetail compuesto y trabajos. Guardar nombre_publico íntegro, no nombres privados; no reemplazar contratos por ServicePreview demo. Parsear num→int/double, NULL, fechas y UUID sin inventar defaults de valoración |
| `features/services/models/service_request_model.dart` | Enum con los cuatro estados SQL, solicitud y proyecciones recibida/enviada; mensajes y puedo_recomendar. Diferenciar solicitante/proveedor visibles como nombre de sus IDs ausentes en RPC |
| `features/reviews/models/recommendation_model.dart` | ID, servicio cuando se conozca por contexto, autor público, puntaje 1–5, comentario nullable, fecha. DTO de creación separado de respuesta RPC (no devuelve autor_id/servicio_id) |
| `features/services/data/services_repository.dart` | Interfaz ServicesRepository y SupabaseServicesRepository(client). Leer categorías, zona propia, servicios por zona/cercanía, servicio por ID, proyección pública, trabajos, puntajes completos y contacto permitido. Publicar/editar/desactivar servicio propio y gestionar contacto/trabajos. No autenticar, no almacenar PIN, no exponer cliente a widgets. Agregados coherentes y filtro por categoría exacta |
| `features/services/data/service_requests_repository.dart` | Interfaz/adaptador para INSERT solicitud, mis_solicitudes_enviadas/recibidas y actualizar_solicitud_servicio. Recuperar resultado después de respuesta perdida por ID estable; no UPDATE directo de estado |
| `features/reviews/data/recommendations_repository.dart` | Interfaz/adaptador: RPC resenas_de_servicio, INSERT recomendación autorizada; edición/borrado solo si se incluyen explícitamente en alcance. Reportar UNIQUE como duplicado; no upsert silencioso |
| `features/services/presentation/controllers/services_controller.dart` | Categorías/lista, texto/categoría/radio/rating, origen GPS o zona, refresco y conservación de filtros; descartar respuestas viejas con contador/generación como auth. Compartir estado entre Home y directorio sin duplicar fuente |
| `features/services/presentation/controllers/service_detail_controller.dart` | Cargar por UUID aun con entrada directa, componer servicio/proveedor/trabajos/reseñas/contacto, elegibilidad propia; solicitar, refrescar agregados tras volver. Recibe repositorios por constructor |
| `features/services/presentation/controllers/service_requests_controller.dart` | Bandejas propias, permisos visuales por estado/rol, cambios por RPC y refresco posterior. No inferir rol proveedor por texto/nombre; usar proveedor_id del servicio y userId actual |
| `features/reviews/presentation/controllers/recommendation_controller.dart` | Servicio seleccionado, elegibilidad, validación 1–5/comentario, envío único, reconciliación y éxito/error. RLS decide autorización final aunque la consulta previa permita el botón |
| `features/services/presentation/controllers/service_editor_controller.dart` | En 3.6: borrador de servicio, categoría real, experiencia, consentimiento/contacto optativos, progreso y éxito parcial. En 3.2 basta definir su contrato en diseño; no crear estructura vacía |
| `core/errors/services_failure.dart` | Error de dominio para red, sesión, validación, referencia ausente, denegado, duplicado y transición. No reutilizar `AuthFailure.duplicate`: ese mensaje habla de DNI. No modificar auth |

El modelo `services/models/service_preview.dart` existente sigue siendo demo hasta adaptar las vistas. No introducir otro catálogo hardcoded para datos reales ni fabricar apellido, occupation o summary; usar categoría/descripcion como presentación y `nombre_publico` como nombre. Iconos quedan en widgets, con fallback para catálogo ampliado.

Inyección: componer los repositorios con el cliente existente en el punto de arranque/composición, junto a auth sin cambiar su lógica; Provider para repositorios e instancias ChangeNotifierProvider con alcance de feature/ruta. Si se amplía `VeciPulsoApp`, conservar el constructor de auth y permitir fakes en tests. No usar Supabase.instance desde modelos/widgets ni nuevos logins. El servicio de zona puede leer `perfiles(id,zona_id)` propio sin ampliar `AuthRepository` ni `Profile` de auth, que hoy solo contiene userId. Limpiar datos de feature ante cambio de sesión para no filtrar contacto/mensajes de otro usuario; no mezclar cachés entre zonas/usuarios.

Lecturas: RPC para cercanía/perfiles públicos/reseñas/bandejas; SELECT para categorías/servicio/trabajos/contacto/zona propia y recomendaciones para agregación de detalle sin radio. Escrituras: INSERT directo de servicio/contacto/trabajos/solicitud/recomendación y UPDATE permitido de servicio/contacto; transición de solicitud **por RPC**. No nuevas funciones SQL implícitas. Si hacen falta agregados paginados o centro legible, abrir alcance SQL separado, no improvisarlos en Dart.

Estados mínimos: inicial, cargando, datos, vacío, error recuperable; detalle además no encontrado/no visible. En escrituras: idle, enviando, confirmado, error y resultado incierto cuando pudo persistir. Contacto ausente es estado válido, no error de pantalla completa. Una sección con error (reseñas/contacto) debe permitir reintento sin perder servicio/formulario. Mantener datos previos solo para lecturas con indicador de antigüedad; no presentar datos demo como caché real.

Red: timeout similar al de auth (20 segundos como convención inicial), traducción segura de errores y reintento explícito. No dependencia nueva de conectividad: detectar fallo de operación. No cola persistente ni PowerSync; no prometer sincronización por tener OfflineDemoController. Generar UUID estable por intento de creación y consultar antes de reintentar tras timeout. Usar UNIQUE para solicitud viva y recomendación; no duplicar servicio ni sobrescribir reseña al reintentar. Cerrar/bloquear botones durante envío sin bloquear toda navegación. Descartar respuesta tras dispose/cambio de usuario o filtros.

## 3.2 — Modelos, repositorios, controladores y pruebas unitarias

- Archivos: modelos, repositorios, error y controllers de lectura/solicitudes/reseñas de la tabla anterior; propuestos `test/services_models_test.dart`, `test/services_repository_test.dart`, `test/service_requests_test.dart`, `test/recommendations_repository_test.dart`, `test/services_controller_test.dart`, `test/support/services_fixture.dart`. Sin repositorios/clases vacíos; agrupar suites si resulta más claro.
- Dependencias: contrato SQL verificado y cliente Supabase existente; sin paquetes nuevos, cambios de auth ni pantallas. Resolver semántica de filtro categoría/texto y origen zona antes de cerrar contratos de métodos.
- Funcionalidad: parseo, interfaz/adaptadores de consulta y escritura, fallos seguros, estados y DI; fallback de zona completo sin distancias; lectura de elegibilidad y reglas de estados. Adaptador probado con transporte HTTP falso disponible en dependencias existentes cuando sea factible; controllers probados con fakes por interfaz, sin red real.
- Aceptación: valores NULL/números/fechas correctos, parámetros RPC exactos, ninguna columna inventada, sin join privado de perfiles, filtro sin GPS no llama RPC con coordenadas nulas; timeout/duplicado/RLS traducidos, respuesta antigua descartada, doble pulsación no duplica operación. No cambia navegación/auth ni se usa auth demo para el backend.
- Riesgos: parseo geography/numeric y campos ausentes en RPC; no presentar DTO parcial como fila completa. No adelantar búsqueda/filtros incompatibles con backend.
- Fin: capas funcionales con unitarias aprobadas, analyze y suite existente verdes, UI aún intacta. Las pruebas con fakes no acreditan RLS real.
- Commit sugerido (no ejecutar en 3.1): `feat(services): add Supabase data layer and controllers`.

## 3.3 — Directorio y filtros conectados a Supabase

- Archivos: `services/presentation/screens/services_screen.dart`, `services/presentation/widgets/{service_list_card,service_heading}.dart`, `home/presentation/screens/home_screen.dart`, `home/presentation/widgets/{home_category_selector,nearby_service_card}.dart` según necesidad; controllers/repository, composición en `app/app.dart` o `main.dart` sin cambiar auth. Nuevas pruebas de widgets sobre estas vistas; conservar pruebas demo útiles con inyección.
- Dependencias: 3.2; categorías reales y política Todos=zona completa, ubicación/fallback decidida. Primer MVP puede operar solo por zona; GPS requiere trabajo de plataforma posterior autorizado, no presuponer paquete disponible.
- Funcionalidad: listado real compartido con portada, selector mínimo de categoría usando componentes actuales, filtros 500/1000/4+, estados accesibles, búsqueda compatible. Debounce y generación para peticiones de texto. Solo retirar avisos demo en vistas convertidas. No cambiar las rutas.
- Aceptación: categorías Cocina/Jardinería con fallback visual, sin GPS zona real sin metros engañosos, con coordenadas válidas radio inclusivo y orden correcto, 4+ con promedio crudo, vacío y reintento, retorno desde ficha conserva filtros. Cambio de categoría no usa p_texto como igualdad.
- Riesgos: búsqueda por proveedor difiere de RPC, radio default 3000 no significa Todos, límite de filas Supabase puede invalidar filtro local si se ignora. No paginar subconjunto antes de calcular totales/filtros completos.
- Fin: portada/directorio sin datos demo de proveedores; widget/unitarias y smoke de lectura real autorizado/registrado. Mapa queda identificado como ilustrativo y sus enlaces demo no deben aparentar proveedores reales.
- Commit sugerido: `feat(services): connect directory and filters to Supabase`.

## 3.4 — Detalle del proveedor y recomendaciones

- Archivos: `services/presentation/screens/provider_detail_screen.dart`, `reviews/presentation/screens/create_review_screen.dart`, `reviews/presentation/widgets/review_star_selector.dart` solo si es necesario, sus controllers/repositorios; `test/services_test.dart`, `test/reviews_test.dart` y nuevas suites por DI.
- Dependencias: 3.2/3.3, servicio por ID y agregación completa sin depender de radio. Para probar envío autorizado se necesita solicitud completada, aunque su interfaz llegará en 3.5: no simular experiencia ni autorizar escritura de prueba implícitamente.
- Funcionalidad: ficha real, nombre público, trabajos de texto, reseñas/fechas, media/conteo y sello calculados; contacto solo permitido. Conservar `providerId` como clave de URL cuyo contenido es servicio.id. Sustituir preview por confirmación/envío real y estado de elegibilidad; acceso directo sin elegibilidad informa la restricción.
- Aceptación: UUID inválido/inexistente/no visible sin error técnico; sin reseñas promedio sin inventar 0 estrellas; teléfono no autorizado oculto; media y sello consistentes con SQL y refresco tras edición/envío. Si solicitud no completada, no habilitar recomendación; RLS también debe rechazar intento directo en integración posterior.
- Riesgos: catálogo demo requiere apellidos privados, contar solo reseñas visibles/página causa media incorrecta; llamada de plataforma sin paquete actual. Alternativa MVP: mostrar contacto autorizado sin prometer llamada nativa hasta implementar capacidad.
- Fin: detalle/formulario operan con datos reales e inyección, estados y validación de UI cubiertos; escritura real autorizada se verifica al cerrar 3.5/3.6. No declarar flujo completo terminado antes.
- Commit sugerido: `feat(services): connect provider details and recommendations`.

## 3.5 — Solicitudes de servicio y Visto Bueno Vecinal

- Archivos: detalle/directorio existentes, controllers de solicitudes/detalle/recomendación y repositorios; widget propuesto `services/presentation/widgets/service_requests_panel.dart` con secciones Enviadas/Recibidas. No necesita nueva ruta: acceso desde directorio, panel/modal en misma estructura visual.
- Dependencias: 3.2–3.4; elegir panel mínimo. Las pantallas de ayudas SOS no se reutilizan como solicitudes de servicio.
- Funcionalidad: Solicitar inserta solicitud activa y mensaje opcional; proveedor consulta recibidas y marca contactado/completada/cancelada por RPC; cliente consulta enviadas/cancela y recomienda cuando puedo_recomendar. Releer después de cada transición. Sello con regla SQL existente, sin añadir umbral.
- Aceptación: A proveedor/B cliente de misma zona completan consultar→solicitar→completar(A)→recomendar(B)→actualizar promedio/conteo; B no puede completar, A no auto-solicita/auto-recomienda, no segunda viva/reseña duplicada. Estados terminales no reabren. Al volver al listado se refrescan agregados.
- Riesgos: dos usuarios no bastan para tres recomendaciones del mismo servicio; añadir clientes C/D para sello real en prueba independiente o validar umbral unitariamente. Sin push/Realtime de estas tablas, refresco explícito.
- Fin: recorrido con dos sesiones reales autorizado y registrado, restricciones verificadas sin service_role ni relajación de RLS; sello real queda diferenciado de prueba unitaria si faltan autores.
- Commit sugerido: `feat(services): add request lifecycle and neighborhood approval`.

## 3.6 — Publicación de servicios, integración completa y pruebas

- Archivos: directorio actual como entrada; propuesto `services/presentation/widgets/service_editor_sheet.dart`, editor controller y repository; reutilizar AppTextField/AppCard/tema; futura `integration_test/supabase_services_test.dart` solo tras autorizar escrituras y preparar fixtures. No convertir publications del muro en servicios ni cambiar rutas.
- Dependencias: 3.2–3.5; categoría/zona auténticas y decisión de contacto/GPS. El recorrido anterior puede usar servicio fixture previamente autorizado; aquí se cierra publicación desde UI.
- Funcionalidad: modal mínimo Publicar servicio con categoría, título 3–120, descripción opcional, años opcionales 0–80, centro aproximado de zona por defecto; teléfono opcional con autorización explícita inicialmente false. Confirmar servicio solo tras persistir; informar paso de contacto fallido separadamente. Trabajos de texto opcionales, fotos pospuestas por falta de columna URL.
- Aceptación: A publica, B lo encuentra y recorre flujo completo; A edita solo campos permitidos/desactiva, B no modifica/elimina servicio ajeno; teléfono sin consentimiento no aparece; pérdida de respuesta/reintento no duplica registros; prueba de zona ajena, sin red y accesibilidad 320/412 px y texto 150–200%.
- Riesgos: inserciones no atómicas, coordenadas en servicios sin validación de radio de barrio, privacidad del bucket público, dependencia de fixtures de zonas. Evitar borrar datos para limpiar sin autorización adicional.
- Fin: RF-M06…M12 aceptados con evidencia separada de unitarias/widgets/integración, analyzer y suite verdes; cualquier limitación GPS/mapa/llamada/sello real explicitada. Cero claves/payloads privados en logs.
- Commit sugerido: `feat(services): add service publishing and end-to-end validation`.

## Estrategia de pruebas futuras

U = unitaria con fakes/contratos; W = widget con repositorios inyectados; I = integración Supabase con sesiones reales, **pendiente de autorización de escrituras**. Los tests de UI existentes de services/reviews acreditan demostración, navegación, filtros locales, preview y accesibilidad; no RLS ni persistencia. `test/auth_test.dart` usa fakes. La integración real de auth en integration_test no forma parte de `flutter test` sin destino explícito.

| Nº | Caso | U / W | I: evidencia requerida |
|---|---|---|---|
| 1 | Categorías reales | Parseo, icono desconocido, error/vacío; selector | SELECT catálogo; no fijar IDs ni exigir solo cinco oficios |
| 2 | Servicios de zona | Repositorio filtra activo/zona, lista carga/vacío | A y B ven mismo servicio de su zona; inactivos omitidos por listado |
| 3 | Cercanía con coordenadas válidas | Parámetros, rangos/finitud, límites 500/1000 | ST_DWithin y orden/distancia aproximada del punto almacenado; no exigir metros demo |
| 4 | Sin permiso GPS | Proveedor ubicación falso denegado; omitir metros y chips métricos | Fallback por perfil.zona_id; no error de RPC con NULL, no coordenada privada inferida |
| 5 | Categoría | ID exacto, combinación de filtros | Categoría real elegida; ningún p_categoria inexistente |
| 6 | Valoración | 3.9 excluida/4.0 incluida; promedio redondeado no decide | Umbral SQL con reseñas controladas; sin reseñas no cumple 4+ |
| 7 | Detalle | Entrada directa, nulos, no encontrado, errores parciales | UUID real con trabajos/perfil público/reseñas correctos |
| 8 | Contacto | Ausente/denegado oculta acción, no fallback a perfil | A propietario ve contacto no autorizado, B no; A autoriza y B puede leer; revocación vuelve a ocultar |
| 9 | Publicar propio | Validación, estado enviando/éxito parcial/reintento | A crea servicio/categoría real y zona propia, centro aproximado si omite punto |
| 10 | Servicio ajeno | No ofrecer edición a B | B intenta UPDATE/DELETE y no altera filas; comprobar estado luego (denegación puede ser cero filas, no siempre excepción) |
| 11 | Crear solicitud | DTO/UUID estable, doble tap | B→servicio A: estado solicitada, segunda viva rechazada; A auto-solicitud rechazada |
| 12 | Completar | Matriz de transiciones/estados terminales | Solo A puede completar desde solicitada/contactado; B no, tercero no; direct UPDATE sin permiso |
| 13 | Recomendar válida | Entero 1–5, comentario opcional y permiso UI | B antes de completada rechazado; tras completar A, INSERT válido; A auto-reseña rechazada |
| 14 | Duplicado | 23505 traducido y formulario preservado | Segundo ID de reseña B/mismo servicio falla incluso con otra solicitud completada; dos clientes concurrentes del mismo autor no duplican |
| 15 | Media/conteo/sello | 0→NULL/0/false; dos reseñas false; tres y media>=4 true; tres con media<4 false; editar/borrar refresca | B añade y verifica 1 reseña/valor real en búsqueda y detalle. Para activar sello: tres autores distintos clientes, no repetir B; probar con datos suficientes en entorno autorizado |
| 16 | Aislamiento usuarios/zonas | Invalidar estado/caché por sesión y respuesta vieja | A/B misma zona; cliente C de segunda zona no lee/contacta/solicita/recomienda servicio A. Bandejas solo participantes, perfiles privados solo propio |
| 17 | Pérdida de red | Timeout, recuperar lectura, preservar borrador; respuesta vieja tras dispose | Desconexión durante lectura/escritura: no falso éxito, al reconectar reconciliar UUID y evitar duplicado; registrar si servidor ya confirmó |
| 18 | Errores seguros | 42501/23505/23514/23503/P0001 traducidos; no details/hint/payload | Capturar mensaje visible genérico/de dominio y comprobar que no expone teléfono, JWT, SQL o perfil ajeno |

Añadir W para carga/vacío/error/reintento en cada pantalla, validación estrellas 0/1/5/6, comentario de 300 grafemas, teclado/tamaño de texto y navegación Atrás que conserva filtros. U de controllers debe cubrir sesión cambiada, doble envío, respuestas fuera de orden y error parcial de contacto. No reemplazar ni borrar suites de otros módulos.

### Protocolo real con dos usuarios y extensiones necesarias

1. Antes de escribir, obtener autorización explícita para entorno/usuarios/datos de prueba; confirmar definiciones desplegadas con lectura de catálogo y `VERIFICAR_INSTALACION.sql` desde entorno autorizado. No ejecutar instalador ni semilla para «arreglar» discrepancias.
2. A y B, perfiles de prueba ya registrados en misma zona, dos dispositivos/sesiones aisladas; conservar PIN/sesiones fuera de reportes. A publica servicio propio, opcionalmente contacto no autorizado y trabajos de texto; registrar IDs de fixture en evidencia privada de prueba.
3. B consulta categorías/listado/detalle, comprueba contacto oculto y busca por coordenadas válidas y fallback de zona. B solicita, A ve recibidas y B enviadas; segundo intento vivo falla.
4. B intenta completar y se rechaza; A marca contactado si se desea y completa. B ahora puede recomendar una vez. Verificar media/count/puedo_recomendar, refresco de directorio/portada y segundo INSERT rechazado. No pedir al cliente marcar completada ni modificar SQL para habilitar reseñas.
5. Probar A/B contra permisos de edición ajena, autocontratación/autorreseña, acceso a perfiles y transiciones terminales. Desactivar/editar contacto con propietario para comprobar revocación. No registrar teléfono real en fixture.
6. Para aislamiento de zona se necesita al menos un tercer perfil en otra zona ya autorizada; dos usuarios en la misma zona no prueban este aislamiento. Para sello positivo del servicio de A se necesitan tres clientes B/C/D en su zona (cuatro usuarios totales); hacer esta extensión separada del caso de segunda zona. Si faltan fixtures/autorización, marcar casos I no ejecutados y mantener U de umbral.
7. Documentar resultado por caso y entorno sin datos sensibles. No borrar fixtures, cuentas ni otras filas como limpieza automática sin autorización; no debilitar RLS ni emplear service_role para simular cliente. No afirmar integración aprobada a partir de mocks.

## Validación ejecutada en Fase 3.1

| Comando | Resultado observado |
|---|---|
| `flutter pub get` | Aprobado, exit 0; dependencias existentes resueltas. Avisó de siete versiones más nuevas incompatibles con las restricciones actuales; no se actualizaron paquetes ni pubspec/lock |
| `flutter analyze` | Aprobado, exit 0: No issues found (16.7 s) |
| `flutter test --concurrency=1` | Aprobado, exit 0: **122 tests pasaron**, All tests passed, 4 min 26 s; suite local `test/`, incluida auth con fakes, services y reviews demo |
| `git diff --check` | Aprobado, exit 0; además revisión explícita de espacios finales y conflictos de documentos nuevos, aún no añadidos al índice |
| `git status --short` | Solo tres documentos nuevos solicitados; ningún archivo de código/SQL/configuración/dependencias modificado |

Pruebas fallidas: ninguna. Errores preexistentes detectados por analyze/tests: ninguno. Errores nuevos detectados: ninguno. Los riesgos del contrato encontrados por inspección se documentan y no se reparan en esta fase.

Pruebas no ejecutadas: integración real de servicios, escrituras contra Supabase, aislamiento de zonas en servidor, GPS/dispositivo/llamada nativa e `integration_test/supabase_auth_test.dart`. Este último crea usuarios/perfiles y modifica intentos PIN, por lo que no se ejecutó. Los 122 tests locales no acreditan servicios funcionales ni RLS real.

La primera ejecución aislada de `flutter pub get` quedó sin salida; se interrumpió y los tres comandos Flutter se ejecutaron con permiso fuera del aislamiento. Flutter regeneró siete archivos de registro de plugins con cambios solo de finales de línea; se verificó equivalencia de contenido con HEAD y se devolvieron al formato CRLF del checkout. No quedan cambios de estos archivos. No se realizó commit, push, cambio de rama, instalación de dependencias nuevas ni cambio en Supabase.

Archivos entregados:

- `docs/FASE_3_1_AUDITORIA_SERVICIOS.md`.
- `docs/FASE_3_1_CONTRATO_SUPABASE.md`.
- `docs/FASE_3_ROADMAP_IMPLEMENTACION.md`.

Recomendación: comenzar 3.2 con los contratos y fakes documentados; resolver las decisiones de filtros/ubicación y modalidad mínima de bandejas/publicación antes de conectar las vistas en 3.3–3.6. Verificar el esquema desplegado antes de las pruebas reales. El comportamiento funcional del aplicativo queda intacto.
