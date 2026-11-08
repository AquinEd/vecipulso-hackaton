# Fase 5.4 — Respuestas y gestión de ayuda SOS

La integración añade Ofrecimientos de ayuda dentro del detalle real de una alerta. La rama encontrada continúa siendo feat/servicios-visto-bueno. Se conserva el trabajo previo sin confirmar de 5.1–5.3 y no se cambia de rama.

## Archivos de esta fase

- lib/features/emergency/data/sos_repository.dart añade publicName(userId) mediante perfiles_publicos_de_mi_zona() filtrada por id. Mantiene offer, responses y updateHelp de 5.2.
- lib/features/emergency/presentation/controllers/help_board_controller.dart compone alerta, respuestas visibles y nombres públicos, calcula acciones de interfaz y gestiona actualización y reconciliación.
- lib/features/emergency/presentation/screens/sos_help_board.dart presenta el formulario, respuestas y confirmación de acciones.
- lib/features/emergency/presentation/screens/sos_alert_views.dart inserta el panel dentro del diálogo de detalle de alerta.
- test/sos_help_test.dart añade pruebas de ofrecimiento, aceptación en interfaz, transiciones, privacidad y concurrencia con repositorio simulado.
- test/sos_alerts_ui_test.dart amplía el fake anterior con lectura vacía de respuestas y nombre público, conservando sus pruebas de alerta.

Se reutilizan HelpResponse, SosAlert, HelpStatus, SosRepository y SosController. No se introducen rutas nuevas. El detalle sigue recibiendo el UUID de la alerta seleccionada. Los cambios del panel refrescan explícitamente tanto las respuestas como el detalle.

## Ofrecer ayuda

Un vecino autenticado distinto del autor ve Ofrecer ayuda en una alerta abierta, siempre que no exista ya una respuesta propia no cancelada visible en la consulta. El formulario admite mensaje opcional y requiere confirmar el ofrecimiento. El SQL no exige descripción ni coordenadas para sos_respuestas. Esta fase envía recurso_id y ubicación nulos.

El INSERT ejecutado por el repositorio fija voluntario_id desde la sesión. La política sos_resp_crear exige UID actual, estado ofrecida, alerta abierta de otro vecino en mi zona y, si se aporta recurso, propiedad de ese recurso. En el formulario se conserva el UUID de operación y el controlador inhibe doble envío.

Antes de cada intento se consultan respuestas autorizadas. Si ya existe el mismo UUID de ese voluntario se devuelve la fila confirmada. Si una escritura produjo un resultado incierto, Reintentar comprueba primero esa fila. Si falla la consulta no se vuelve a insertar. Los errores quedan visibles y el texto de éxito aparece después de una fila confirmada. Al cerrar un formulario con resultado incierto, actualizar los ofrecimientos antes de crear otra operación.

## Respuestas y privacidad

responses(alertaId) consulta sos_respuestas por alerta_id, sujeta a RLS. El autor ve sus ofrecimientos recibidos, el voluntario ve los propios y un admin puede leer según política. El panel no amplía la autorización del backend. Una lista vacía significa que no hay filas visibles para esa cuenta. Se muestran nombre público, mensaje de la ayuda, estado y fecha.

publicName invoca perfiles_publicos_de_mi_zona() y devuelve únicamente nombre_publico a la presentación. Si no existe perfil público se usa Vecino de la comunidad. No se consulta perfiles privados, no se llama contraparte_ayuda para obtener teléfonos y no se renderizan contactos ni posiciones de voluntarios. Los datos se limpian durante cargas y errores. El controlador comprueba que la sesión observada al iniciar la lectura siga siendo la misma al finalizar.

## Estados y autoridad

| Actor | Desde | Acciones presentadas |
|---|---|---|
| Emisor | ofrecida | Aceptar si no hay otra aceptada/en_camino, o cancelar |
| Emisor | aceptada/en_camino | Completar o cancelar |
| Voluntario | ofrecida | Cancelar |
| Voluntario | aceptada | En camino, completar o cancelar |
| Voluntario | en_camino | Completar o cancelar |
| Tercero o estado terminal | Cualquiera | Lectura autorizada solamente |

Cada acción tiene confirmación explícita. Antes de actualizar se releen alerta y respuestas, se comprueba que el UUID pertenezca a la alerta y que la acción siga disponible. La operación efectiva utiliza actualizar_ayuda(p_resp uuid,p_estado estado_ayuda), retorna void y el repositorio relee la respuesta. Después el panel relee las respuestas y la alerta. Las comprobaciones visuales nunca sustituyen a RLS o la RPC.

Un cambio de estado que falla por red/servidor queda sin confirmar. Actualizar respuestas consulta el estado persistido y permite decidir desde ese estado. No se repite la transición automáticamente. Completar puede cerrar la alerta como atendida, con lo que desaparecen las acciones de estados abiertos.

## SQL efectivo, cancelación y concurrencia

La definición efectiva está en docs/database/003_correcciones_mvp.sql:31–97 y en el bloque correspondiente de INSTALACION_UNICA_VECIPULSO_MVP.sql. Se aplica después de 001 y 002.

