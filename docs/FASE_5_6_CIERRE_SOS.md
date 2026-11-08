# Fase 5.6 — Integración y cierre del Modo SOS

Fecha: 2026-11-08. **Implementación local integrada; validación integral parcial. Integración real pendiente. No se recomienda merge ni despliegue todavía.**

La rama encontrada sigue siendo `feat/servicios-visto-bueno`, no `feat/modo-sos`. Se conservó el árbol de trabajo con todos los cambios previos 5.1–5.5. No se ejecutaron operaciones Git de escritura, cambios de esquema, RLS ni escrituras remotas. Tampoco se desarrolló Fase 6.

## Estado de las subfases

| Subfase | Estado | Evidencia | Bloqueos |
|---|---|---|---|
| 5.1 | Completa | Auditoría y contrato contrastados con scripts 001/002/003 e instalador único | La auditoría identifica un defecto crítico SQL todavía pendiente |
| 5.2 | Completa, local | Modelos, repositorio Supabase inyectable y controladores; suite sos_data_test | RLS y despliegue remoto no acreditados por mocks |
| 5.3 | Parcial | Emisión, zona sin GPS, listado, mis alertas, detalle y cancelación propia; tests de formulario y recorrido con PIN | Emisión/consulta reales y Android pendientes |
| 5.4 | Parcial | Ofrecer, aceptar, cancelar, en camino y completar por actualizar_ayuda; reconciliación y relectura | Requiere confirmar 003 instalado y ejecutar carreras con sesiones reales |
| 5.5 | Parcial | Catálogos reales por repositorio, filtros, detalles y contacto público; tests de SDK y widgets | Lecturas y aislamiento de zona remotos pendientes |
| 5.6 | Parcial | Composición de recorridos locales, correcciones, integración remota preparada y guía de aceptación | Prueba real pendiente y cerrar_alerta insegura en el contrato versionado |

«Completa, local» describe implementación y pruebas aisladas; no certifica el backend desplegado. Los informes 5.1–5.5 registran los resultados históricos de cada entrega, no sustituyen este cierre.

## Auditoría del código y contrato efectivo

Se revisaron docs/FASE_5_1_AUDITORIA_SOS.md, FASE_5_1_CONTRATO_SUPABASE_SOS.md y documentos 5.2–5.5; repositorio, modelos, controladores, pantallas, Provider de main.dart, GoRouter y suites SOS/auth/servicios. El contrato es 001_esquema_base_v5.sql → 002_complemento_v5.sql → 003_correcciones_mvp.sql. INSTALACION_UNICA_VECIPULSO_MVP.sql incorpora esas versiones y datos de demostración. No se leyó el catálogo remoto ni su configuración privada.

| Entidad/operación | Uso efectivo |
|---|---|
| alertas_sos | SELECT bajo RLS de zona, filtro autor en Mis alertas, detalle UUID |
| emitir_alerta(p_id uuid, p_clase clase_alerta, p_tipo tipo_emergencia, p_urgencia urgencia_alerta, p_descripcion text, p_lat double precision, p_lng double precision, p_creado_local timestamptz) → uuid | Formulario con UUID estable, autor/zona decididos por PostgreSQL. 003:167 reemplaza 001:929; defaults y cuerpo completos en contrato 5.1 |
| cancelar_alerta(p_alerta uuid) → void | Autor cancela alerta abierta; relectura de fila. 001:988 |
| sos_respuestas | INSERT con voluntario_id tomado de sesión; SELECT de todas las páginas autorizadas por alerta. 001:275,1526 |
| actualizar_ayuda(p_resp uuid,p_estado estado_ayuda) → void | Relectura de respuesta/alerta tras transición. Cuerpo efectivo 003:31–97, bloqueo alerta→respuesta, aceptación única |
| perfiles_publicos_de_mi_zona() | Solo nombre público para participantes visibles; no perfiles privados ni teléfonos |
| recursos_criticos, grupos_apoyo, zonas | SELECT paginado, filtros tipo/nombre y detalle bajo RLS. Ver contrato detallado 5.5 |
| alertas_cercanas, resumen_emergencia | Adaptadores de lectura existentes en capa de datos; el tablero actual usa listado directo por zona, sin prometer distancias ni un resumen conectado |
| cerrar_alerta, confirmaciones_de | No invocadas desde la interfaz conectada por los riesgos pendientes |

