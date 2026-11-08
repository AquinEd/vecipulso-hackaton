# VeciPulso MVP — Guía de instalación inicial y roadmap

## Primero Supabase, luego Flutter

1. Crear un proyecto nuevo en el Dashboard de Supabase.
2. En **Authentication → Sign In / Providers → Anonymous**, activar inicio de sesión anónimo.
3. Abrir **SQL Editor**, crear una consulta y pegar el contenido de `INSTALACION_UNICA_VECIPULSO_MVP.sql`.
4. **ANTES DE EJECUTAR:** cambiar el nombre, latitud y longitud del barrio ficticio en el bloque final `insert into public.zonas`. Por defecto el seed original está en Lima. El radio debe adaptarse a la sede de prueba.
5. Ejecutar `Run` **solo una vez en la base vacía**. El archivo crea tipos, 26 tablas public, políticas, RPC, índices, Storage (cuando exista), Realtime, parche MVP y datos de prueba de catálogos. Se ejecuta dentro de una transacción para evitar dejar parcialmente creada la instalación si falla.
6. Ejecutar `VERIFICAR_INSTALACION.sql`. Confirmar 26 tablas, 0 tablas sin RLS, 0 RPC públicas ejecutables por anon, extensiones ubicadas correctamente y tablas presentes en la publicación Realtime.
7. En Project Settings / Connect obtener `Project URL` y la **publishable key** (o anon key legada). **Nunca** usar `service_role` ni claves secretas en Flutter.
8. Añadir `supabase_flutter` en `pubspec.yaml`, inicializar `Supabase.initialize(...)` en `main.dart`, hacer login anónimo con `supabase.auth.signInAnonymously()` antes de invocar las RPC de registro.
9. Crear DOS usuarios de prueba desde la app. Para valorar un servicio, completar antes una solicitud de servicio real de prueba; la base impide reseñas de usuarios sin solicitud completada.

## Entrega y decisiones

- `INSTALACION_UNICA_VECIPULSO_MVP.sql` es el archivo principal para instalación nueva; los `001-004` permiten inspeccionar etapas y la semilla por separado. **No ejecute ambos métodos sobre la misma base.**
- No ejecutar la instalación repetidamente: los `create table` y `create type` originales de v5 no son idempotentes.
- `004_datos_demo_OPCIONAL.sql` es exclusivamente para desarrollo; incluye teléfonos de emergencia a contrastar y brigadas ficticias.
- Las acciones offline y las imágenes de mapas requieren código Flutter; una columna `creado_local` no equivale a sincronización offline.
- Las cuentas anónimas no son recuperables si se cierra sesión, borra datos o cambia de dispositivo. El PIN es un bloqueo de UI, **no** autenticación de backend.
- No desplegar la solución como servicio de emergencias real sin pruebas de seguridad, abuso, fiabilidad, privacidad, limitaciones y verificación institucional.

## Plan de 22 horas (objetivo, no garantía)

| Fase | Horas | Entregable de validación |
| --- | ---: | --- |
| 1. Supabase limpio y prueba SQL | 2.5 | 26 tablas, RLS, RPC, catálogos; verificaciones pasan |
| 2. Flutter supabase_flutter + sesión + registro/PIN | 2.5 | Usuarios A y B creados, sesión persistida |
| 3. Servicios + reseñas Visto Bueno | 3.5 | Servicio publicado, fichas y recomendación real validada |
| 4. Muro + creación/respuesta | 3.5 | Publicación del A visible al B; respuesta y aceptación |
| 5. SOS + recursos + brigadas | 4.0 | B ve alerta de A, ofrece ayuda, se acepta, se completa |
| 6. Mapa con ubicaciones y marcadores | 2.0 | Servicios, alertas y recursos aparecen en mapa real |
| 7. Offline de solo lectura + tutorial | 1.0 | Datos consultados anteriormente accesibles sin red |
| 8. QA con dos dispositivos + APK + demo | 3.0 | Demo completa con sin/red, permisos y errores |
| **Total** | **22.0** | **MVP demostrable** |

Si el cronograma se atrasa: conservar servicio con recomendación, muro, ayuda SOS, mapa y tutorial. Postergar chat en vivo, edición de perfiles, filtros avanzados, push y membresías. No omitir pruebas de dos usuarios.

## Verificaciones complementarias

- Registrar con el PIN de 6 cifras; el login anónimo autentica el usuario y la RPC `verificar_pin` solo desbloquea el UI.
- El PIN no debe permitir acceder a datos de otro usuario o crear sesiones en otro teléfono.
- Validar reintentos duplicados por UUID en `publicar_rapido()` y `emitir_alerta()`.
- Si la sede real está lejos del barrio del seed original, cambiar coordenadas ANTES del primer `Run`; con geofiltros fuera de radio no aparecerán resultados.
- Si SQL Editor muestra un error no continuar con inserciones parciales: revisar el mensaje y restaurar/crear nueva base limpia para repetir la instalación.

### Enlaces oficiales
- https://supabase.com/docs/guides/auth/auth-anonymous
- https://supabase.com/docs/guides/database/extensions/postgis
- https://supabase.com/docs/guides/database/functions
- https://supabase.com/docs/guides/realtime/subscribing-to-database-changes

## Estado de verificación del paquete

Inspección estática realizada (archivos y delimitadores SQL); **no se ejecutó contra un servidor PostgreSQL/Supabase real**. Una consulta puede requerir adaptación por la configuración exacta o versión del proyecto nuevo. Antes de conectar Flutter, confirmar con `VERIFICAR_INSTALACION.sql` y una prueba desde dos sesiones.
