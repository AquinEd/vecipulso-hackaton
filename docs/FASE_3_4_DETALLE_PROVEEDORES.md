# Fase 3.4 — Fichas públicas y recomendaciones

La ruta /servicios/:id resuelve el UUID mediante ServicesRepository.detail. ServiceDetailController carga la proyección pública del proveedor, categoría, nombre de zona, años de experiencia, descripción, trabajos textuales y reseñas con autor público, puntaje, comentario opcional y fecha. Los servicios inactivos producen el estado de registro no disponible. La ficha permite actualizar, reintentar y regresar mediante la navegación existente.

## Archivos

- lib/features/services/presentation/screens/provider_detail_screen.dart integra ServiceDetailController y reutiliza AppCard, AppSectionHeader y ServiceHeading.
- lib/features/services/presentation/controllers/services_controllers.dart amplía ServiceDetail con categoría, zona y estadísticas y comprueba activo.
- lib/features/services/data/services_repository.dart añade zoneName y lectura paginada de puntajes. Reutiliza contact, works, provider y detail. Expone RecommendationsRepository con el mismo SupabaseClient mediante recommendations.
- test/support/directory_fixture.dart incorpora las lecturas simuladas necesarias para conservar las pruebas del directorio.
- test/provider_detail_real_test.dart comprueba datos públicos, reseñas nulas, privacidad, estados vacíos, fallos, reintento y descarte de cargas antiguas.
- test/services_data_layer_test.dart verifica las páginas de puntajes y parámetros del helper SQL del sello.

Los modelos ServiceRow, PublicProvider, ServiceContact, ServiceWork y ServiceReview proceden de 3.2. La composición de Provider usa el cliente existente. Un controlador con clave del UUID evita reutilizar el estado al cambiar de servicio. Se descartan respuestas antiguas y las posteriores a dispose.

## Consultas y privacidad

Se consultan servicios por id, categorias_servicio y zonas.nombre por zona_id. perfiles_publicos_de_mi_zona() filtrada por proveedor_id entrega nombre_publico, avatar_url, zona_id y vecino_confiable. La ficha muestra el nombre público íntegro y usa iconos estáticos. Los datos privados del perfil quedan fuera de las consultas.

La política contacto_lectura de INSTALACION_UNICA_VECIPULSO_MVP.sql, línea 1436, permite lectura al propietario y a vecinos de la zona si autorizado=true. El repositorio aplica además autorizado=true a todas las lecturas para presentación. El widget también comprueba esa bandera antes de crear el texto seleccionable. El propietario puede consultar por SQL su contacto no autorizado, pero esta ficha presenta exclusivamente el autorizado. La ausencia de fila se muestra como Contacto no disponible. No se inicia llamada ni mensajería.

servicio_trabajos contiene título y fecha, con visibilidad de zona. La ficha presenta títulos con iconos. El esquema carece de una URL de imagen en esa tabla, por lo que la carga de fotos queda pendiente de un contrato posterior.

resenas_de_servicio(p_servicio uuid), definida en línea 1170 del instalador, entrega id, autor público, puntaje, comentario nullable y creado_en. La lectura se pagina por rangos de hasta 500, con orden de fecha definido por la RPC e id como desempate. Se continúa hasta recibir una página vacía. Las fechas se presentan en la zona horaria del dispositivo.

## Media, conteo y sello

La RPC de cercanía ofrece agregados pero requiere coordenadas. Para el detalle por UUID se leen todos los puntajes autorizados desde recomendaciones, por páginas ordenadas por id. El desplazamiento avanza por la cantidad efectivamente recibida para admitir límites de respuesta inferiores al tamaño solicitado. Se calcula suma/cantidad y se consulta tiene_visto_bueno(n bigint, promedio numeric) con la media sin redondear. El helper existente exige n>=3 y promedio>=4.0. La media se redondea solo al presentarla.

Sin puntajes se presenta Sin valoraciones. Tener una reseña o media alta no basta para mostrar el sello. El helper y la regla proceden del contrato de 3.1, del SQL 001 y del instalador efectivo, línea 468.

Las lecturas paginadas son independientes y no tienen snapshot transaccional. Si otra sesión modifica recomendaciones durante la carga, puede haber diferencias transitorias entre el listado de reseñas y las estadísticas. Actualizar vuelve a consultar todo. Para un volumen elevado o consistencia transaccional será conveniente una RPC de detalle agregada en una fase SQL autorizada. Los autores que ya no sean visibles por zona pueden faltar en resenas_de_servicio aunque existan puntajes visibles, según el join del contrato.

## Errores y alcance

Cualquier fallo de la composición muestra ServicesFailure y Reintentar. No se presenta una media parcial si falla una página. La ausencia de perfil público tiene un mensaje neutral. Los trabajos y reseñas vacíos tienen mensajes específicos. Se conservan las entradas demostrativas explícitamente identificadas de Inicio y Mapa para sus IDs demo. El directorio real usa UUID y consulta la ficha real.

## Validación Android pendiente

1. Con una cuenta sintética existente, abrir Servicios del Barrio y tocar un servicio. Comprobar título, categoría y zona contra los datos autorizados del entorno.
2. Verificar nombre público, experiencia, trabajos de texto, reseñas con fecha y comentario ausente.
3. Abrir un servicio sin reseñas y comprobar Sin valoraciones y ausencia de sello.
4. Con dos cuentas sintéticas existentes de la zona, revisar que un teléfono sin autorización no se presenta y uno autorizado sí. Verificar además servicios de otra zona como inaccesibles usando fixtures existentes.
5. Volver al directorio y comprobar que conserva la búsqueda. Abrir otro servicio rápidamente y verificar que su UUID determina el contenido.
6. Desactivar la conexión antes de actualizar. Comprobar el mensaje de fallo, restaurar la red y reintentar.
7. Usar servicios existentes inactivos/eliminados para comprobar el estado no disponible. Evitar crear o cambiar datos remotos durante esta verificación.

Las pruebas manuales Android, lecturas con usuarios Supabase reales y revisión efectiva de RLS en el despliegue quedan no ejecutadas. Las pruebas automatizadas usan repositorios y HTTP simulados.

La fase 3.5 puede conectar solicitudes y elegibilidad con sus repositorios existentes. Debe conservar la autoridad de RLS y de actualizar_solicitud_servicio para completar solicitudes. Las nuevas recomendaciones siguen dependiendo de experiencia completada y de UNIQUE(servicio_id,autor_id).

## Resultados locales

flutter pub get completado con las dependencias existentes. flutter analyze sin incidencias. La suite completa flutter test --concurrency=1 aprobó 138 pruebas en 2 min 24 s. Después se añadió el caso positivo del sello y se ejecutaron las siete pruebas de provider_detail_real_test.dart con éxito. En total, 139 casos distintos aprobados y cero fallos pendientes. El formato se aplicó exclusivamente a los seis Dart de esta fase. git diff --check pasó. No se ejecutaron lecturas ni escrituras contra Supabase real, ni pruebas Android manuales. La integración real de autenticación que crea usuarios quedó fuera de la ejecución local.
