# Arquitectura

`features/publications` comparte `PostType` con el muro. Las cuatro plantillas precargan un `PublicationDraft` editable. Cada router tiene su propio `PublicationDraftController` en memoria. Confirmar recorta los campos y reemplaza el borrador por una copia para la vista previa. Al salir se libera ese estado. `test/publications_test.dart` verifica el recorrido y las validaciones locales.

El módulo `features/solidarity/` conserva seis publicaciones constantes en `data/demo_solidarity_posts.dart`. Cada `SolidarityPost` declara su ID, vecino, tipo, categoría, modalidad y vistas de destino. La selección local devuelve referencias a los mismos objetos. El muro y Economía solidaria utilizan `SolidarityWallScreen` y `SolidarityPostCard`. La tarjeta usa el formateador público de proveedores. El filtro pertenece al estado del muro dentro del shell. Las pruebas en `test/solidarity_test.dart` recorren filtros, navegación, avisos y tamaños de pantalla.

El catálogo inmutable de `features/services/data/demo_services.dart` alimenta el directorio y la selección del Dashboard. Cada `ServicePreview` reúne el servicio y el proveedor bajo un ID estable. Su método `matches` combina texto normalizado, distancia y valoración. El directorio conserva sus controles en memoria mientras se visita un perfil. Los trabajos, las reseñas y los distintivos pertenecen a cada registro de demostración.

`features/auth/presentation/screens/` contiene las tres interfaces de demostración. Comparten el encabezado, el teclado, los indicadores y el campo de formulario. Los validadores puros viven en `auth/utils/`. El formulario conserva sus controladores mientras la ruta sigue abierta. Crear PIN compara dos entradas locales y las descarta al terminar o salir. Login conserva únicamente un contador. Las pruebas de interfaz recorren ambos flujos desde el Dashboard.

VeciPulso organiza el código por funcionalidad con MVVM ligero. `main.dart` inicia la aplicación. `app/` compone el tema, las rutas y el Scaffold de las cinco pestañas. El catálogo AppRoute concentra títulos y patrones de ruta. El shell mantiene los navegadores mediante StatefulShellRoute.indexedStack.

`core/theme/` define paleta, tipografía del sistema, espaciado, radios y tema Material 3. `core/constants/` contiene AppAssets. Configuración transversal, servicios de plataforma y utilidades tienen sus directorios reservados en core.

`shared/widgets/` contiene navegación, botones, tarjetas, encabezados, imágenes y la pantalla pendiente. Las vistas de negocio se ubican en `features/<feature>/presentation/screens/`. Al introducir estado de negocio, cada feature podrá añadir widgets propios y viewmodels observables con provider. Los modelos irán en models/ y el acceso a datos en data/repositories/. La pantalla temporal de Inicio solo necesita estado de navegación.

El módulo features/maps separa el modelo de marcador, el catálogo local y la presentación. NeighborhoodMapCanvas dibuja las calles y parques a escala y coloca controles sobre posiciones relativas. La pantalla conserva en memoria las categorías activas y la consulta normalizada. Los comercios toman su ID, título y descripción de ServicePreview.
