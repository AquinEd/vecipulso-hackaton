# Solicitudes y recomendaciones

Desde una ficha real, Solicitar servicio muestra el título y el nombre público del proveedor, acepta un mensaje opcional e inserta en solicitudes_servicio. El repositorio usa el UID autenticado, el UUID del servicio y el estado SQL predeterminado solicitada. RLS exige servicio activo de otro vecino de la zona. El índice parcial permite una sola solicitud viva por solicitante y servicio.

Mis solicitudes está disponible en el directorio y en la ficha. Enviadas usa mis_solicitudes_enviadas() y Recibidas usa mis_solicitudes_recibidas(). Cada fila presenta servicio, contraparte pública, fecha y estado. El proveedor también ve el mensaje recibido. Las acciones requieren confirmación y llaman a actualizar_solicitud_servicio(p_solicitud,p_estado). Tras la RPC se relee la fila y se refresca la bandeja.

| Actor | Estado actual | Acciones |
|---|---|---|
| Cliente | solicitada o contactado | Cancelar |
| Proveedor | solicitada | Marcar contactado, completar o cancelar |
| Proveedor | contactado | Completar o cancelar |
| Ambos | completada o cancelada | Consultar el historial |

Una fila enviada con puedo_recomendar=true ofrece el formulario Recomendar. Reutiliza ReviewStarSelector, valida de una a cinco estrellas y admite comentario opcional de hasta 300 grafemas en la interfaz. El INSERT en recomendaciones envía autor_id de sesión. PostgreSQL exige experiencia completada y aplica UNIQUE(servicio_id,autor_id), incluso si el cliente completó varios encargos. La bandeja relee la elegibilidad después del envío. Cerrar la bandeja en la ficha recarga reseñas y estadísticas. Regresar al directorio actualiza el conteo.

ServiceController protege cada operación mientras espera la respuesta. El formulario conserva el UUID durante los reintentos, muestra errores de dominio y se cierra con confirmación tras la respuesta. Si la red se corta después de que el servidor acepte la escritura, revisar la bandeja antes de volver a crear una solicitud. El sello procede de tiene_visto_bueno y exige tres autores y media cruda de al menos cuatro.