No hay RPC inventadas ni consultas directas a Supabase desde widgets. Se comparte el cliente inicializado en main.dart. Los controladores ChangeNotifier dependen de SosRepository y se observan mediante Provider/ListenableBuilder. No se añadió gestión de estado, almacenamiento offline, suscripción Realtime ni GPS.

## Recorridos y pantallas

| Recorrido | Implementación y comprobación local | Evidencia remota |
|---|---|---|
| A: PIN → SOS → emitir → confirmación | VeciPulsoApp y guardas reales de ruta con AuthRepository simulado; formulario y repositorio SOS simulado compartido | Pendiente |
| B: PIN B → zona → detalle → ofrecer | Segundo desbloqueo independiente en widget; UUID del servicio SOS seleccionado, confirmación explícita y respuesta registrada en fake | Pendiente |
| C: PIN A → Mis alertas → aceptar → estado B | Se reconstruye sesión A, acepta y B vuelve a consultar. Pruebas previas cubren completar/cancelar, errores y carreras simuladas | Pendiente |
| D: recursos → detalle | Desde tablero, diálogo, registro seleccionado y regreso | Pendiente |
| E: brigadas → información pública | Ruta existente, detalles opcionales, contacto público y regreso | Pendiente |
| F: red → error → recuperar | Error simulado visible, reconsulta y recuperación; tests anteriores de respuesta de emisión/oferta perdida | Pendiente |

Pantallas conectadas: emergency_dashboard_screen.dart delega a LiveSosDashboard en /sos/tablero; emergency_actions_screen.dart usa AlertEmissionForm en /sos/acciones; sos_alert_views.dart contiene emisión/detalle/cancelación; sos_help_board.dart gestiona ofrecimientos dentro del detalle; brigades_screen.dart delega al catálogo en /sos/brigadas; sos_catalog_screen.dart muestra recursos en modal y grupos en ruta existente. No se añadieron rutas.

Los formularios muestran carga y bloquean escrituras repetidas. Solo hay éxito tras respuesta de servidor confirmada. Un corte posterior a emisión conserva UUID y exige consulta antes de reintentar; un corte de transición requiere actualizar respuestas. No hay cola offline ni reintentos automáticos. Las lecturas limpian datos anteriores y descartan generaciones antiguas/dispose. Los mensajes públicos no imprimen detalles SQL ni credenciales. Existe aviso de coordinación comunitaria que no sustituye servicios oficiales.

Sin GPS se usa exclusivamente el centro aproximado de la zona de perfil permitido por emitir_alerta: ambas coordenadas omitidas. No se solicita permiso, por lo que GPS denegado no bloquea ese flujo. No hay coordenadas ficticias ni distancias desde el dispositivo. Recursos/grupos muestran zona y presencia de ubicación aproximada, sin coordenadas numéricas. La disponibilidad de recursos es un dato registrado, sin stock reservado ni seguimiento.

## Correcciones de 5.6

1. AlertEmissionController queda ligado a la identidad que abrió el formulario. Comprueba sesión antes de emitir/reconciliar y después de cada respuesta; un cambio de identidad impide confirmar o reenviar desde ese formulario. También rechaza un UUID de retorno distinto del solicitado.
2. El centro SOS conectado incorpora PopScope para que Atrás Android vuelva al tablero, igual que su diseño demostrativo. No cambia GoRouter ni autenticación.
3. Se incorpora test/sos_closure_test.dart: prueba de sesión durante envío y recorrido compuesto A/B con PIN, catálogos, error y regreso de Android.
4. Se prepara integration_test/supabase_sos_test.dart, cerrado por defecto y sin ejecutarlo contra internet.

