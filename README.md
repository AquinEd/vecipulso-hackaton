# VeciPulso

Desde el menú lateral, abre **Tutorial de uso** para recorrer Servicios del Barrio, Cadena de Favores y Modo SOS. En **Accesibilidad** puedes activar texto grande, alto contraste, botones grandes e instrucciones claras durante la sesión. «Pedir ayuda» muestra un aviso de vista previa. «Restablecer ajustes» desactiva las cuatro opciones y conserva el modo actual.

La fase 11 incorpora la vista previa local de ayuda comunitaria. Desde el Tablero SOS, pulsa «Solicitar ayuda», elige una necesidad, abre el resumen y pulsa «Ver confirmación visual (demo)». El perfil es ficticio y los controles de contacto muestran avisos informativos.

La fase 10 implementa Grupos de Apoyo y Brigadas en `/sos/brigadas`, siguiendo la referencia 09 con widgets Flutter y estilo claro. El Tablero SOS ofrece «Grupos y Brigadas». La pantalla conserva el controlador SOS y la única barra inferior de cinco pestañas; Atrás de interfaz o Android vuelve al tablero, también desde una entrada directa. La app sigue iniciando en `/inicio`.

Los cuatro grupos ficticios son Brigada Los Álamos (cuadras 1–5, 12 integrantes), Grupo El Progreso (6–10, 8), Equipo Salud Vecinal (11–15, 6) y Movilidad Solidaria (16–20, 11). Todos, Brigadas y Voluntarios son filtros excluyentes combinados con búsqueda local por nombre, categoría, sector y cada cuadra del intervalo, ignorando mayúsculas y tildes. El estado vacío permite restablecer búsqueda y filtros. «Contacto directo» abre un diálogo con el nombre del grupo, «Contacto no disponible todavía» y «Entendido». La pantalla indica «Grupos de demostración · Contactos no disponibles»; no realiza comunicaciones ni registros.

Pendientes: Supabase, brigadas reales, identificación de miembros, contactos verificados, chat y llamadas, registro de voluntarios, coordinación de ayuda, notificaciones, GPS y sincronización offline. El mapa definitivo de la pantalla 23 sigue pendiente.


Validación de fase 10 (7 de noviembre de 2026): `dart format lib test` aplicado, `flutter pub get` completado sin cambios de versión, `flutter analyze` sin incidencias y `flutter test` con 63 pruebas aprobadas (55 anteriores y 8 nuevas). Las nuevas pruebas cubren filtros, búsqueda, sectores, contacto y navegación, además de 320/412 px, texto al 150 %, teclado y 50 grupos. `flutter devices` confirmó `emulator-5554`; `flutter run -d emulator-5554 --no-resident` compiló, instaló e inició la app en Pixel 6, Android 17/API 37. Se inspeccionaron pantalla, filtro Voluntarios y diálogo de Movilidad Solidaria, con una sola barra inferior y sin desbordamientos visibles.

La fase 9 implementa el Centro de Ayuda Vecinal en `/sos/acciones`, siguiendo la referencia 18 con widgets Flutter: encabezado rojo, tres tarjetas, selectores y resúmenes locales. Todo el recorrido muestra «DEMOSTRACIÓN — Ninguna acción se enviará» y usa «Ubicación de ejemplo: Barrio Los Álamos».

- Emitir alerta vecinal: Sismo, Incendio, Seguridad y Salud.
- Solicitar soporte crítico: Persona atrapada, Ayuda médica, Agua o alimentos y Transporte o refugio.
- Ofrecer ayuda o recursos: Agua, Botiquín, Herramientas, Transporte y Espacio seguro o refugio.

Seleccionar abre un único panel. El resumen requiere una categoría; permite cambiarla y cerrar la demostración. Cancelar, deslizar el panel, Atrás o cerrar descarta la selección. Los estados son «No enviada» o «No registrado». No hay conexiones, persistencia ni cambios en los reportes o el muro.

Desde el Tablero SOS, «Centro de ayuda vecinal» abre las tres acciones; Solicitar y Ofrecer ayuda abren sus selectores correspondientes. Atrás desde acciones siempre vuelve al tablero, incluso en una entrada directa. La vista enfocada oculta la barra inferior y conserva el controlador SOS existente; al regresar vuelve la única barra de cinco pestañas. Salir de SOS restaura Inicio y Mapa normales.


Validación de fase 9 (7 de noviembre de 2026): dart format lib test aplicado, flutter pub get completado sin cambios de versión, flutter analyze sin incidencias y 55 pruebas aprobadas. Incluye trece categorías y sus resúmenes a 412 y 320 px con texto al 150 %, cancelación, reapertura limpia, Atrás Android, restauración del modo y conservación del filtro del mapa. flutter devices confirmó emulator-5554; flutter run -d emulator-5554 --no-resident compiló, instaló e inició la versión final en Pixel 6 (Android 17, API 37). Se inspeccionaron visualmente el centro, el selector de alertas y el recorrido Solicitar ayuda → Ayuda médica → resumen No enviada → cerrar, sin desbordamientos visibles. No se enviaron ni registraron acciones reales.

