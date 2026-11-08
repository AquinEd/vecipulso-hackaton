# Fase 3.3 — Directorio de servicios por zona

Al abrir **Servicios del Barrio** desde Inicio o desde el menú, `/servicios` carga el catálogo de oficios y los servicios activos visibles para la sesión. Cada tarjeta muestra título, categoría y número de recomendaciones visibles. Con cero recomendaciones muestra «Sin valoraciones». El toque abre `/servicios/:id` con el UUID de la fila. La ficha mínima vuelve a consultar el servicio y muestra título y descripción. Esto permite abrir un enlace directo o detectar que la fila dejó de estar disponible entre el listado y el toque.

## Implementación

| Archivo | Cambio |
|---|---|
| `lib/main.dart` | Provee ServicesRepository con el mismo cliente inicializado para la sesión de la aplicación. |
| `lib/features/services/data/services_repository.dart` | Añade page con filtros y paginación a las lecturas de la fase 3.2. |
| `lib/features/services/models/service_rows.dart` | DirectoryEntry combina ServiceRow y el conteo de la relación recomendaciones. |
| `lib/features/services/presentation/controllers/services_controllers.dart` | DirectoryController gestiona catálogo, búsqueda, categoría, página, recarga y resultados vigentes. |
| `lib/features/services/presentation/screens/services_screen.dart` | Sustituye demoServices, distancias fijas, estrellas e insignias por el controlador y tarjetas AppCard con datos del servidor. |
| `lib/features/services/presentation/screens/provider_detail_screen.dart` | Para UUID reales usa la consulta de detalle. Las entradas demo de Inicio y Mapa conservan su identificación de ejemplo. |
| `test/services_data_layer_test.dart` | Verifica método HTTP, filtros PostgREST, límites y proyección con transporte simulado. |
| `test/services_test.dart`, `test/support/directory_fixture.dart` | Ejercitan el directorio mediante un repositorio inyectado. |
| `test/app_mode_navigation_test.dart`, `test/reviews_test.dart` | Comprueban el regreso desde el detalle del directorio real y la vista previa de reseñas desde el acceso demo de Inicio, respectivamente. |

## Consultas y filtros

1. ServicesRepository.categories lee id, nombre e icono de categorias_servicio ordenados por nombre. «Todos» quita el filtro de categoría.
2. ServicesRepository.page consulta servicios con activo=true y selecciona la proyección ServiceRow junto con recomendaciones(count). El servidor aplica RLS tanto al servicio como al conteo relacionado. La política servicios_lectura limita las filas a mi_zona(). Los nombres de oficio se cruzan por categoria_id con el catálogo.
3. El selector envía igualdad por categoria_id. El buscador limpia espacios y envía texto plano a textSearch sobre titulo con configuración spanish. Combina ambas condiciones en el servidor. La búsqueda admite palabras del título y los oficios se eligen del catálogo. El nombre del vecino queda fuera de estos filtros.
4. El directorio solicita 26 filas por rango y presenta hasta 25. La fila adicional determina si hay página siguiente. El orden por titulo e id evita empates ambiguos. Al cambiar filtros se vuelve a la primera página. El debounce de 250 ms evita consultar por cada pulsación consecutiva y el controlador descarta respuestas antiguas.
5. La ficha solicita la proyección de servicios por id, bajo las mismas políticas de lectura. Un error se presenta con los mensajes de ServicesFailure. Una lista vacía permite limpiar filtros y los fallos de conexión o autorización ofrecen reintento. Actualizar vuelve a leer el catálogo y la página.

La firma de buscar_servicios_cercanos exige latitud y longitud. El proyecto carece de una fuente de coordenadas autorizadas para este recorrido. Por eso se consulta la zona registrada mediante RLS y se omiten distancia, radio, promedio y filtro de cuatro estrellas. Los conteos sí están disponibles en esta consulta. Las lecturas del directorio y de la ficha mínima excluyen teléfono, perfil privado, mensajes y coordenadas exactas. Los identificadores los proporciona el servidor y se utiliza la clave pública con la sesión vigente.

## Verificación y continuidad

Las pruebas locales cubren carga, catálogo, búsqueda, limpieza, categoría vacía, cambio rápido con respuesta tardía, error de red y denegación, reintento, tarjeta sin valoraciones, navegación por UUID, conservación del filtro al volver, teclado y texto ampliado. La prueba HTTP inspecciona la proyección y la ausencia de campos telefónicos. Se conserva la suite de autenticación.

**Lecturas reales con una sesión de prueba existente: no ejecutadas.** La validación usa repositorio inyectado y transporte HTTP simulado. Queda por comprobar en el despliegue la búsqueda textual de PostgREST, el formato del conteo relacionado y el aislamiento efectivo entre zonas con usuarios de prueba.

En 3.4 se puede ampliar la ficha mínima con la proyección pública del proveedor, portafolio y reseñas mediante los repositorios existentes. La autorización de contacto sigue correspondiendo a servicio_contacto. Inicio y Mapa mantienen sus datos ilustrativos.

La ejecución final de flutter test --concurrency=1 pasó las 131 pruebas en 2 min 15 s, con cero fallos. flutter analyze terminó sin incidencias. Se ejecutaron flutter pub get, el formateo de los 11 archivos Dart de la fase y git diff --check.
