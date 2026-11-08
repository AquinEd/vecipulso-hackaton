# Fase 6.1 — Contrato geográfico Supabase/PostGIS

Contrato estático del checkout main, 2026-11-08. No se consultó ni alteró Supabase remoto. Las firmas se reproducen literalmente del SQL al final; no son declaraciones nuevas para ejecutar.

## Procedencia y versión efectiva

docs/database/001_esquema_base_v5.sql define las lecturas geográficas. 002_complemento_v5.sql no reemplaza puntos_mapa ni las búsquedas cercanas. 003_correcciones_mvp.sql reemplaza publicar_rapido y emitir_alerta para validar coordenadas y zona, además de corregir ayuda y membresías. El instalador único integra 001 → 002 → 003 → semilla 004; no ejecutarlo sobre una base existente. Los títulos históricos v4/parche004 de comentarios no alteran ese orden.

Se buscaron SQL en el repositorio: los scripts efectivos están en docs/database/. No hay otra migración de mapa en este checkout. Las definiciones de lecturas del anexo coinciden con las del instalador; sus posiciones consolidadas principales son buscar_servicios_cercanos:1137, buscar_publicaciones_cercanas:1181, alertas_cercanas:1210, sugerir_coincidencias:1247, contraparte_ayuda:1267 y puntos_mapa:1288.

## Entidades geográficas verificadas

| Tabla y fuente 001 | Ubicación | Columnas relevantes y relaciones | Visibilidad |
|---|---|---|---|
| zonas:108 | centro geography(Point,4326) NOT NULL | id UUID PK, nombre obligatorio, sector nullable, radio_m int DEFAULT 2000 CHECK >0 | Catálogo SELECT para anon y authenticated |
| perfiles:119 | No tiene punto GPS | id PK/FK auth.users, zona_id FK zonas obligatorio | SELECT propio; zona se obtiene por mi_zona() |
| servicios:162 | ubicacion_aprox geography(Point,4326) NOT NULL | id UUID, proveedor_id FK perfiles, categoria_id FK categorias_servicio, zona_id FK zonas; titulo, descripcion nullable, activo DEFAULT true | SELECT de mi zona, incluidos inactivos si consulta directa |
| publicaciones:214 | ubicacion_aprox geography(Point,4326) NOT NULL | id UUID, autor_id FK perfiles, zona_id, tipo/categoria, titulo/detalle, estado DEFAULT abierta, vence_en DEFAULT now()+7 days | SELECT de mi zona; la RPC filtra abiertos/en coordinación y no vencidos |
| alertas_sos:242 | ubicacion_aprox geography(Point,4326) NOT NULL | id UUID, autor_id, zona_id, clase/tipo/urgencia, estado, creado_en/cerrado_en | SELECT de mi zona; puntos_mapa filtra abiertos de últimas 24 h |
| recursos_criticos:261 | ubicacion_aprox geography(Point,4326) nullable | id UUID, propietario_id, zona_id, tipo, cantidad >0, descripcion, disponible DEFAULT true | SELECT de mi zona; mapa solo disponible y punto no nulo |
| grupos_apoyo:308 | ubicacion_aprox geography(Point,4326) nullable | id UUID, zona_id, nombre, tipo brigada/voluntarios, especialidad/sector/integrantes/contacto opcionales | SELECT de mi zona, contacto público de zona por diseño |
| respuestas:230; sos_respuestas:275 | ubicacion_aprox nullable | Participantes de una coordinación, sin zona_id propia | Privadas por participante/autor/admin según tabla; nunca capas generales |
| vecinos_vulnerables:321 | ubicacion_aprox NOT NULL | vecino_id, zona_id, consentimiento | Propio o admin de mi zona; excluir del mapa comunitario |

No existen columnas latitude/longitude ni lat/lng en estas tablas. lat/lng son proyecciones de RPC. No hay tabla de polígonos de riesgo, rutas viales ni telemetría continua. servicio_contacto está separado y protegido por autorizado/propiedad/zona; no se une a puntos_mapa. perfiles.telefono requiere sus reglas de consentimiento, no debe incorporarse a marcadores.

Índices: GiST idx_servicios_geo, idx_publicaciones_geo, idx_alertas_geo, idx_recursos_geo, idx_grupos_geo, idx_vulnerables_geo en 001:382–387; B-tree por zona/estado/fecha/disponibilidad en 390–415. zonas no declara un índice espacial propio en estos scripts. No se afirma un plan de ejecución medido: EXPLAIN/latencia remotos quedan pendientes.

## Sistema y formato: no intercambiar ejes