La documentación histórica 5.2 indicaba una lectura de respuestas limitada por página; la implementación actual de 5.4 recorre todas las páginas hasta vacía y descarta resultados parciales si falla alguna. El tablero de 5.3 consulta historial paginado, no solo 24 horas, y no conecta resumen_emergencia. Esas diferencias no se presentan como funciones implementadas adicionales.

## Seguridad y bloqueos para producción

### Crítico: cerrar_alerta

001_esquema_base_v5.sql:961–985, consolidado en INSTALACION_UNICA_VECIPULSO_MVP.sql:978, conserva SECURITY DEFINER con `IF NOT (mi_rol()='admin' OR EXISTS ayuda_autorizada)`. mi_rol() retorna NULL si la sesión no tiene perfil. NULL OR false deja NULL y el IF no rechaza. authenticated puede tener sesión anónima de Auth sin perfil y dispone de EXECUTE; con un UUID ajeno abierto podría alcanzar el UPDATE privilegiado, afectando estado, ayudas y confianza. No se ejecutó una explotación remota.

**Afecta al cierre directo de cualquier alerta por esa RPC y a la seguridad general del proyecto, aunque Flutter no la exponga.** La cancelación propia y la finalización mediante actualizar_ayuda usan funciones distintas, pero no eliminan esa vía de ataque. No se recomienda despliegue ni merge de producción hasta una revisión SQL autorizada y prueba real. La corrección a revisar debe exigir sesión/perfil explícitos y rechazar la autorización cuando la expresión `IS NOT TRUE`; debe conservar las restricciones de actor y transiciones del contrato. No se cambió SQL ni se aplicó una migración.

### Otros riesgos

- 003 debe estar instalado: el cuerpo viejo de actualizar_ayuda cancelaba ofertas independientes y no serializaba adecuadamente la aceptación. El cuerpo final corrige ambas cosas y añade índice único parcial. Flutter no acredita qué versión está desplegada.
- confirmaciones_de de 001:1331 cuenta por UUID sin comprobar zona/visibilidad. Es una fuga limitada de conteo pendiente; la interfaz actual no la usa.
- La autorización de recursos/grupos es por zona y las respuestas por participante/autor/admin. La interfaz no sustituye RLS. Completar y cancelar una alerta completa sí cancelan otras ofertas deliberadamente; cancelar solo una respuesta no debe hacerlo.
- Grupo_miembros no admite autopromoción bajo 003:116–118. La política anterior 002 aislada sí admitía rol lider. No hay administración de membresías en Flutter.
- No se consultan teléfonos de perfiles ni contraparte_ayuda; solo contacto público de grupo. No hay service_role ni claves administrativas en código SOS. El PIN sigue siendo bloqueo local de interfaz, sin reemplazar autorización PostgreSQL.
- Las consultas paginadas no son un snapshot transaccional ante escrituras concurrentes. No hay push ni actualización automática; el usuario puede recargar. Los recursos no tienen reservas exclusivas.

## Datos demostrativos restantes

Sin repositorio inyectado, las pantallas históricas conservan ejemplos etiquetados como demostración para los tests/diseño. No se usan como fallback ante errores de Supabase. /sos/confirmacion y /sos/seguimiento siguen siendo simulaciones explícitas y no forman parte del recorrido real, que ocurre dentro del detalle por UUID. /sos/mapa conserva su lienzo de demostración; la cartografía real pertenece a Fase 6. No se afirma que esos destinos reciban SOS, asignen un voluntario o calculen rutas reales.

La semilla 004_datos_demo_OPCIONAL.sql puede añadir grupos ficticios al servidor; la tabla no los marca como tales. Hay que revisar el contenido del entorno antes de presentarlo como directorio comunitario real. No se añadieron ni eliminaron datos remotos.

## Integración real preparada — pendiente

