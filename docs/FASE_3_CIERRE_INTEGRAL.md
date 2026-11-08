# Cierre de implementación de la Fase 3

| Subfase | Entrega disponible |
|---|---|
| 3.1 | Inventario de pantallas, contrato SQL, RLS y roadmap. |
| 3.2 | Modelos de filas y RPC, repositorios con cliente inyectado y controladores Provider. |
| 3.3 | Directorio de servicios activos de la zona, búsqueda por título, oficios reales y paginación. |
| 3.4 | Ficha real por UUID, proyección pública, trabajos, contacto autorizado, reseñas paginadas y sello SQL. Se verificaron las siete pruebas específicas al iniciar el cierre. |
| 3.5 | Solicitud desde ficha, bandejas de cliente y proveedor, confirmación de estados y recomendación desde experiencia completada. |
| 3.6 | Oferta desde el directorio, Mis servicios, edición, desactivación, consentimiento de contacto y trabajos de texto. |

## Recorridos Android

Desde la raíz, usar un dispositivo conectado visible en `flutter devices`. Ejecutar `flutter pub get` y `flutter run -d <dispositivo> --dart-define-from-file=config/supabase.dev.json` con la configuración local del proyecto autorizado. Iniciar sesión con el flujo existente.

1. A abre Inicio → Servicios del Barrio → Ofrecer un servicio. Guarda título y categoría y comprueba la fila en Mis servicios. Puede editarla y gestionar el consentimiento telefónico.
2. B, en la misma zona, abre el directorio, busca el servicio y comprueba la ficha. Envía una solicitud con mensaje opcional y revisa Enviadas.
3. A abre Mis solicitudes → Recibidas y completa la solicitud. B actualiza Enviadas, elige Recomendar, selecciona estrellas y confirma. Al volver a la ficha obtiene reseñas, media y conteo actualizados.
4. Otro vecino de la zona puede consultar la ficha. Probar que un número no autorizado se mantiene oculto y que un usuario de otra zona no obtiene la fila. Una sola reseña no alcanza el umbral del sello.

## Contrato y privacidad

Los INSERT de servicios, solicitudes_servicio y recomendaciones usan el UID autenticado. El cliente no elige un ID de propietario como prueba de permiso. Edición y desactivación se limitan a campos permitidos por SQL. La transición usa actualizar_solicitud_servicio, que bloquea la fila y verifica actor y estado. Las bandejas se basan en mis_solicitudes_enviadas y mis_solicitudes_recibidas. Los nombres ajenos proceden de proyecciones públicas. Las políticas de zona y de servicio_contacto se mantienen intactas. El PIN desbloquea la UI y la sesión Supabase identifica al actor. El esquema v5 cubre ambos recorridos sin migración.

## Evidencia y aceptación

- [x] Directorio, ficha, búsqueda, filtros por oficio y estados de lectura.
- [x] Formularios conectados a escrituras del repositorio con confirmación del servidor y guardas de concurrencia.
- [x] Bandejas separadas y transiciones para cada actor verificadas con repositorios simulados.
- [x] Lectura de elegibilidad del servidor, recomendaciones 1–5 y refresco posterior.
- [x] Publicación por zona, edición propia y desactivación.
- [ ] E2E contra Supabase con dos sesiones reales y verificación manual en Android. Resultado pendiente.
- [ ] Comprobación entre zonas en el despliegue con un perfil de otra zona. El caso automatizado A/B usa la misma zona.

### Prueba remota preparada

`integration_test/supabase_services_test.dart` crea dos sesiones anónimas independientes con registros sintéticos, publica un servicio, comprueba la visibilidad de bandejas, intenta modificar el servicio ajeno, intenta completar como cliente, prueba una recomendación prematura, completa como proveedor, registra la recomendación y verifica duplicación, conteo y media para ambos. Usa claves públicas y deja los datos sintéticos en el entorno elegido. Requiere Anonymous Sign-ins, una zona y un catálogo de categorías.

Para un proyecto de pruebas expresamente autorizado, crear un archivo local de configuración con URL y clave pública de ese proyecto. Ejecutar `flutter test integration_test/supabase_services_test.dart -d <dispositivo> --dart-define-from-file=<config-local-de-pruebas> --dart-define=ALLOW_SERVICES_TEST_WRITES=true`. La prueba se omite sin esa bandera. Las pruebas unitarias y de widgets utilizan HTTP o repositorios simulados. La integración previa de auth también escribe datos y queda fuera de la suite local.

### Alcance de los archivos

Se modificaron services_repository.dart, provider_detail_screen.dart, services_screen.dart, test/support/directory_fixture.dart y test/services_data_layer_test.dart. Se añadieron los widgets service_operations.dart y service_editor.dart, test/service_lifecycle_test.dart, la integración de dos cuentas y los tres documentos del cierre. Las rutas actuales abren formularios y bandejas mediante diálogos. Inicio y Mapa siguen identificando sus ejemplos históricos.

La búsqueda métrica sigue dependiendo de disponer de un origen autorizado. Las estadísticas paginadas pueden cambiar si otro usuario escribe entre lecturas. No existe snapshot de varias consultas ni notificación push de cambios de estado. Actualizar relee el servidor. Para fusionar a main se recomienda comprobar primero el E2E A/B y la privacidad en el entorno de pruebas.


## Resultados de ejecución

La suite local completa aprobó 146 pruebas en 2 min 33 s, con cero fallos. Incluye autenticación y PIN, directorio, ficha, publicación y el recorrido hasta recomendar. Las pruebas nuevas ejercitan el bloqueo durante la escritura, comentario limitado a 300 grafemas, categoría obligatoria o eliminada, rechazo de edición ajena, solicitud duplicada o inexistente, restricciones de puntaje y autorización, reintento y recuperación de las estadísticas. Se repitieron los tres tests de interfaz de ciclo de servicio tras el ajuste final del editor. flutter pub get y git diff --check finalizaron correctamente. flutter analyze terminó sin incidencias.

Se dejaron sin ejecutar dos pruebas automatizadas remotas: la integración existente de auth y el nuevo E2E de servicios. También queda pendiente la comprobación manual en Android con usuarios de distintas zonas. El resultado de Supabase real para estos flujos es pendiente.