- PostGIS almacena geography(Point,4326), WGS84. ST_MakePoint recibe X=longitud, Y=latitud; cada RPC construye ST_MakePoint(p_lng,p_lat).
- La salida usa ST_Y(...::geometry) como lat y ST_X(...) como lng. LatLng del cliente recibe latitud primero. GeoJSON usa coordinates=[longitud,latitud]. WKT POINT usa longitud espacio latitud.
- Distancias usan geography, metros; ST_DWithin filtra por metros y distancia_m es round(ST_Distance(...))::int. Es distancia geográfica entre puntos aproximados, no distancia vial ni tiempo de llegada.
- Las RPC retornan listas JSON de objetos con números lat/lng, UUID como cadena y enums como literales SQL. El parser Dart debe aceptar num y convertir a double, validar finitud/rangos, UUID, nulos y listas vacías; no convertir cadenas arbitrarias a coordenadas silenciosamente.
- SELECT directo de geography puede devolver cadena hexadecimal WKB/EWKB, no un objeto con lat/lng. La guía oficial de Supabase muestra este formato y recomienda proyección ST_Y/ST_X. [PostGIS en Supabase](https://supabase.com/docs/guides/database/extensions/postgis). El formato exacto del despliegue aquí no se observó.
- Preferir puntos_mapa a decodificar cada tabla. Solo el fallback de zonas.centro necesita decoder validado con Point 2D/SRID 4326/endian. No asumir que el valor es GeoJSON ni que se puede hacer split por coma. Ante un formato no soportado, mostrar error, nunca fabricar ubicación.

aplicar_aproximacion (001:463) usa centro de zona si falta punto y la fila tiene zona_id. aproximar (001:457) aplica ST_SnapToGrid(...,0.0015), rejilla angular aproximadamente 166 m norte/sur; el tamaño este/oeste depende de latitud. No garantiza anonimato ni un error radial fijo. tg_aproximar se instala en INSERT o UPDATE de ubicación de servicios, publicaciones, respuestas, alertas, ayudas, recursos, vulnerables y grupos (001:550–562). Sin zona_id, una ubicación nullable puede permanecer nula. zonas.centro no pasa por ese trigger.

## puntos_mapa: contrato y alcance

Firma/retorno literales en anexo. p_lat y p_lng son obligatorios; p_radio_m int DEFAULT 3000. No admite p_zona, p_capa, p_query, p_zoom, bbox ni fecha. No tiene GPS implícito ni fallback al centro del perfil.

| capa literal | titulo | subtipo | estado | urgencia | Condiciones |
|---|---|---|---|---|---|
| comercio | servicios.titulo | categorias_servicio.nombre | activo (texto constante) | NULL | s.activo y dentro del radio |
| recurso | Tipo formateado con initcap/reemplazo de guion bajo | tipo_recurso como texto | disponible (constante) | NULL | disponible y ubicación no nula, radio |
| alerta | Tipo formateado | tipo_emergencia como texto | estado_alerta | urgencia_alerta | sin_verificar/verificada, creado_en > now()-24h, radio |
| brigada | grupos_apoyo.nombre | tipo_grupo como texto | activo (constante) | NULL | ubicación no nula, radio; incluye voluntarios |

El estado activo de brigada es una etiqueta de la consulta, no columna ni prueba de actividad. El de recurso no reserva cantidad. No retorna descripcion, nombre de proveedor, contacto, promedio, visto_bueno, fecha, autor_id ni zona_id. No calcular esos datos desde el título. Todos los UNION ALL se filtran además por RLS de tablas.

Es language sql stable y SECURITY INVOKER por omisión; search_path public,extensions. SELECT de cada tabla exige zona_id=mi_zona() (001:1409,1522,1554,1564). Elegir un origen en otro barrio o ampliar radio no permite leer otra zona. Sin perfil mi_zona() retorna NULL y normalmente las capas quedan vacías; distinguir esa condición con preconsulta, no anunciar que no existen recursos.

No hay ORDER BY ni LIMIT/OFFSET dentro de la función. Supabase puede limitar filas del resultado. No asumir completitud ni orden de cercanía; pedir order por capa,id mediante PostgREST si se pagina (no son parámetros SQL), documentar que no hay snapshot durante cambios concurrentes y señalar truncamiento. Para escalar, revisar consulta de viewport/filtrado en una futura tarea SQL autorizada. No inventar una RPC bbox.

No contiene validaciones explícitas de rango/NULL/radio ni RAISE de negocio. Validar entradas en cliente sin sustituir RLS. NULL no proporciona alternativa de zona; coordenadas/radio incompatibles pueden producir vacío, error o comportamiento PostGIS que debe comprobarse. Sesión inválida/expirada, permiso EXECUTE, caché de esquema desactualizada, extensión/search_path y timeouts son errores, nunca listas demo de respaldo.

## Otras RPC geográficas

Todas las columnas exactas y defaults están en el anexo.

| Función | Seguridad y filtros efectivos | Uso propuesto |
|---|---|---|
| buscar_servicios_cercanos | Invoker; activo, radio, texto unaccent/lower en título/descripción/categoría y promedio mínimo. Join a perfiles_publicos_de_mi_zona. promedio puede ser NULL sin reseñas; tiene_visto_bueno aplica >=3 y media>=4 | Directorio/estadísticas reales si módulo disponible. No existe filtro categoria_id ni nombre de parámetro diferente |
| buscar_publicaciones_cercanas | DEFINER, pero exige p.zona_id=mi_zona(), estado abierta/en_coordinacion, vence_en>now(), radio y tipo opcional | Favores opcionales por segunda RPC, nunca asumir capa de puntos_mapa. Incluye nombre público, conteos y ya_respondi, no filas privadas de respuestas |
| alertas_cercanas | Invoker, abiertas de 24h, orden por urgencia y distancia; es_mia y verificada derivados | Alternativa de capa SOS enriquecida. La verificación es comunitaria, no institucional |
| resumen_emergencia | DEFINER con z.id=mi_zona(); reporte crítico verificado de 24h para en_riesgo | Indicador textual de zona; no devuelve polígono ni ubicación de riesgo |
| sugerir_coincidencias | DEFINER, solo autor de alerta abierta, recursos disponibles de su zona y de otro propietario, tipo compatible y radio desde alerta | Coordinación privada, fuera del mapa público. No asigna recursos |
| contraparte_ayuda | DEFINER, solo voluntario o autor de alerta; coordenadas de contraparte pueden ser NULL; teléfono solo con compartir_telefono y aceptada/en_camino | Detalle privado futuro, nunca alimentar mapa general. Distancia coalesce puede ser 0 sin coordenada real de voluntario |
| mi_zona | DEFINER, retorna zona_id de perfil con id=auth.uid(), NULL si no hay perfil | Origen registrado sin modificar auth |

publicar_rapido y emitir_alerta finales (003:123,167) aceptan coordenadas opcionales pareadas, validan [-90,90]/[-180,180], construyen geography SRID4326 y dejan que trigger use centro cuando faltan o están fuera de dos radios de la zona. Errores explícitos: Perfil incompleto, Latitud y longitud deben enviarse juntas, Coordenadas invalidas, Identificador en uso; también aplican restricciones/cuotas de tablas/triggers. Esa política de escritura no es una validación equivalente en puntos_mapa. No se implementan escrituras en Fase 6.1.

## Permisos y privacidad

001:1338–1346 revoca permisos a anon/authenticated, revoca EXECUTE a PUBLIC/anon y concede SELECT de catálogos a ambos, SELECT de tablas a authenticated. 1374 concede EXECUTE a authenticated, salvo registro interno sin PIN. RLS se activa en 1381–1391. Una cuenta de Auth anónima tiene rol authenticated; el PIN no cambia sus permisos PostgreSQL.

No convertir denegado en una consulta administrativa. No leer perfiles completos, ubicaciones vulnerables ni contactos privados para completar una ficha. Las coordenadas visibles ya fueron aproximadas, pero texto libre puede identificar domicilios. No registrar GPS/JWT ni enviar títulos/descripciones a servicios de teselas/geocodificación. No persistir GPS del visitante al abrir mapa.

Hallazgos SQL preexistentes, no explotados:

- Crítico independiente del mapa: cerrar_alerta (001:961) SECURITY DEFINER usa IF NOT(mi_rol()='admin' OR EXISTS ayuda) y mi_rol NULL sin perfil puede omitir rechazo. No invocarla ni afirmar seguridad general de SOS por leer mapas; requiere corrección SQL autorizada antes de producción.
- confirmaciones_de (001:1331) DEFINER cuenta por UUID sin comprobación de zona/visibilidad. No usarlo para puntos que no se leyeron bajo RLS.
- En 002:352 la inserción de grupo_miembros admitía autoasignar rol lider; 003:116–118 revoca INSERT/DELETE y elimina políticas. Confirmar parche desplegado; no interfaz de membresías.
- Aproximación no comprueba por sí sola pertenencia física a zona en INSERT directo de servicios/recursos. RLS determina zona declarada y propietario, no distancia al centro. No tratar posición dibujada como prueba de domicilio.

## Alternativa sin GPS y consultas Dart propuestas

No hay función existente centro_de_mi_zona ni columnas perfiles.lat/lng. Es viable sin cambiar SQL: mi_zona() → SELECT de zonas por ese UUID → decodificar centro → puntos_mapa con ese origen. El radio de búsqueda se decide explícitamente; radio_m de la zona no sustituye al DEFAULT 3000 sin una decisión de producto. Si no hay zona/centro soportado, bloquear consulta con mensaje y reintento, no usar Lima o el primer catálogo.

Ejemplos de diseño, no código implementado:

```dart
final rows = await client.rpc('puntos_mapa', params: {
  'p_lat': origin.latitude,
  'p_lng': origin.longitude,
  'p_radio_m': radiusMeters,
}).order('capa').order('id').range(offset, offset + pageSize - 1);

final zoneId = await client.rpc('mi_zona');
// Comprobar UUID/no NULL antes de continuar.
final zone = await client.from('zonas')
    .select('id,nombre,centro,radio_m').eq('id', zoneId).single();
// Decoder Point 4326 a implementar y probar; no es un Map lat/lng.
```

Origen GPS y centro de zona deben distinguirse visualmente. Pasar latitud propia para buscar no concede acceso a puntos de otras zonas. Antes de mostrar un detalle, volver a comprobar su visibilidad mediante consulta autorizada; puede haber sido desactivado o eliminado.

## Anexo literal

Las siguientes firmas y el cuerpo de puntos_mapa se extraen de los archivos, conservando tipos y defaults. Las otras funciones se identifican como invoker/definer por su declaración literal. Ningún bloque es una migración.


### puntos_mapa

Fuente: docs/database/001_esquema_base_v5.sql:1271

```sql
create function public.puntos_mapa(
  p_lat double precision, p_lng double precision, p_radio_m int default 3000)
returns table (capa text, id uuid, titulo text, subtipo text, estado text, urgencia text,
               lat double precision, lng double precision, distancia_m int)
language sql stable set search_path = public, extensions as $$
  with o as (select ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography as g)
  select 'comercio', s.id, s.titulo, c.nombre, 'activo', null::text,
         ST_Y(s.ubicacion_aprox::geometry), ST_X(s.ubicacion_aprox::geometry),
         round(ST_Distance(s.ubicacion_aprox, o.g))::int
    from o, public.servicios s join public.categorias_servicio c on c.id = s.categoria_id
   where s.activo and ST_DWithin(s.ubicacion_aprox, o.g, p_radio_m)
  union all
  select 'recurso', r.id, initcap(replace(r.tipo::text, '_', ' ')), r.tipo::text, 'disponible', null,
         ST_Y(r.ubicacion_aprox::geometry), ST_X(r.ubicacion_aprox::geometry),
         round(ST_Distance(r.ubicacion_aprox, o.g))::int
    from o, public.recursos_criticos r
   where r.disponible and r.ubicacion_aprox is not null and ST_DWithin(r.ubicacion_aprox, o.g, p_radio_m)
  union all
  select 'alerta', a.id, initcap(replace(a.tipo::text, '_', ' ')), a.tipo::text, a.estado::text, a.urgencia::text,
         ST_Y(a.ubicacion_aprox::geometry), ST_X(a.ubicacion_aprox::geometry),
         round(ST_Distance(a.ubicacion_aprox, o.g))::int
    from o, public.alertas_sos a
   where a.estado in ('sin_verificar', 'verificada')
     and a.creado_en > now() - interval '24 hours'
     and ST_DWithin(a.ubicacion_aprox, o.g, p_radio_m)
  union all
  select 'brigada', g.id, g.nombre, g.tipo::text, 'activo', null,
         ST_Y(g.ubicacion_aprox::geometry), ST_X(g.ubicacion_aprox::geometry),
         round(ST_Distance(g.ubicacion_aprox, o.g))::int
    from o, public.grupos_apoyo g
   where g.ubicacion_aprox is not null and ST_DWithin(g.ubicacion_aprox, o.g, p_radio_m)
$$;
```

### buscar_servicios_cercanos

Fuente: docs/database/001_esquema_base_v5.sql:1120

```sql
create function public.buscar_servicios_cercanos(
  p_lat double precision, p_lng double precision,
  p_radio_m int default 3000, p_texto text default null, p_min_estrellas numeric default 0)
returns table (id uuid, titulo text, categoria text, descripcion text, proveedor text,
               anios_experiencia smallint, distancia_m int, promedio numeric,
               recomendaciones bigint, visto_bueno boolean, lat double precision, lng double precision)
language sql stable set search_path = public, extensions as $$
```

### buscar_publicaciones_cercanas

Fuente: docs/database/001_esquema_base_v5.sql:1164

```sql
create function public.buscar_publicaciones_cercanas(
  p_lat double precision, p_lng double precision,
  p_radio_m int default 3000, p_tipo tipo_publicacion default null)
returns table (id uuid, tipo tipo_publicacion, categoria categoria_favor, titulo text, detalle text,
               autor text, autor_id uuid, vecino_confiable boolean, distancia_m int,
               estado estado_publicacion, respuestas bigint, ya_respondi boolean,
               lat double precision, lng double precision, creado_en timestamptz)
language sql stable security definer set search_path = public, extensions as $$
```

### alertas_cercanas

Fuente: docs/database/001_esquema_base_v5.sql:1193

```sql
create function public.alertas_cercanas(
  p_lat double precision, p_lng double precision, p_radio_m int default 5000)
returns table (id uuid, clase clase_alerta, tipo tipo_emergencia, urgencia urgencia_alerta,
               estado estado_alerta, descripcion text, verificada boolean, es_mia boolean,
               distancia_m int, lat double precision, lng double precision, creado_en timestamptz)
language sql stable set search_path = public, extensions as $$
```

### resumen_emergencia

Fuente: docs/database/001_esquema_base_v5.sql:1214

```sql
create function public.resumen_emergencia()
returns table (zona text, en_riesgo boolean, reportes_activos bigint, actualizado_en timestamptz)
language sql stable security definer set search_path = public as $$
```

### sugerir_coincidencias

Fuente: docs/database/001_esquema_base_v5.sql:1230

```sql
create function public.sugerir_coincidencias(p_alerta uuid, p_radio_m int default 3000)
returns table (recurso_id uuid, tipo tipo_recurso, cantidad int, descripcion text,
               ofrece text, distancia_m int, lat double precision, lng double precision)
language sql stable security definer set search_path = public, extensions as $$
```

### contraparte_ayuda

Fuente: docs/database/001_esquema_base_v5.sql:1250

```sql
create function public.contraparte_ayuda(p_resp uuid)
returns table (nombre text, avatar_url text, soy_solicitante boolean, estado estado_ayuda,
               ayudas_completadas bigint, distancia_m int, lat double precision, lng double precision,
               telefono text)
language sql stable security definer set search_path = public, extensions as $$
```

### mi_zona

Fuente: docs/database/001_esquema_base_v5.sql:432

```sql
create function public.mi_zona() returns uuid
language sql stable security definer set search_path = public as $$
  select zona_id from public.perfiles where id = auth.uid()
$$;
```

### aproximar

Fuente: docs/database/001_esquema_base_v5.sql:457

```sql
create function public.aproximar(g extensions.geography) returns extensions.geography
language sql immutable set search_path = public, extensions as $$
  select extensions.ST_SnapToGrid(g::extensions.geometry, 0.0015)::extensions.geography
$$;
```

### aplicar_aproximacion

Fuente: docs/database/001_esquema_base_v5.sql:463

```sql
create function public.aplicar_aproximacion() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare v_zona uuid;
begin
  if new.ubicacion_aprox is null then
    v_zona := nullif(to_jsonb(new) ->> 'zona_id', '')::uuid;
    if v_zona is not null then
      select centro into new.ubicacion_aprox from public.zonas where id = v_zona;
    end if;
  end if;
  if new.ubicacion_aprox is not null then
    new.ubicacion_aprox := public.aproximar(new.ubicacion_aprox);
  end if;
  return new;
end $$;
```

### publicar_rapido (versión final)

Fuente: docs/database/003_correcciones_mvp.sql:123

```sql
create or replace function public.publicar_rapido(
  p_id uuid, p_tipo tipo_publicacion, p_titulo text,
  p_detalle text default null, p_categoria categoria_favor default 'otro',
  p_lat double precision default null, p_lng double precision default null,
  p_creado_local timestamptz default null)
returns uuid
language plpgsql security definer set search_path = public, extensions as $$
```

### emitir_alerta (versión final)

Fuente: docs/database/003_correcciones_mvp.sql:167

```sql
create or replace function public.emitir_alerta(
  p_id uuid, p_clase clase_alerta, p_tipo tipo_emergencia, p_urgencia urgencia_alerta,
  p_descripcion text default null,
  p_lat double precision default null, p_lng double precision default null,
  p_creado_local timestamptz default null)
returns uuid
language plpgsql security definer set search_path = public, extensions as $$
```
