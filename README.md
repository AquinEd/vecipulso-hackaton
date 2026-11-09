# VeciPulso

VeciPulso es una aplicación móvil que busca fortalecer la colaboración entre vecinos. Permite registrarse en una zona y consultar puntos de interés comunitario en un mapa. También ofrece recorridos de demostración para explorar el intercambio de favores y la ayuda vecinal en emergencias.

## Funcionalidades del aplicativo

| Función | Qué puedes hacer en el MVP |
| --- | --- |
| Registro y acceso | Crear un perfil asociado a una zona y desbloquear el acceso con un PIN de seis dígitos. El registro y la verificación del PIN utilizan Supabase. |
| Mapa comunitario y SOS | Explorar cartografía de OpenStreetMap, filtrar puntos y consultar los registros que Supabase permite ver desde el origen de búsqueda. Entre las capas hay servicios, alertas, recursos críticos y brigadas. Puedes solicitar una lectura puntual de tu ubicación. |
| Servicios de Proximidad y Visto Bueno Vecinal | Inicio muestra servicios de ejemplo. En el arranque actual, la pantalla del directorio carece de conexión con su repositorio y muestra «Se requiere una sesión vigente», incluso después de ingresar. Las solicitudes y recomendaciones vinculadas a servicios quedan fuera del recorrido disponible. La valoración de demostración no se publica. |
| Cadena de Favores | Explorar un muro de ejemplo, filtrar sus publicaciones y consultar la vista de economía solidaria. La vista previa de publicación es local. |
| Modo SOS | Recorrer un tablero con reportes de ejemplo, simular una solicitud u oferta de ayuda y consultar brigadas ilustrativas. El tablero arranca en demostración. El mapa SOS sí consulta puntos autorizados. |
| Accesibilidad y tutorial | Ajustar texto, contraste, tamaño de botones e instrucciones durante la sesión. El tutorial explica cómo recorrer la aplicación. |

Mensajes, notificaciones y estados de sincronización son ejemplos de interfaz. No ofrecen chat en vivo, avisos push ni envío diferido de solicitudes.

## Tecnologías utilizadas

Flutter y Dart implementan la aplicación móvil. Provider gestiona el estado y GoRouter controla las rutas y el acceso según la sesión. El cliente usa `supabase_flutter` para Supabase Auth y las consultas a PostgreSQL, con PostGIS para los datos geográficos. El mapa utiliza `flutter_map` y `latlong2`, y obtiene la ubicación del dispositivo mediante `geolocator`.

## Requisitos previos

- Git y Flutter SDK con Dart incluido. Para las dependencias resueltas en este repositorio, utiliza Flutter **3.47.0 o superior** con Dart **desde 3.13.7 hasta antes de 4.0.0**.
- Android Studio con Android SDK y herramientas de compilación. El proyecto configura Java y Kotlin para JVM 17. Gradle toma los niveles mínimo, de compilación y de destino de Android del SDK de Flutter.
- Un emulador Android o un dispositivo físico con depuración USB. Puedes usar VS Code como editor.
- Acceso autorizado a un proyecto Supabase configurado y conexión a internet para descargar dependencias, autenticarte, consultar datos y cargar mosaicos del mapa.

En PowerShell, comprueba el entorno antes de continuar:

```powershell
flutter --version
flutter doctor
flutter devices
```

El primer comando muestra las versiones de Flutter y Dart. El segundo diagnostica la instalación y las herramientas Android. El tercero enumera los dispositivos que Flutter reconoce.

## Clonar el repositorio

```powershell
git clone https://github.com/AquinEd/vecipulso-hackaton.git
cd vecipulso-hackaton
```

Si GitHub solicita autenticación, utiliza una cuenta con permiso de lectura del repositorio.

## Instalar las dependencias

Ejecuta este comando desde la raíz del proyecto, donde se encuentra [pubspec.yaml](pubspec.yaml). Conserva esa carpeta como directorio de trabajo para los siguientes pasos.

```powershell
flutter pub get
```

## Configurar Supabase

**Si el equipo te facilita un backend desplegado**, solicita la URL del proyecto y su clave publicable. Con acceso autorizado a ese backend, pasa directamente a la configuración del cliente.

