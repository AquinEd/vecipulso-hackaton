# VeciPulso

«Servicios del Barrio» abre el directorio local de cinco profesionales. La búsqueda admite nombres, oficios y descripciones sin tildes. Los límites de 500 m y 1 km se combinan con la valoración mínima de cuatro estrellas. Cada ficha muestra los trabajos y reseñas ilustrativos disponibles. Llamar y solicitar servicio muestran avisos informativos. Las pruebas de directorio y perfil se ejecutan con `flutter test`.

En «Pruebas de desarrollo», al pie de Inicio, puedes probar el registro con DNI autodeclarado y nombre, crear y confirmar un PIN de seis dígitos o explorar el ingreso con teclado aleatorio. La fase 3 funciona en memoria. Las cuentas y sesiones reales quedan pendientes de la integración con Supabase.

Aplicación de integración vecinal para descubrir servicios, intercambiar favores y coordinar ayuda. El Dashboard está implementado. El buscador filtra tres servicios locales de ejemplo por nombre o descripción. Las valoraciones, los distintivos y las distancias son ilustrativos. La ubicación sigue por configurar y la integración con el backend queda pendiente.

## Ejecutar en Windows

Requisitos verificados: Flutter estable 3.47.9, Dart 3.13.7 y, para Android, Android Studio con un dispositivo o emulador configurado. Desde la raíz del proyecto:

```powershell
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run
```

Para elegir un destino, sustituye el identificador con el que aparezca en la lista de dispositivos:

```powershell
flutter run -d ID_DEL_DISPOSITIVO
```

## Organización

El proyecto usa Material 3, go_router y una estructura por funcionalidad preparada para MVVM. El shell conserva cinco pestañas y permite abrir servicios, solidaridad y SOS. Solidaridad y SOS muestran pantallas de preparación. La ubicación está pendiente y no se solicitan permisos.

- [Arquitectura](docs/ARCHITECTURE.md)
- [Pantallas y rutas](docs/ROUTES.md)
- [Recursos originales](docs/ASSETS.md)
- [Funciones pendientes](docs/BACKLOG.md)