La RPC final bloquea primero la alerta y después la respuesta. Comprueba sesión, estado obligatorio, alerta abierta, participante y transición. uq_ayuda_sos_seleccionada_mvp impide más de una respuesta aceptada/en_camino por alerta. Dos aceptaciones concurrentes se serializan y una se rechaza. uq_sos_resp_activa de 002 impide dos ofertas no canceladas del mismo voluntario y alerta, permitiendo ofrecer nuevamente después de cancelar.

La condición final que afecta otras ofertas es exclusivamente p_estado='completada'. Cancelar una oferta individual actualiza solo esa respuesta. Completar cancela otras ofertas activas y marca atendida la alerta de forma transaccional. La versión original 001 cancelaba las demás ofertas también al cancelar una respuesta. Esa versión está reemplazada en los scripts efectivos.

No se detectó ese defecto de cancelación en 003 y no se propone una migración redundante. La seguridad de concurrencia se verificó mediante inspección del contrato versionado. Es indispensable confirmar que 003 esté instalado antes de usar transiciones reales. Si el despliegue conserva el cuerpo 001, la cancelación individual debe considerarse bloqueada hasta revisar y aplicar una corrección SQL autorizada.

Si otra operación cierra la alerta antes de obtener el bloqueo, actualizar_ayuda rechaza La alerta ya fue cerrada. Las carreras de cierre, aceptación y cancelación deben verificarse con sesiones reales y transacciones concurrentes en un entorno autorizado. Los tests locales no acreditan el comportamiento del servidor desplegado.

El hallazgo previo de cerrar_alerta() con NULL de mi_rol() continúa pendiente de revisión autorizada. Esta fase no incorpora esa RPC. Se usan únicamente actualizar_ayuda y las lecturas/creación de respuestas previstas.

## Pruebas locales y revisión real pendiente

Las pruebas simulan un backend con RLS y transiciones para comprobar los estados de interfaz y los fallos. Incluyen ofrecimiento confirmado, bloqueo de doble pulsación, aceptación del emisor desde el detalle, oferta en alerta cerrada o sin permiso, lista vacía, nombres públicos sin contactos, lectura y cancelación individual que preserva otra respuesta, dos aceptaciones concurrentes con una seleccionada, reconciliación del UUID tras respuesta perdida y refresco posterior a actualización incierta. Se conserva la suite anterior de alertas, autenticación y PIN.

La prueba remota A/B/C queda sin ejecutar. En un entorno autorizado, A emite una alerta sintética, B y C ofrecen, A acepta B, C cancela su oferta y se verifica que B siga aceptada. Repetir aceptación simultánea desde dos sesiones del emisor, cancelación concurrente de otra oferta y cierre durante actualización. B puede pasar a en_camino y completar, y A debe ver atendida. Un vecino D de otra zona y un tercero no participante deben recibir exclusivamente las filas autorizadas. Probar desconexión posterior a UPDATE y reconsulta. No usar una conexión administrativa como prueba de RLS.

La lectura de respuestas recorre páginas ordenadas por creado_en e id hasta recibir una página vacía. El desplazamiento avanza según la cantidad recibida para respetar límites del servidor inferiores al tamaño solicitado. Si falla una página, se descarta la lectura completa y se muestra el error. Las consultas paginadas no constituyen un snapshot transaccional si otros usuarios escriben simultáneamente. No hay notificación push ni suscripción automática al estado remoto; Actualizar respuestas relee el servidor.


## Resultados finales

flutter analyze terminó sin incidencias. flutter test --concurrency=1 aprobó las 174 pruebas locales en 2 min 34 s, con cero fallos pendientes. La suite específica de ayuda aprobó sus ocho pruebas también después del último ajuste de comprobación de sesión. Las pruebas anteriores de autenticación, PIN y alertas siguen aprobadas. Se formatearon exclusivamente los archivos Dart modificados de esta subfase. git diff --check terminó con exit 0 y se verificaron los nuevos archivos fuera del índice.

No se ejecutaron escrituras ni pruebas remotas de SOS, ni las integraciones existentes de auth/servicios. Tampoco se realizó revisión manual Android. La implementación de 5.4 está disponible en Flutter y la garantía del servidor se basa en el contrato versionado, pendiente de validación del despliegue.


## Correcciones de cierre del código

Se completó la lectura paginada de todas las respuestas autorizadas para que una selección aceptada no quede fuera del conjunto utilizado por la interfaz. Se deshabilitan visiblemente las acciones mientras hay confirmación o actualización pendiente. Una sesión ausente se rechaza antes de leer el panel y los resultados privados en curso se descartan si cambia el usuario.

Las pruebas añadidas en el cierre comprueban las páginas y sus desplazamientos reales en el transporte HTTP simulado, el error en una página posterior sin devolución parcial y el cambio de sesión durante la lectura del nombre público. Se conserva la revisión remota como pendiente.

Validación del cierre adicional: 174 casos aprobados, cero fallidos, flutter analyze sin incidencias y git diff --check aprobado. Las pruebas remotas siguen pendientes de autorización.