**Si preparas un proyecto nuevo**, habilita los inicios de sesión anónimos (*Anonymous Sign-ins*) en Supabase Auth. El registro necesita zonas disponibles, y la aplicación espera el esquema de VeciPulso, PostGIS, las funciones de base de datos, sus permisos y las políticas de seguridad por fila (RLS). Para una base **vacía**, revisa el [instalador SQL](docs/database/INSTALACION_UNICA_VECIPULSO_MVP.sql) antes de aplicarlo en el editor SQL de Supabase. Incluye datos de ejemplo con coordenadas de Lima. En una base existente, consulta primero las [comprobaciones de instalación](docs/database/VERIFICAR_INSTALACION.sql). Reaplicar el instalador completo sobre un esquema existente queda fuera de su uso previsto.

**Configura el cliente móvil** con los valores del mismo proyecto:

1. En el panel de Supabase, localiza la **Project URL** en los ajustes de API del proyecto y la **Publishable key** en **API Keys**. El cliente exige una URL HTTPS y una clave con prefijo `sb_publishable_`. Una clave heredada `anon` en formato JWT no supera la validación.
2. Si todavía no tienes configuración local, copia la [plantilla](config/supabase.example.json) desde la raíz:

   ```powershell
   Copy-Item config/supabase.example.json config/supabase.dev.json
   ```

3. En `config/supabase.dev.json`, sustituye ambos marcadores por los valores del proyecto:

   ```json
   {
     "SUPABASE_URL": "https://TU_PROYECTO.supabase.co",
     "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_TU_CLAVE_PUBLICABLE"
   }
   ```

El archivo local está excluido en [.gitignore](.gitignore). La clave publicable está diseñada para distribuirse en clientes. Supabase Auth identifica la sesión y las políticas RLS limitan qué datos puede leer o modificar. Nunca incluyas una clave secreta, una clave `service_role` ni una contraseña administrativa en el aplicativo.

## Ejecutar el aplicativo

En Android Studio, abre **Device Manager** e inicia un dispositivo virtual con el botón de reproducción. Si la lista está vacía, crea un dispositivo y descarga su imagen de Android. También puedes conectar un teléfono y aceptar la autorización de depuración USB.

```powershell
flutter run --dart-define-from-file=config/supabase.dev.json
```

Para elegir un dispositivo concreto, consulta su identificador:

```powershell
flutter devices
```

Sustituye `ID_DEL_DISPOSITIVO` por el identificador Android que aparece en la salida:

```powershell
flutter run -d ID_DEL_DISPOSITIVO --dart-define-from-file=config/supabase.dev.json
```

Flutter incorpora los valores del JSON al compilar. Si los cambias, detén la ejecución y vuelve a lanzar el comando.

## Primer uso de VeciPulso

1. Abre la aplicación con conexión. Al iniciar, comprueba la sesión y presenta el registro si falta el perfil.
2. Introduce tu DNI de ocho dígitos y tu nombre completo. Selecciona una zona de la lista, acepta el tratamiento de datos y pulsa **Continuar**.
3. Crea un PIN de seis dígitos y confírmalo. Elige una combinación distinta de seis cifras iguales, `123456` o `654321`.
4. Tras completar el registro, explora **Inicio**. Cuando vuelvas a abrir la aplicación con el perfil registrado, introduce el PIN para desbloquearla.

Supabase Auth asocia el perfil a una sesión anónima que se conserva en la instalación. El PIN desbloquea ese perfil. Si borras los datos de la aplicación o cambias de dispositivo, el formulario de acceso no permite recuperar la sesión anterior con DNI y PIN.

## Guía rápida de navegación

| Desde la interfaz | Recorrido |
| --- | --- |
| **Inicio → Servicios cercanos** | Explora los ejemplos. En el menú lateral, **Servicios del Barrio** abre el directorio con la limitación indicada en Funcionalidades. Para consultar servicios georreferenciados disponibles, utiliza los filtros del mapa. |
| **Menú lateral → Cadena de Favores** | Filtra el muro por categoría. **Explorar economía solidaria** abre la vista ampliada. |
| **Menú lateral → Modo SOS** | Abre **Centro de ayuda vecinal** para explorar las acciones de ejemplo o **Grupos y Brigadas** para ver los grupos ilustrativos. **Ver mapa de reportes** abre el mapa SOS. |
| **Mapa** | Desplaza o amplía el mapa, ajusta sus filtros y toca un marcador para consultar su resumen. **Usar mi ubicación** solicita permiso para obtener una posición puntual. La consulta de puntos envía el origen a Supabase. |
| **Menú lateral → Accesibilidad** | Activa las preferencias que necesites y revisa la vista previa. **Restablecer ajustes** recupera los valores iniciales. En el mismo menú encontrarás **Tutorial de uso**. |