El test automatizado utiliza sesiones SupabaseClient de usuario independientes con clave publicable, no conexión administrativa. A y B son emisor/colaborador. Se requiere C de la misma zona para comprobar lectura privada antes de participar, ofertas independientes y dos aceptaciones concurrentes: dos usuarios no bastan para comprobar esas tres propiedades. Las cuentas deben estar previamente creadas con perfiles sintéticos de rol vecino y sin otros usuarios reales en la zona/proyecto.

El test verifica emisión normal sin GPS, UUID idempotente, detalle de B, oferta de B, lectura por A, ocultamiento para C, rechazo de cancelación/UPDATE ajeno y de aceptación por C, oferta de C, una sola aceptación concurrente, cancelación de la oferta no seleccionada sin afectar la otra, estado visible al seleccionado, en_camino, completada, atendida para todos y rechazo de nueva oferta sobre alerta cerrada. Cancela solo su alerta sintética si queda abierta al terminar; conserva registros terminales para revisión. Un corte de red durante el test puede impedir esa limpieza: revisar los registros sintéticos antes de repetir. No crea ni borra usuarios o zonas.

Preparación, sin ejecutar automáticamente:

1. Autorizar expresamente un proyecto aislado sin vecinos reales, integraciones de notificación externas ni alertas operativas. Revisar cuerpos/grants mediante VERIFICAR_INSTALACION.sql y catálogo PostgreSQL; confirmar 003 y resolver cerrar_alerta antes de usar el entorno como candidato de producción.
2. Provisionar A/B/C sintéticos con cuentas email/password de Supabase Auth y perfiles creados mediante el registro permitido. Son identidades de prueba del mismo contrato Auth/RLS; no representan recuperación por email de las cuentas anónimas de la app. Probar PIN mediante la aplicación separadamente. No usar datos personales reales.
3. Guardar SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, SOS_TEST_PROJECT_URL (igual a la URL aislada) y SOS_TEST_EMAIL_A/B/C, SOS_TEST_PASSWORD_A/B/C en `config/supabase.sos.local.json`, ya excluido por gitignore. Nunca imprimirlo ni versionarlo. No se creó ese archivo aquí.
4. Tras autorización, ejecutar en dispositivo elegido:

```powershell
flutter test integration_test/supabase_sos_test.dart -d <dispositivo> --dart-define-from-file=config/supabase.sos.local.json --dart-define=ALLOW_SOS_TEST_WRITES=true --dart-define=SOS_TEST_ENVIRONMENT=isolated-synthetic
```

Sin ALLOW_SOS_TEST_WRITES el test queda omitido. Con la bandera activa falla antes de escrituras si no coincide la URL explícita, falta la declaración de entorno o las credenciales/perfiles no cumplen los requisitos. Esas barreras evitan ejecuciones accidentales, no acreditan autorización por sí mismas. **No se ejecutó este test, ni con la bandera ni sin ella; analizarlo no equivale a ejecutarlo.**

Procedimiento manual adicional: en dos dispositivos A/B registrar perfiles sintéticos mediante el flujo existente y desbloquear PIN; A emite desde zona y copia UUID; B recarga, ofrece; A abre Mis alertas, acepta; B recarga y pasa a en_camino; A/B completan según sus permisos y comparan estado con SELECT desde sus respectivas sesiones. Repetir desconectando red después de cada envío y usar reconsulta antes de repetir. Con C sin participación, intentar leer respuestas de A/B: vacío o rechazo; después ofrecer C, cancelar C y comprobar B intacta. Con D de otra zona comprobar que SELECT de alerta/recurso/grupo ajeno no devuelve filas. No consultar esas pruebas como administrador.

Para la vulnerabilidad de cerrar_alerta, solo en un escenario aislado expresamente aprobado, usar una cuarta sesión authenticated sin perfil y un UUID de alerta sintética. Después de la corrección SQL revisada, debe rechazar cerrar_alerta y dejar intactos alerta, confianza y respuestas. No ejecutar este ensayo sobre alertas reales. Las carreras y rechazos se registrarán como evidencia remota independiente de las pruebas con mocks.

## Android y regresiones

