# PowerSync en una fase posterior

## Arquitectura propuesta

Mantener Supabase Auth como origen de identidad y los repositorios como frontera entre Flutter y los datos. Añadir el SDK Flutter `powersync` en la fase offline. Evaluar `path_provider` y `path` si el almacenamiento elegido requiere resolver una ruta local. Cada repositorio podrá consultar una proyección SQLite y exponer la antigüedad del último dato sincronizado.

## Orden de integración

1. Acordar con backend las columnas y filas permitidas. Empezar por nombres de zonas y categorías de servicio. Para publicaciones, considerar únicamente contenido visible en la zona del usuario y mantener las condiciones de visibilidad y vigencia del SQL.
2. Preparar una instancia de desarrollo de PowerSync Cloud, conexión TLS a PostgreSQL, publicación de replicación limitada a esas tablas y credenciales de replicación gestionadas en servidor. Configurar la validación de JWT de Supabase y los Sync Streams. Los streams deben aplicar su propio control de lectura. [Guía de PowerSync para Supabase](https://docs.powersync.com/integrations/supabase/guide)
3. Autorizar cada suscripción con el usuario del JWT y su pertenencia a zona comprobada en servidor. Proyectar únicamente columnas necesarias. Excluir DNI, hashes, credenciales de PIN, el esquema privado, teléfonos privados y ubicaciones sensibles. Decidir cifrado y retención del archivo local. Separar las bases por identidad y purgar los datos revocados al cambiar de usuario o zona.
4. Verificar lecturas sin red, cambio de zona y aislamiento con dos dispositivos. Mantener el registro y la verificación del PIN en línea. Un cliente desconectado puede conservar información que acaba de ser revocada, por lo que se necesita una política de caducidad.
5. Evaluar escrituras por operación. Una lectura offline usa la última copia autorizada. Una escritura offline requiere una cola con autor, identificador idempotente, estado pendiente, reintentos y resolución de rechazos. Enviar favores mediante `publicar_rapido` y alertas mediante `emitir_alerta`. La interfaz solo podrá mostrar envío confirmado cuando responda la RPC. Antes de habilitar SOS offline, acordar caducidad y comportamiento ante alertas tardías.

Esta fase entrega el diseño de integración. La sincronización y la cola de escrituras quedan pendientes.
