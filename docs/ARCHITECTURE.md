# Arquitectura

`features/auth/presentation/screens/` contiene las tres interfaces de demostración. Comparten el encabezado, el teclado, los indicadores y el campo de formulario. Los validadores puros viven en `auth/utils/`. El formulario conserva sus controladores mientras la ruta sigue abierta. Crear PIN compara dos entradas locales y las descarta al terminar o salir. Login conserva únicamente un contador. Las pruebas de interfaz recorren ambos flujos desde el Dashboard.

VeciPulso organiza el código por funcionalidad con MVVM ligero. `main.dart` inicia la aplicación. `app/` compone el tema, las rutas y el Scaffold de las cinco pestañas. El catálogo AppRoute concentra títulos y patrones de ruta. El shell mantiene los navegadores mediante StatefulShellRoute.indexedStack.

`core/theme/` define paleta, tipografía del sistema, espaciado, radios y tema Material 3. `core/constants/` contiene AppAssets. Configuración transversal, servicios de plataforma y utilidades tienen sus directorios reservados en core.

`shared/widgets/` contiene navegación, botones, tarjetas, encabezados, imágenes y la pantalla pendiente. Las vistas de negocio se ubican en `features/<feature>/presentation/screens/`. Al introducir estado de negocio, cada feature podrá añadir widgets propios y viewmodels observables con provider. Los modelos irán en models/ y el acceso a datos en data/repositories/. La pantalla temporal de Inicio solo necesita estado de navegación.