```powershell
flutter pub get
flutter devices
flutter run -d <dispositivo-android> --dart-define-from-file=config/supabase.dev.json
```

Configurar únicamente URL/clave publicable; el archivo ya está ignorado. La app comparte el cliente de autenticación existente. El manifiesto Android ya tiene INTERNET; no se añadieron permisos de GPS ni seguimiento. Restaurar sesión requiere PIN. Sin configuración válida, las guardas impiden operar SOS. No emitir en un proyecto compartido sin autorización: usar el entorno aislado para los pasos de escritura.

Revisión manual pendiente: 320/412 px, texto 150–200 %, teclado visible, lectores de pantalla, Atrás Android, pausa/restauración y recuperación de conexión. El widget compuesto acredita navegación y desbloqueo con fakes; no sustituye la ejecución en dispositivo. Las suites anteriores de auth, servicios, navegación y SOS se mantienen.

## Archivos de esta ejecución y coordinación

Modificados exclusivamente en 5.6:

- lib/features/emergency/presentation/controllers/alert_emission_controller.dart.
- lib/features/emergency/presentation/screens/emergency_actions_screen.dart.

Nuevos en 5.6:

- test/sos_closure_test.dart.
- integration_test/supabase_sos_test.dart.
- docs/FASE_5_6_CIERRE_SOS.md.

El árbol inicial ya incluía cambios en main.dart, emergency_dashboard_screen.dart, emergency_actions_screen.dart y brigades_screen.dart, documentos 5.1–5.5, repositorio/modelos/controladores SOS, pantallas sos_alert_views/sos_help_board/sos_catalog_screen y tests sos_data/sos_alerts_ui/sos_help/sos_catalog. Todos se preservan. Los archivos nuevos siguen sin seguimiento; git diff por sí solo no los incluye. Las modificaciones de composición en main.dart son el punto compartido con servicios. Router, guardas, auth, dependencias y SQL permanecen sin cambios en esta ejecución.

Antes de integrar con compañeros, revisar la rama real y separar el conjunto SOS de cualquier cambio de servicios en su PR; no depender de commits en otras ramas. No se comparó main remoto ni se cambió de rama para hacerlo. Las regresiones verifican las funcionalidades disponibles en este checkout.

## Resultados finales y recomendación

| Comprobación | Resultado |
|---|---|
| Formateo exclusivo de los cuatro Dart de 5.6 | Correcto |
| flutter pub get | Correcto; sin nuevas dependencias ni cambios de lockfile. Aviso de siete versiones más recientes incompatibles con las restricciones actuales |
| flutter analyze, resultado final | Sin incidencias |
| flutter test test/sos_closure_test.dart --concurrency=1 | 2 aprobadas, 0 fallidas |
| flutter test --concurrency=1 | 182 aprobadas, 0 fallidas, sin omisiones locales; 2 min 19 s |
| git diff --check | Correcto |
| git status | Árbol con cambios previos y cinco archivos nuevos/ampliados de 5.6; sin staging ni commit |
| Tests remotos | 3 archivos no ejecutados: supabase_auth_test, supabase_services_test, supabase_sos_test |
| Android físico/emulador | No ejecutado |

El primer análisis detectó una incidencia de estilo en el test remoto nuevo (llaves en un if). Se corrigió y el análisis final quedó limpio. No hubo pruebas locales fallidas ni regresiones pendientes. También se revisaron los archivos nuevos fuera del índice para espacios finales y marcadores de conflicto. No se verificó RLS remota mediante mocks ni se emitieron SOS reales.

El código queda preparado para revisión. **No recomiendo merge con main ni despliegue** mientras cerrar_alerta mantenga el defecto crítico y no exista evidencia del despliegue 003 y de los recorridos reales A/B/C. Un commit/push y PR de borrador para revisión podrían hacerse después de la autorización del usuario y de acordar con el equipo el alcance de rama; no representarían aceptación de producción. No se ejecutó ninguna de esas operaciones y este documento no las autoriza. No se avanza a Fase 6.
