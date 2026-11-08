# Fase 5.3 — Emisión y consulta de alertas comunitarias

El tablero /sos/tablero utiliza LiveSosDashboard cuando dispone de SosRepository en Provider. El arranque construye SupabaseSosRepository con el mismo cliente ya inicializado para la sesión. El centro /sos/acciones ofrece el formulario de alerta o soporte crítico. Los tests y accesos demostrativos sin repositorio siguen usando los escenarios explícitos de demostración. El recorrido productivo configurado emplea el repositorio real.

## Archivos de la fase

- lib/main.dart añade la composición Provider de SosRepository con el cliente existente.
- lib/features/emergency/data/sos_repository.dart expone userId para visibilidad de acciones del emisor. Las operaciones de escritura siguen verificadas por Supabase.
- lib/features/emergency/presentation/controllers/alert_emission_controller.dart gestiona envío, UUID estable, error y reconciliación del resultado incierto.
- lib/features/emergency/presentation/screens/sos_alert_views.dart contiene listado, diálogo de detalle y formulario que usan los repositorios/controladores.
- emergency_dashboard_screen.dart y emergency_actions_screen.dart, en el mismo directorio, conectan los accesos actuales con esas vistas.
- test/sos_alerts_ui_test.dart añade ocho pruebas locales de formulario, lectura y resultado incierto.

Se mantienen los documentos y código sin confirmar de 5.1/5.2 encontrados al comenzar. La rama activa encontrada fue feat/servicios-visto-bueno y se conservó. No se avanzó a la integración de ofrecimientos, recursos ni brigadas.

## Formulario y ubicación

La clase se elige entre alerta y soporte. El selector de emergencia contiene únicamente los tipos compatibles con la clase según el CHECK de alertas_sos. Cambiar clase borra el tipo anterior. La urgencia admite critica, urgente y normal. La descripción es opcional según SQL y se recortan espacios exteriores. El formulario exige tipo y confirmación mediante casilla antes de habilitar una emisión válida.

Se emplea exclusivamente la alternativa por zona del SQL 003. No se solicita permiso GPS ni se instala una dependencia geográfica. Se envían p_lat y p_lng nulos, de modo que el trigger completa el centro aproximado del barrio registrado. La denegación de GPS no bloquea esta alternativa porque no se solicita el permiso en este flujo. La ubicación nunca se sustituye por una coordenada fija de demostración.

emitir_alerta recibe p_id, p_clase, p_tipo, p_urgencia, p_descripcion, p_lat, p_lng y p_creado_local con los tipos efectivos documentados en 5.1. El UUID se genera una vez por formulario con Random.secure en formato v4 y se conserva en cada reintento. La RPC determina autor_id y zona_id a partir de la sesión/perfil.

## Confirmación, red y reintento

Durante el envío se bloquean los controles y el botón de registro, además de proteger la operación en el controlador. El texto Alerta registrada por el servidor solo aparece cuando la RPC devuelve un UUID confirmado. Describe persistencia en Supabase, sin afirmar recepción por otra persona o llegada de ayuda.

Si falla por red o servidor, el resultado se marca incierto. El siguiente toque consulta detail(id) antes de volver a emitir. Si el registro existe y pertenece a la sesión actual, se confirma el UUID sin repetir la escritura. Si la consulta devuelve missing, se permite el reintento explícito con el mismo UUID. Si la comprobación falla por red o autorización, se mantiene el error y no se realiza una nueva escritura. La RPC efectiva también reconoce el mismo UUID y autor.

Los campos se congelan tras el primer intento para conservar el contenido de la operación. Para cambiar datos después de un rechazo conocido, cerrar y abrir un formulario nuevo. El borrador y el UUID pertenecen a la memoria del formulario. Ante resultado incierto se muestra el UUID y se indica consultar Mis alertas si se cierra el formulario antes de iniciar otro envío. No existe cola offline ni reenvío automático.

## Listado, detalle y cancelación

Alertas de mi zona utiliza alerts() bajo RLS. Mis alertas añade el filtro autor_id de sesión. Ambas incluyen historial abierto y cerrado, ordenado por fecha e id, en páginas de 50 con Anterior/Siguiente y actualización explícita. Se muestran tipo, estado comunitario y fecha. Un listado vacío y los errores tienen mensajes específicos y acción Actualizar alertas.

El diálogo de detalle recibe el UUID, consulta la fila y muestra descripción opcional, urgencia, tipo, fecha y estado. La ubicación se identifica como aproximada de zona, sin presentar distancias calculadas desde el dispositivo. Los datos anteriores se limpian al cargar. Cada diálogo tiene su controlador y las generaciones del controlador descartan respuestas antiguas o posteriores a dispose.

El autor puede cancelar una alerta abierta tras una confirmación adicional. Se ejecuta cancelar_alerta(p_alerta), se relee la fila y al cerrar el detalle se actualiza el listado. La autorización definitiva pertenece al cuerpo SQL. El estado verificada se presenta como Confirmada por vecinos.

cerrar_alerta permanece fuera de la capa por el riesgo SQL documentado en 5.1. Tampoco se incorporan transiciones de ayuda. Las guardas de sesión y PIN de GoRouter se conservan. Los errores de dominio se presentan sin mensajes internos SQL, claves o datos personales.

## Pruebas y pendientes

Las ocho pruebas nuevas usan un repositorio inyectado para comprobar tipo y confirmación requeridos, rechazo de tipo incompatible al cambiar clase, alternativa de zona sin coordenadas, doble envío, confirmación posterior a respuesta, envío incierto persistido y ausente, reconsulta denegada, lista vacía, red, reintento, selección por UUID, cancelación propia y detalle missing/denied. Los tests de la capa 5.2 y de autenticación conservan la cobertura de argumentos de RPC, coordenadas válidas, respuestas fuera de orden y PIN.

La integración remota de emisión y consulta SOS y la revisión manual Android quedan pendientes de un escenario sintético expresamente autorizado. No se emitieron alertas contra Supabase compartido.

Para la revisión Android, iniciar con config/supabase.dev.json, desbloquear el PIN y abrir Modo SOS. Confirmar listado y Mis alertas, probar formulario incompleto, cancelar antes del envío y revisar detalle. En un entorno autorizado, emitir una alerta sintética por zona, comprobar su UUID con otra sesión de la zona, recuperar el listado tras desconectar la red y cancelar como autor. Verificar que un tercero no pueda cancelar la alerta y que otro barrio no reciba la fila.

## Resultados de validación local

flutter analyze terminó sin incidencias. La suite completa flutter test --concurrency=1 aprobó 165 pruebas, incluidas las ocho nuevas de 5.3 y las suites de autenticación/PIN. La suite aislada de formulario/listado también aprobó sus ocho casos. Cero fallos pendientes. Se formatearon exclusivamente los siete archivos Dart de la fase. git diff --check terminó con exit 0.

Las dos integraciones remotas existentes de autenticación y servicios quedaron sin ejecutar. El recorrido remoto SOS y la prueba manual Android también quedan pendientes. No se modificaron SQL, RLS, dependencias, rutas ni pantallas de recursos o brigadas.
