# Arquitectura

VeciPulso organiza el código por funcionalidad con MVVM ligero. `main.dart` inicia la aplicación. `app/` compone el tema, las rutas y el Scaffold de las cinco pestañas. El catálogo AppRoute concentra títulos y patrones de ruta. El shell mantiene los navegadores mediante StatefulShellRoute.indexedStack.

`core/theme/` define paleta, tipografía del sistema, espaciado, radios y tema Material 3. `core/constants/` contiene AppAssets. Configuración transversal, servicios de plataforma y utilidades tienen sus directorios reservados en core.

`shared/widgets/` contiene navegación, botones, tarjetas, encabezados, imágenes y la pantalla pendiente. Las vistas de negocio se ubican en `features/<feature>/presentation/screens/`. Al introducir estado de negocio, cada feature podrá añadir widgets propios y viewmodels observables con provider. Los modelos irán en models/ y el acceso a datos en data/repositories/. La pantalla temporal de Inicio solo necesita estado de navegación.