## Estructura del proyecto

```text
vecipulso-hackaton/
├── android/           Proyecto Android y configuración de Gradle
├── assets/            Imágenes e iconos SVG
├── config/            Plantilla de configuración del cliente
├── docs/              Documentación técnica
│   └── database/      Instalador y consultas de verificación
├── lib/
│   ├── main.dart      Inicialización de Supabase y arranque
│   ├── app/           Navegación, modo SOS y accesibilidad
│   ├── core/          Configuración, tema y utilidades comunes
│   ├── features/      Pantallas, controladores y acceso a datos por módulo
│   └── shared/        Componentes de interfaz compartidos
├── test/              Pruebas locales de lógica e interfaz
├── integration_test/  Pruebas en dispositivo y contra servicios externos
└── pubspec.yaml        Dependencias y recursos de Flutter
```

## Pruebas y validación

Desde la raíz, ejecuta el análisis estático y luego las pruebas locales:

```powershell
flutter analyze
flutter test --concurrency=1
```

Las pruebas de integración se ejecutan por archivo en un dispositivo. Por ejemplo, esta comprobación de los mosaicos necesita internet y habilitación explícita:

```powershell
flutter test integration_test/map_tiles_test.dart -d ID_DEL_DISPOSITIVO --dart-define=ALLOW_MAP_TILE_CHECK=true
```

Para probar el backend, utiliza un proyecto de pruebas aislado, con el esquema instalado, zonas y autenticación anónima habilitada. Pasa su configuración con `--dart-define-from-file`. La [prueba de autenticación](integration_test/supabase_auth_test.dart) crea usuarios y perfiles. Las pruebas de servicios y SOS requieren habilitar escrituras explícitamente, y las de SOS y lectura de puntos requieren además las cuentas y variables indicadas en sus archivos. Revisa cada prueba antes de conectarla al proyecto elegido.

## Solución de problemas frecuentes

| Síntoma | Qué comprobar |
| --- | --- |
| PowerShell no reconoce `flutter` | Añade la carpeta `bin` del Flutter SDK al `PATH`, abre otra terminal y ejecuta `flutter --version`. |
| Android no aparece en `flutter devices` | Espera a que termine de iniciar el emulador. En un teléfono, comprueba el cable de datos, la depuración USB y el permiso de conexión. Revisa `flutter doctor`. |
| El emulador no arranca | Revisa la imagen del dispositivo en Device Manager, la virtualización del equipo y los componentes de Android Emulator en SDK Manager. |
| Falta el JSON o se rechaza la URL o la clave | Comprueba que estás en la raíz, crea la copia local si falta y sustituye los marcadores. Usa la URL HTTPS del proyecto y su clave publicable. Reinicia Flutter con el archivo de configuración. |
| Falla la conexión a Supabase | Verifica internet en el dispositivo, que el proyecto esté disponible y que URL y clave pertenezcan al mismo proyecto. Para el registro, comprueba que se permiten sesiones anónimas. |
| No aparecen zonas o puntos | Comprueba que existen zonas seleccionables y que el perfil tiene la zona correcta. En el mapa, revisa el origen, los filtros y los registros disponibles dentro del área consultada. |
| Supabase devuelve un error de permisos | Comprueba la sesión, el perfil, los permisos de las funciones y las políticas RLS para esa operación y zona. Utiliza las consultas de verificación del esquema. |
| Se denegó la ubicación | Activa la ubicación del dispositivo y concede el permiso a VeciPulso desde los ajustes de Android. Vuelve al mapa y solicita la lectura. En un emulador, configura una posición de prueba. |
| El mapa no carga mosaicos | Comprueba la conexión del dispositivo a OpenStreetMap. Si ves calles pero faltan marcadores, revisa los filtros y la consulta a Supabase. |
| Hay errores tras cambiar dependencias | Comprueba que el SDK satisface los requisitos, ejecuta `flutter pub get` desde la raíz y vuelve a iniciar la aplicación. |

## Consideraciones importantes

VeciPulso es un MVP. El acceso y los datos comunitarios dependen de la conectividad y de un backend Supabase correctamente configurado. La cartografía depende de la disponibilidad de OpenStreetMap y el uso del GPS requiere permiso. El mapa no realiza seguimiento continuo. **VeciPulso no reemplaza a los servicios oficiales de emergencia.** Las acciones de ejemplo del tablero SOS no despachan ayuda.