La navegación principal del Drawer y las categorías del Dashboard reemplaza la sección actual; Atrás vuelve al Dashboard sin recorrer otras secciones. Los detalles y formularios conservan su regreso al origen inmediato. Inicio muestra el Dashboard y Mapa muestra los recursos comunitarios en modo normal. Activar Modo SOS cambia Inicio al tablero y Mapa al Mapa de Emergencia, manteniendo Publicar, Mensajes y Perfil disponibles. El modo permanece activo entre pestañas. «Salir del Modo SOS» o Atrás desde el tablero restaura el Dashboard; Atrás desde el mapa SOS vuelve al tablero. El mapa normal conserva sus filtros al entrar y salir de SOS.

Validación de la corrección (7 de noviembre de 2026): formato aplicado, dependencias resueltas sin cambios de versión, análisis sin incidencias y 44 pruebas aprobadas. En Pixel 6 (`emulator-5554`, Android 17) se compiló e instaló la app y se verificó Servicios → Cadena de Favores → SOS → Mapa SOS → Inicio SOS → Atrás Android → Dashboard → Mapa normal. Se inspeccionó el placeholder con una sola barra inferior; el registro de errores de Flutter estaba vacío.

La fase 8 implementa el tablero de emergencia en `/sos/tablero`, accesible desde Modo SOS en Inicio y el Drawer. Muestra un encabezado rojo con «MODO DEMOSTRACIÓN — No hay alertas reales verificadas», cinco reportes ficticios con distancias simuladas, prioridades y detalles de solo lectura. Los tres principales son Persona atrapada (Crítica, 120 m), Necesita agua (Urgente, 250 m) y Daño en vivienda (En revisión, 400 m); ampliar permite consultar Necesita abrigo (Urgente, 550 m) y Revisión de techo (En revisión, 700 m). La lista se puede contraer.

Validación inicial de fase 8 (7 de noviembre de 2026): formato de `lib` y `test` aplicado, `flutter pub get` completado, `flutter analyze` sin incidencias y `flutter test` con 31 pruebas aprobadas. `flutter run -d emulator-5554 --no-resident` compiló e instaló la app en Pixel 6 (Android 17, API 37). Se inspeccionaron visualmente el tablero y las acciones tras desplazamiento, sin desbordamientos visibles; el registro de errores de Flutter estaba vacío. El tamaño de 320 px con texto al 150 % se verificó mediante pruebas de widgets.

Solicitar y Ofrecer ayuda abren los selectores locales del Centro de Ayuda Vecinal (fase 9). Ver mapa de reportes abre el Mapa de Emergencia. Se conserva el inicio en `/inicio` y la navegación inferior de cinco pestañas. No existen alertas ni registros reales. Quedan pendientes Supabase, GPS, reportes reales, solicitudes y ofrecimientos de ayuda, confirmación de alertas, brigadas reales, seguimiento, notificaciones, sincronización offline y chat de emergencia. `test/emergency_dashboard_test.dart` verifica la interfaz, las interacciones y el diseño a 320 px con texto al 150 %, junto con las pruebas anteriores.

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

## Publicación rápida

Abre Publicar, elige una de las cuatro plantillas y pulsa «Confirmar demostración». Puedes editar el título y el detalle antes de confirmar. «Ver mi publicación» muestra la vista previa local. El borrador se descarta al salir del recorrido.

## Organización

El proyecto usa Material 3, go_router y una estructura por funcionalidad preparada para MVVM. Desde Inicio o el Drawer, «Cadena de Favores» abre el Muro Colaborativo. Filtra las tarjetas con Todos, Ofrezco, Necesito y Dono, o abre «Explorar economía solidaria» para consultar donaciones, solicitudes, intercambios y préstamos. Ambas vistas usan publicaciones ficticias. Contactar, favoritos y comentarios muestran avisos informativos. El tablero SOS de demostración está implementado.

- [Arquitectura](docs/ARCHITECTURE.md)
- [Pantallas y rutas](docs/ROUTES.md)
- [Recursos originales](docs/ASSETS.md)
- [Funciones pendientes](docs/BACKLOG.md)

## Mapa de recursos

La pestaña Mapa muestra seis puntos ilustrativos sin conexión. Busca por nombre, categoría o descripción y activa las categorías desde la leyenda. Cada marcador abre su ficha y los dos comercios enlazan al perfil del directorio.

Desde la confirmación de ayuda, «Ver simulación de seguimiento» abre la coordinación local de la fase 12. La ruta dibujada y los perfiles son ficticios. Llamar muestra un aviso y Chat permite leer dos mensajes de ejemplo. No hay aceptación real, llamadas ni envío de mensajes.

La fase 13 incorpora el Mapa de Emergencia en /sos/mapa. Toca un marcador para consultar su ficha o filtra por solicitudes urgentes, reportes en revisión, recursos y brigadas. Todos restablece la vista. El plano y la disponibilidad son ficticios. Funciona sin GPS, reportes reales ni backend.

## Visto Bueno Vecinal

Desde el perfil de un proveedor, «Calificar experiencia (demo)» abre el formulario de la fase 14. Elige entre una y cinco estrellas y, si lo deseas, escribe hasta 300 caracteres. «Previsualizar Visto Bueno» muestra cómo se leería la opinión. Puedes cerrar el diálogo y corregirla. Al salir del formulario se descarta el borrador.
