# Publicar y administrar servicios

En Inicio, abrir Servicios del Barrio, elegir Ofrecer un servicio y guardar el formulario. El título admite entre 3 y 120 caracteres. La categoría proviene de categorias_servicio y la descripción es opcional. El repositorio toma el proveedor de la sesión y la zona mediante mi_zona(). El trigger de servicios completa la ubicación con el centro aproximado de esa zona. El formulario reutiliza su UUID de publicación si se reintenta.

Tras la confirmación se actualiza el directorio y se abre Mis servicios. La consulta selecciona proveedor_id igual al usuario de la sesión e incluye servicios inactivos. Editar cambia título, descripción y activo, conservando años de experiencia. La consulta de actualización filtra por UUID y propietario y exige una fila confirmada. RLS y permisos de columnas siguen siendo la autoridad.

En cada servicio propio se puede guardar un teléfono y seleccionar expresamente si se comparte con la zona. La casilla comienza desmarcada. Para retirar el permiso, guardar el teléfono con la casilla desmarcada. Se inserta o actualiza la fila de servicio_contacto por separado de la publicación. Añadir trabajo inserta un título en servicio_trabajos y el detalle lo lee posteriormente. El contrato dispone de trabajos textuales. No existe una columna que asocie imágenes del bucket con los trabajos.

Publicación, contacto y cada trabajo tienen confirmaciones independientes. Tras pérdida de respuesta comprobar Mis servicios o actualizar la ficha antes de repetir. El MVP conserva el borrador en memoria mientras el formulario permanezca abierto.
