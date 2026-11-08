# Autenticación de VeciPulso

## Configurar y ejecutar

El equipo de backend debe instalar v5 corregido, habilitar el acceso anónimo en Supabase Auth y disponer de al menos una fila en `public.zonas`. La Data API debe exponer el esquema público con los permisos y políticas v5. La aplicación necesita la URL HTTPS del proyecto y su clave `sb_publishable_…`. La clave publicable identifica el proyecto y puede distribuirse en Flutter. Los permisos dependen de los grants, las RPC y RLS.

Desde la raíz, copiar el ejemplo una vez y editar la copia local:

```powershell
Copy-Item config/supabase.example.json config/supabase.dev.json
```

Completar `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`. Mantener fuera del cliente las claves administrativas, contraseñas de PostgreSQL y credenciales de replicación. Reiniciar con los defines después de editar la configuración.

```powershell
flutter pub get
flutter run --dart-define-from-file=config/supabase.dev.json
```

## Flujo y contrato v5

- El arranque valida los defines e inicializa Supabase antes de montar Flutter. El controlador consulta la sesión persistida por el SDK y solo pide `perfiles.id` para el UUID autenticado. La configuración incompleta y los errores tienen pantallas propias. Tutorial y accesibilidad admiten acceso público.
- Sin perfil, el formulario lee `zonas(id,nombre)`, normaliza el nombre (3–80 caracteres), valida el DNI de ocho dígitos y requiere zona y consentimiento. Conserva los datos en memoria al avanzar y volver. Para registrar, el usuario introduce y confirma un PIN de seis dígitos. El SQL rechaza seis dígitos iguales y las secuencias ascendentes o descendentes 123456 y 654321.
- La confirmación reutiliza la sesión o solicita `signInAnonymously()`. La RPC transaccional `registrar_completo(p_dni, p_nombre_completo, p_zona, p_consentimiento, p_pin)` recibe el UUID de zona y devuelve `void`. Tras la respuesta, la aplicación vuelve a consultar el perfil. Ante un resultado incierto permite reconsultar. Si ya existe un perfil, exige su PIN.
- Al abrir la app con un perfil existente, el teclado aleatorio envía `verificar_pin(p_pin)`. El JSON indica éxito, formato inválido, sesión o PIN ausente, intentos restantes o la fecha de bloqueo. El temporizador local inhibe entradas durante el bloqueo conocido. El servidor conserva la autoridad sobre los cinco intentos y los cinco minutos de bloqueo.
- El PIN bloquea la interfaz. Su verificación no eleva ni reduce los permisos de la API. Una sesión autenticada conserva las facultades que otorga RLS, incluso con la interfaz bloqueada. El PIN solo permanece en memoria durante la operación. Borrar los datos de la instalación puede hacer perder el acceso. Introducir DNI y PIN en otro dispositivo no recupera la cuenta anónima. [Supabase Anonymous Sign-Ins](https://supabase.com/docs/guides/auth/auth-anonymous)

## Archivos de integración

| Área | Archivos |
| --- | --- |
| Configuración y arranque | Nuevos `config/supabase.example.json`, `lib/core/config/supabase_config.dart`, `lib/core/errors/auth_failure.dart`. Cambios en `.gitignore`, `lib/main.dart`, `pubspec.yaml` y `pubspec.lock`. Dependencia directa añadida `supabase_flutter 2.18.3`. |
| Datos y estado | Nuevos `lib/features/auth/data/auth_repository.dart`, `models/auth_models.dart` y `presentation/controllers/auth_controller.dart` bajo el mismo módulo. El repositorio recibe un cliente Supabase y el controlador recibe el repositorio. |
| Presentación | Nueva pantalla `auth_status_screen.dart`. Adaptación de registro, creación y entrada de PIN y de `auth_validators.dart`. Se retiraron los accesos de prueba de autenticación de Inicio. |
| Navegación | `lib/app/app.dart`, `app_router.dart` y `app_routes.dart` conectan Provider y la protección de rutas. |
| Plataformas | Permiso de internet en Android, entitlements de red en macOS y registradores de plugins generados para Linux, macOS y Windows. |
| Verificación | `test/auth_test.dart` y el nuevo `test/support/auth_fixture.dart`. Las suites existentes que abrían la app o el router inyectan el estado desbloqueado para probar sus pantallas. |
| Documentación | README, esta guía y [plan posterior de PowerSync](POWERSYNC_FASE_POSTERIOR.md). |

## Validación local y siguiente fase

`flutter pub get` y `dart format .` completados. `flutter analyze` sin incidencias. `flutter test` aprobó las 122 pruebas, con repositorio simulado para autenticación. Se cubrieron validaciones, confirmación incorrecta, doble envío, conservación del formulario, registro, DNI duplicado, sesión ausente o restaurada, bloqueo, error de red, acceso directo y ausencia de navegación tras fallo. Se revisaron nombres de archivos y patrones reconocibles de credenciales en el árbol y el historial de las referencias locales. Los SQL de `docs/database/` sirvieron de referencia de lectura.

### Fase 2.1 · Repetir la prueba real

La prueba de dispositivo usa los mismos defines, el repositorio de producción y las dos RPC de v5. Comprueba que el archivo local apunta al proyecto de pruebas previsto. Cada ejecución completa crea dos cuentas anónimas y dos perfiles sintéticos en ese proyecto. El intento de DNI duplicado ocurre en la segunda cuenta, antes de crear su perfil. Los cinco fallos de PIN afectan exclusivamente a la primera cuenta creada por esa ejecución. La prueba conserva los registros del servidor.

```powershell
flutter devices
flutter test integration_test/supabase_auth_test.dart -d emulator-5554 --dart-define-from-file=config/supabase.dev.json
```

Sustituir `emulator-5554` por el dispositivo disponible. El identificador de zona proviene del catálogo remoto. Los DNI y PIN se generan en memoria. Para probar restauración, el test reinicializa el SDK y abre de nuevo las preferencias de Android con una clave de almacenamiento exclusiva de la ejecución. Verifica que permanece el mismo UUID y que el controlador exige PIN. La comprobación RLS consulta dos perfiles cuya existencia se confirmó primero con su propietario. La prueba verifica tanto el rechazo del PIN correcto durante el bloqueo como su aceptación después del plazo del servidor. Reservar al menos cinco minutos más el tiempo de compilación.

### Resultado observado el 7 de noviembre de 2026

En el emulador Android API 37, la prueba de integración aprobó en 5 min 9 s contra el proyecto definido en el JSON local ignorado por Git. Se comprobó también que el endpoint de configuración de Auth anunciaba acceso anónimo habilitado.

| Comprobación real | Resultado |
| --- | --- |
| Arranque de la aplicación | Tras la prueba se instaló y abrió `lib/main.dart` con los defines locales. Android mostró «Crea tu cuenta» usando el almacenamiento habitual de la app. |
| Catálogo con clave publicable y sin sesión | Lectura de al menos una zona con UUID y nombre. El registro utilizó su UUID. |
| Alta y perfil | A llegó a interfaz desbloqueada después de la RPC y de consultar su perfil. El servidor rechazó el DNI duplicado de B. B pudo registrarse con otro DNI en su misma sesión. |
| Sesión persistida | Una nueva inicialización del SDK recuperó el UUID de A desde el almacenamiento de Android. El controlador exigió PIN y el servidor aceptó el correcto. |
| PIN incorrecto | Los primeros cuatro fallos devolvieron 4, 3, 2 y 1 intentos restantes. El quinto devolvió bloqueo con fecha de expiración. El servidor rechazó el PIN correcto durante el bloqueo y lo aceptó al vencer el plazo. |
| RLS de perfiles | A y B leyeron su propio perfil. Al consultar el UUID del otro usuario, ambas sesiones recibieron cero filas. Ambos perfiles pertenecían a la misma zona. |
| Regresión local | `flutter analyze` sin incidencias. Las 122 pruebas de `flutter test --concurrency=1` aprobaron. Una ejecución paralela previa agotó memoria en Windows. |

La primera ejecución creó un perfil antes de fallar al reinicializar la misma instancia de almacenamiento en el propio test. Se corrigió el test para crear una instancia por inicialización, conservando su clave. La ejecución completa creó otros dos perfiles sintéticos. Los tres perfiles permanecieron en el proyecto. El cliente de producción fue compatible con las firmas probadas.

La restauración comprobada reinició el SDK dentro del proceso Android. El cierre forzado del proceso con sesión registrada, la expiración o revocación del token y el corte de red durante una RPC siguen como pruebas manuales.

### Antes de integrar Servicios de Proximidad

La validación de autenticación no consulta el directorio de servicios. El siguiente trabajo se desprende del contrato SQL y del modelo actual de Flutter.

- Inyectar el cliente de la sesión autenticada en el futuro repositorio de servicios. El SQL obtiene la zona mediante `mi_zona()`. Probar el aislamiento con perfiles y servicios de dos zonas distintas.
- Mapear la respuesta de `buscar_servicios_cercanos` al modelo de presentación. El UUID corresponde al servicio, `proveedor` contiene el nombre público ya preparado y distancia se expresa en metros. El modelo de demostración exige nombre y apellido por separado. Contemplar categoría del catálogo, descripción, antigüedad y promedio sin reseñas.
- Acordar el origen de latitud y longitud y qué mostrar cuando el usuario carezca de ubicación. Comprobar los filtros de radio, texto y estrellas con servicios autorizados que tengan coordenadas conocidas.
- Leer el contacto mediante `servicio_contacto` respetando su política de autorización. Validar el detalle cuando el contacto esté oculto. Conservar la lectura del perfil privado limitada al titular.

### Checklist manual de dispositivo

Usar un proyecto de pruebas y dos instalaciones separadas con datos de prueba autorizados.

- [ ] **A** abre sin defines y verifica el diagnóstico. Con defines válidos debe ver las zonas antes de crear una cuenta anónima.
- [ ] **A** intenta avanzar sin consentimiento, confirma un PIN distinto y luego completa los datos correctamente. Comprueba un solo usuario y un solo perfil con el mismo UUID en el proyecto.
- [ ] **A** cierra y abre la aplicación. Verifica que conserva el UUID, exige PIN y bloquea un enlace directo a mensajes. Prueba los intentos restantes, el quinto fallo, la espera y el PIN válido después del bloqueo.
- [ ] **B** intenta registrar el DNI de A. Debe recibir el error y permanecer fuera de Inicio. Vuelve al formulario y registra un DNI distinto. Comprueba que el reintento reutiliza su sesión.
- [ ] Con los JWT de A y B en un entorno de pruebas autorizado, comprueba que cada uno lee su propio perfil y que al consultar el UUID del otro obtiene cero filas. Verifica que el rol sin sesión solo puede consultar los catálogos autorizados.
- [ ] Interrumpe la red antes de la verificación y tras enviar un registro. Al reconectar, comprueba que un perfil ya creado conduce a PIN y que no se duplica la cuenta. Invalida una sesión de prueba y comprueba el diagnóstico, el reintento y el retorno a registro cuando ya no exista sesión.
- [ ] Registra resultados de RPC, RLS y restauración sin copiar JWT, DNI, nombres ni PIN. Estas comprobaciones requieren el proyecto Supabase real.
