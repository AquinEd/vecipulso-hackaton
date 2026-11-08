# Fase 3.1 — Contrato Supabase verificado en el repositorio

Fecha: 2026-11-08. Auditoría estática; no acredita el estado desplegado ni ejecuta SQL. Los ejemplos Dart son propuestas para implementación futura, no funcionalidades probadas. No incluyen claves, sesiones ni datos personales.

## Procedencia y orden efectivo

La cabecera de `docs/database/INSTALACION_UNICA_VECIPULSO_MVP.sql:4` declara: base 001 → complemento 002 → correcciones 003 → semilla 004. La instalación unificada abre transacción y fija search_path en líneas 15–16; es alternativa a los archivos separados, no un paso posterior. `LEEME_INICIO_Y_ROADMAP.md` prohíbe ambos métodos sobre la misma base. `VERIFICAR_INSTALACION.sql` solo comprueba instalación; no redefine objetos.

Se inspeccionaron los seis SQL. Los encabezados históricos «Parche MVP 004» dentro de 003 y «Migración 003» dentro de 004 no cambian el orden de archivos. 002 agrega favoritos/Storage y reemplaza mis_conversaciones; 003 reemplaza actualizar_ayuda, publicar_rapido y emitir_alerta, políticas de SOS/respuestas y permisos de brigadas. **Ninguna de estas etapas reemplaza las cinco RPC de servicios/reseñas/solicitudes**: sus definiciones efectivas son las de 001. Los bloques correspondientes de la instalación unificada conservan esas definiciones. 004 es semilla de catálogos/zona/brigadas, sin servicios ni recomendaciones; los comentarios de verificación de 22 tablas en la semilla son históricos (instalación completa: 26 tablas de aplicación).

Referencias de línea (archivo 001 → instalación unificada):

| Objeto | 001_esquema_base_v5.sql | INSTALACION_UNICA_VECIPULSO_MVP.sql |
|---|---:|---:|
| zonas / perfiles | 108 / 119 | 125 / 136 |
| categorias_servicio / servicios | 156 / 162 | 173 / 179 |
| servicio_contacto / servicio_trabajos | 176 / 183 | 193 / 200 |
| solicitudes_servicio / recomendaciones | 193 / 203 | 210 / 220 |
| índices | 382–424 | 399–441 |
| mi_zona / tiene_visto_bueno / aproximar | 432 / 451 / 457 | 449 / 468 / 474 |
| triggers de aproximación | 548–561 | 565–578 |
| actualizar_solicitud_servicio | 1046 | 1063 |
| mis_solicitudes_recibidas / enviadas | 1080 / 1093 | 1097 / 1110 |
| perfiles_publicos_de_mi_zona | 1110 | 1127 |
| buscar_servicios_cercanos / resenas_de_servicio | 1120 / 1153 | 1137 / 1170 |
| puntos_mapa | 1271 | 1288 |
| permisos / RLS | 1336–1481 | 1353–1498 |

## Tablas, tipos, relaciones y columnas para Flutter

El anexo reproduce literalmente DDL de las ocho tablas, incluidos tipos, nullabilidad, defaults, FK y CHECK. En las tablas con UUID generado, Flutter debe guardar el UUID retornado o suministrar uno estable en reintentos; los IDs `demo-*` no son válidos. No hay servicio agregado por proveedor: el recurso principal y los conteos son por **servicio.id**.

| Tabla | Columnas que necesita la integración | Relación y observaciones |
|---|---|---|
| zonas | id, nombre, sector; centro/radio_m si se define fallback geográfico | centro es geography(Point,4326), no dos doubles; radio positivo default 2000, no implica filtro automático de todos los servicios |
| perfiles | propio: id,zona_id; ajenos: proyección pública de RPC | id = auth.users.id, cascade al borrar Auth. No reconstruir perfil ajeno mediante SELECT a tabla |
| categorias_servicio | id,nombre,icono | serial PK, nombre UNIQUE; IDs no se deben fijar por posición del enum ni de la semilla. Flutter consume catálogo, no lo crea |
| servicios | id,proveedor_id,categoria_id,titulo,descripcion,anios_experiencia,zona_id,activo,creado_en; ubicación solo cuando sea necesaria | FK proveedor cascade; categoría y zona sin ON DELETE especial (NO ACTION). Ubicación requerida al final del INSERT, trigger permite omitir y usa centro |
| servicio_contacto | servicio_id,telefono,autorizado | PK=FK a servicio con cascade; teléfono regex, autorización false por defecto; fila opcional |
| servicio_trabajos | id,servicio_id,titulo,creado_en | FK cascade; no tiene descripción, foto_url ni ubicación; título obligatorio sin CHECK de longitud |
| solicitudes_servicio | id,servicio_id,solicitante_id,estado,mensaje,creado_en | FKs cascade; estado default solicitada; mensaje nullable y sin límite SQL; sin actualizado_en, completado_en ni proveedor_id |
| recomendaciones | id,servicio_id,autor_id,puntaje,comentario,creado_en | FKs cascade; UNIQUE(servicio_id,autor_id); smallint entero 1–5; comentario nullable sin límite SQL; no tiene solicitud_id, sello ni promedio |

Todas las columnas `not null` sin default son obligatorias: revisar el DDL literal. Excepciones prácticas: perfiles se crea por el flujo de registro existente; en servicios ubicacion_aprox puede ser completada por trigger. En zonas/categorías no se escribe desde este módulo.

Índices relevantes: GiST idx_servicios_geo(ubicacion_aprox); B-tree idx_perfiles_zona, idx_servicios_zona/proveedor/categoria, idx_trabajos_servicio, idx_solicitudes_solicitante/servicio, idx_recomendaciones_serv/autor. PK y UNIQUE crean sus índices. `uq_solicitud_activa(servicio_id,solicitante_id) WHERE estado IN ('solicitada','contactado')`: se puede volver a solicitar tras completar/cancelar, no mantener dos vivas. No hay índice específico de texto/rating; búsqueda agrega reseñas al consultar.

Triggers: `tg_aproximar BEFORE INSERT OR UPDATE OF ubicacion_aprox` de servicios ejecuta aplicar_aproximacion: centro de zona cuando no se envía ubicación, luego ST_SnapToGrid de 0.0015 grados. No hay trigger de solicitudes/recomendaciones/contacto/trabajos que cree reseñas, cambie confianza, materialice promedios o envíe notificaciones de servicio. `tg_limite` de otros módulos no limita estos INSERT. No hay escritura directa en perfiles desde este módulo.

## Permisos efectivos y RLS

RLS está habilitada en las ocho tablas. SELECT otorgado a authenticated no equivale a todas las filas. Sin perfil, mi_zona() devuelve NULL y no se ven servicios. Los usuarios Supabase Auth anónimos con sesión tienen rol authenticated, distinto del rol PostgreSQL anon sin sesión. No se cambia autenticación ni se usa service_role.

| Tabla | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| zonas, categorias_servicio | anon/authenticated, true | Sin grant/policy | Sin grant/policy | Sin grant/policy |
| perfiles | authenticated: solo id=auth.uid() | Sin permiso directo; registro existente por RPC | Propio, solo avatar_url,telefono,compartir_telefono,tutorial_visto,preferencias | Sin permiso directo |
| servicios | authenticated, zona_id=mi_zona(), incluye inactivos | proveedor_id=auth.uid() y zona_id=mi_zona() | Propietario, solo titulo,descripcion,anios_experiencia,activo | Propietario |
| servicio_contacto | Propietario, o autorizado=true y servicio de mi zona | Propietario del servicio | Propietario, solo telefono,autorizado | Propietario |
| servicio_trabajos | Servicio de mi zona | Propietario | Sin grant/policy | Propietario |
| solicitudes_servicio | Solicitante o proveedor | Solicitante=auth.uid(), estado solicitada, servicio activo, de mi zona y de otro proveedor | Sin grant/policy directo: RPC obligatoria | Sin grant/policy |
| recomendaciones | Servicio de mi zona | Autor actual, servicio de mi zona/otro proveedor y solicitud propia completada | Autor actual, solo puntaje/comentario | Autor actual |

Las subconsultas de políticas a servicios también quedan sujetas a su RLS. La política UPDATE de contacto tiene USING propietario; al no declarar WITH CHECK separado, PostgreSQL usa la condición USING para comprobar la fila nueva; además no hay permiso de cambiar servicio_id. La edición de recomendaciones solo revalida autor, no vuelve a exigir experiencia; identificadores no son editables por grants. Servicios no permite actualizar categoría, proveedor, zona, coordenadas ni fecha por API.

Los INSERT no restringen columnas mediante grants parciales: se permite suministrar id/creado_en y otros campos declarados siempre que satisfagan CHECK/FK/RLS; no hay trigger que normalice fechas de servicios/solicitudes/recomendaciones. La UI debe enviar únicamente campos esperados. El backend limita acceso/experiencia, pero no certifica trabajo real ni identidad externa del vecino.

Funciones: revoke EXECUTE a PUBLIC y anon, grant a authenticated (con excepción explícita de registrar_perfil); 002/003 mantienen esta restricción. RPC SECURITY DEFINER debe evaluarse por su propio cuerpo, no suponer que RLS la protege automáticamente. No debilitar permisos para tests.

## Tablas auxiliares relacionadas

`favoritos` (002:29; instalación:1666) tiene id uuid PK generado, perfil_id uuid obligatorio FK perfiles ON DELETE CASCADE, publicacion_id y servicio_id uuid opcionales FK con cascade, creado_en timestamptz NOT NULL DEFAULT now(), CHECK(num_nonnulls(publicacion_id,servicio_id)=1). Índices únicos parciales uq_fav_publicacion/perfil-publicación y uq_fav_servicio/perfil-servicio; idx_fav_perfil(perfil_id,creado_en DESC). RLS: SELECT y DELETE solo perfil_id=auth.uid(); INSERT exige ese autor y publicación/servicio de mi zona. Grants SELECT/INSERT/DELETE authenticated, sin UPDATE, sin triggers de favoritos. No es requisito del recorrido MVP, no agregar guardados por iniciativa de esta fase.

`storage.buckets`/`storage.objects`: 002 crea buckets públicos avatares y trabajos si existe Storage; políticas SELECT público y escrituras por carpeta del usuario. Trabajos permite INSERT/DELETE, no define política UPDATE equivalente a avatares. No confundir permiso de objeto con FK a servicio; fotos no están modeladas en servicio_trabajos.

`auth.users` es la raíz de identidad, con FK cascade a perfiles; registro/PIN ya implementados y fuera del alcance. `privado.config` y `privado.pin_credenciales` no son accesibles a Flutter. No se documenta ningún secreto ni se propone acceso directo. `notificaciones` y `mensajes` existen, pero no hay trigger de notificaciones de servicio ni conversación de solicitudes en las RPC inspeccionadas: las bandejas no se reemplazan por estos módulos.

## Firmas RPC y comportamiento

Las firmas y cuerpos exactos se reproducen en el anexo. Todos los nombres de parámetros son los que debe enviar `client.rpc`.

| RPC | Autorización / retorno / restricciones |
|---|---|
| `buscar_servicios_cercanos(p_lat double precision, p_lng double precision, p_radio_m int DEFAULT 3000, p_texto text DEFAULT NULL, p_min_estrellas numeric DEFAULT 0)` | RETURNS TABLE exacta en anexo. SQL STABLE SECURITY INVOKER: RLS de servicios/recomendaciones + perfiles públicos de mi zona. Solo activos, ST_DWithin, texto sin tildes/case en título/descripción/categoría, orden distancia ascendente. No p_categoria_id, LIMIT, offset ni búsqueda de nombre proveedor. Coordenadas requeridas sin default, sin validación explícita de rangos ni fallback NULL; validar finitud/rangos/radio positivo en cliente. Resultado sin proveedor_id,categoria_id,zona_id,avatar ni teléfono |
| `resenas_de_servicio(p_servicio uuid)` | TABLE(id uuid,autor text,puntaje smallint,comentario text,creado_en timestamptz). SQL STABLE INVOKER, RLS y join a autores públicos de mi zona, orden fecha descendente. ID ajeno/inexistente puede dar vacío, no implica autorización de escritura |
| `actualizar_solicitud_servicio(p_solicitud uuid,p_estado estado_solicitud)` | RETURNS void; PL/pgSQL SECURITY DEFINER, search_path public, bloqueo FOR UPDATE OF ss. Errores: La solicitud no existe / Transición no permitida / No autorizado. Solo participantes y transiciones de tabla siguiente. Sin defaults; NULL no se valida explícitamente pero NOT NULL de estado impide persistirlo; no enviarlo |
| `mis_solicitudes_recibidas()` | TABLE(id uuid,servicio_id uuid,servicio text,solicitante text,estado estado_solicitud,mensaje text,creado_en timestamptz). STABLE DEFINER, solo s.proveedor_id=auth.uid(), fecha descendente; devuelve nombre público, no solicitante_id |
| `mis_solicitudes_enviadas()` | TABLE(id uuid,servicio_id uuid,servicio text,proveedor text,estado estado_solicitud,puedo_recomendar boolean,creado_en timestamptz). STABLE DEFINER, solicitante actual, fecha descendente; puedo_recomendar = completada AND ausencia de recomendación de ese autor/servicio. No comprueba nuevamente zona/activo; RLS del INSERT sigue siendo autoridad |
| `perfiles_publicos_de_mi_zona()` | TABLE(id uuid,nombre_publico text,avatar_url text,zona_id uuid,vecino_confiable boolean), SQL STABLE DEFINER. Restricción explícita zona=mi_zona(); vecino_confiable deriva de puntaje_confianza>=80 |
| `mi_zona()` | RETURNS uuid, STABLE DEFINER, zona del perfil de auth.uid(); no parámetro |
| `tiene_visto_bueno(n bigint,promedio numeric)` | RETURNS boolean, SQL IMMUTABLE: coalesce(n,0)>=3 AND coalesce(promedio,0)>=4.0; no consulta datos ni otorga permisos |
| `aproximar(g extensions.geography)` | RETURNS extensions.geography, SQL IMMUTABLE; helper ST_SnapToGrid. Aplicación normalmente delega al trigger |
| `puntos_mapa(p_lat double precision,p_lng double precision,p_radio_m int DEFAULT 3000)` | TABLE(capa text,id uuid,titulo text,subtipo text,estado text,urgencia text,lat double precision,lng double precision,distancia_m int). STABLE INVOKER, search_path public,extensions. Une servicios activos como comercio y recursos/alertas/brigadas con sus reglas/RLS; no retorna recomendaciones ni contacto. Su cuerpo literal está en anexo; integración de mapa fuera de la ruta crítica |

`estado_solicitud` enum exacto: solicitada, contactado, completada, cancelada (`001:101`; instalación:118). No existe aceptada, en_progreso ni rechazada para servicios.

| Actor | Desde | Hacia permitido |
|---|---|---|
| Proveedor | solicitada | contactado, completada, cancelada |
| Proveedor | contactado | completada, cancelada |
| Solicitante | solicitada o contactado | cancelada |
| Cualquiera | completada o cancelada | Ninguno |
| Tercero | Cualquier estado | Ninguno |

No hay RPC crear_servicio, crear_solicitud ni crear_recomendacion en los SQL. Las tres inserciones son directas bajo RLS. Tampoco hay RPC de detalle por ID/agregado independiente de radio ni de centro de zona en lat/lng. `publicar_rapido` crea publicaciones del muro y no debe usarse para servicios. `mis_conversaciones` solo modela favores/SOS, no chat de servicios.

## Modelo de recomendaciones y privacidad

RLS controla autor actual, misma zona, no auto-recomendación y existencia de solicitud completada propia. No se almacena enlace a una solicitud específica. UNIQUE(servicio_id,autor_id) rechaza la segunda aunque la solicitud o ID sean distintos: experiencia válida no significa una reseña por cada experiencia. Insertar puntaje 0/6 o fracciones incompatibles con smallint no es válido; Flutter valida entero 1–5.

La búsqueda calcula `round(avg(r.puntaje),1)`, `count(r.id)` y `tiene_visto_bueno(count(r.id),avg(r.puntaje))`. Sin reseñas: promedio NULL, recomendaciones=0 y sello false. Mínimo de estrellas usa avg crudo con coalesce a 0. El detalle debe agregar **todos** los puntajes visibles de ese servicio; no calcular media desde una página de reseñas ni desde media redondeada. La función de reseñas filtra por autores públicos en zona; si existiesen inconsistencias históricas de zona, el listado podría contener menos filas que el agregado sobre recomendaciones. La app no puede modificar zona de perfiles/servicios con grants actuales.

No exponer públicamente: nombre_completo, dni_hash, teléfono de perfil, compartir_telefono, puntaje_confianza numérico, preferencias, consentimientos, rol, secretos de esquema privado, credenciales de Auth. Mostrar solo proyección pública. El mensaje de solicitud es privado entre participantes, no reseña pública. El teléfono de servicio requiere su propio autorizado. Ambos buckets `avatares` y `trabajos` son públicos en 002, con ruta de subida `<auth.uid()>/archivo`; no subir imágenes sensibles. `servicio_trabajos` no tiene URL: Storage no añade esa columna ni vínculo automáticamente. Sin necesidad de fotos en MVP, usar títulos e iconos actuales.

## Ejemplos Dart propuestos (no implementados ni ejecutados)

Se reutiliza el SupabaseClient ya inicializado y su sesión; no crear un nuevo login ni leer config en las pantallas. Los siguientes fragmentos son independientes dentro de métodos futuros con variables de entrada validadas. Aplicar timeout y traducción de fallos en repositorios.

```dart
final categories = await client.from('categorias_servicio')
    .select('id,nombre,icono').order('nombre');
final own = await client.from('perfiles').select('id,zona_id')
    .eq('id', client.auth.currentUser!.id).single();
// Sin GPS: todos los activos de zona, sin inventar distancias.
final zoneServices = await client.from('servicios')
    .select('id,proveedor_id,categoria_id,titulo,descripcion,anios_experiencia,zona_id,activo,creado_en')
    .eq('zona_id', own['zona_id']).eq('activo', true).order('titulo');
final publicProfiles = await client.rpc('perfiles_publicos_de_mi_zona');
final nearby = await client.rpc('buscar_servicios_cercanos', params: {
  'p_lat': latitude, 'p_lng': longitude, 'p_radio_m': radiusMeters,
  'p_texto': query.trim().isEmpty ? null : query.trim(),
  'p_min_estrellas': onlyFourStars ? 4 : 0,
});
```

Categoría exacta: `servicios.categoria_id` en consulta directa; para resultados cercanos, cruzar IDs con la consulta de servicios visible y filtrar por categoria_id, o filtrar respuesta por nombre del catálogo si se verifica equivalencia única exacta. No enviar p_categoria inventado. Búsqueda por proveedor requiere estrategia de zona completa filtrada localmente para conservar el comportamiento actual; no ejecutar primero p_texto para después intentar recuperar proveedores que SQL ya excluyó.

```dart
final service = await client.from('servicios')
    .select('id,proveedor_id,categoria_id,titulo,descripcion,anios_experiencia,zona_id,activo,creado_en')
    .eq('id', serviceId).maybeSingle();
final works = await client.from('servicio_trabajos')
    .select('id,titulo,creado_en').eq('servicio_id', serviceId).order('creado_en');
final reviews = await client.rpc('resenas_de_servicio', params: {'p_servicio': serviceId});
// Todos los puntajes, no solo las reseñas paginadas; revisar límite de filas del servidor.
final scores = await client.from('recomendaciones').select('id,puntaje')
    .eq('servicio_id', serviceId);
final contact = await client.from('servicio_contacto')
    .select('telefono,autorizado').eq('servicio_id', serviceId).maybeSingle();
final sent = await client.rpc('mis_solicitudes_enviadas');
final received = await client.rpc('mis_solicitudes_recibidas');
```

En ficha por ID resolver nombre público cruzando service.proveedor_id con proyección pública; consultas base no pueden hacer join a perfiles privados ajenos. maybeSingle NULL significa inexistente o no visible. No mostrar teléfono si no se recibió fila/consentimiento adecuado para el visitante; no usar perfil como alternativa. Agregación local exige cargar conjunto completo, con paginación técnica si el servidor limita filas; cuando eso deje de ser mínimo, proponer RPC agregada en una tarea SQL independiente.

```dart
final userId = client.auth.currentUser!.id;
await client.from('servicios').insert({
  'id': newServiceId, 'proveedor_id': userId, 'categoria_id': categoryId,
  'titulo': title.trim(), 'descripcion': description,
  'anios_experiencia': yearsExperience, 'zona_id': own['zona_id'],
  // Omitir ubicacion_aprox: el trigger usa centro aproximado de zona.
});
// Paso opcional y separado: no es transacción con el INSERT anterior.
await client.from('servicio_contacto').insert({
  'servicio_id': newServiceId, 'telefono': phone,
  'autorizado': explicitContactConsent,
});
await client.from('solicitudes_servicio').insert({
  'id': newRequestId, 'servicio_id': serviceId,
  'solicitante_id': userId, 'mensaje': message,
  // estado omitido => solicitada.
});
// Ejecutar como proveedor de esa solicitud; nunca UPDATE directo.
await client.rpc('actualizar_solicitud_servicio', params: {
  'p_solicitud': requestId, 'p_estado': 'completada',
});
await client.from('recomendaciones').insert({
  'id': newRecommendationId, 'servicio_id': serviceId,
  'autor_id': userId, 'puntaje': rating, 'comentario': optionalComment,
});
```

Los UUID `new*Id` son entradas generadas una vez por operación futura; no se especifica un paquete nuevo. No aplicar upsert de recomendación para eludir duplicado; diferenciar editar explícitamente de crear. Tras timeout consultar por UUID/UNIQUE antes de repetir y tratar éxito parcial del contacto. Tras recomendar/completar releer enviadas, detalle y directorio. Para errores 23505 informar duplicado; 42501 acceso/experiencia no permitido; 23514 validación; 23503 referencia ya no disponible; P0001 de transición mostrar mensaje de dominio permitido. No presentar details/hint SQL ni payloads/teléfonos/JWT en logs. Sin red no anunciar éxito ni usar OfflineDemoController como cola real.

## Anexo: definiciones literales de referencia

Los bloques siguientes se extraen del archivo 001 (objetos no reemplazados en el orden efectivo). Se incluyen para evitar omisiones de tipos, defaults, retornos y reglas. Las políticas y grants se documentan en la matriz anterior y en los rangos de origen; no se propone ejecutar este anexo.

### public.zonas (001:108)

```sql
create table public.zonas (
  id      uuid primary key default gen_random_uuid(),
  nombre  text not null,
  sector  text,
  centro  extensions.geography(Point, 4326) not null,
  radio_m int  not null default 2000 check (radio_m > 0)
);
```

### public.perfiles (001:119)

```sql
create table public.perfiles (
  id                   uuid primary key references auth.users(id) on delete cascade,
  dni_hash             text not null unique,
  nombre_completo      text not null,                 -- solo lo ve el propio vecino
  nombre_publico       text not null,                 -- "Carlos R." (lo que ven los demás)
  avatar_url           text,
  telefono             text check (telefono ~ '^[0-9+ ]{6,15}$'),
  compartir_telefono   boolean not null default false,
  zona_id              uuid not null references public.zonas(id),
  rol                  rol_usuario not null default 'vecino',
  puntaje_confianza    int not null default 60 check (puntaje_confianza between 0 and 100),
  consentimiento_datos boolean not null check (consentimiento_datos),
  consentimiento_en    timestamptz not null default now(),
  tutorial_visto       boolean not null default false,
  preferencias         jsonb not null default '{}'::jsonb check (pg_column_size(preferencias) < 2048),
  creado_en            timestamptz not null default now()
);
```

### public.categorias_servicio (001:156)

```sql
create table public.categorias_servicio (
  id     serial primary key,
  nombre text not null unique,
  icono  text
);
```

### public.servicios (001:162)

```sql
create table public.servicios (
  id                uuid primary key default gen_random_uuid(),
  proveedor_id      uuid not null references public.perfiles(id) on delete cascade,
  categoria_id      int  not null references public.categorias_servicio(id),
  titulo            text not null check (char_length(titulo) between 3 and 120),
  descripcion       text,
  anios_experiencia smallint check (anios_experiencia between 0 and 80),
  zona_id           uuid not null references public.zonas(id),
  ubicacion_aprox   extensions.geography(Point, 4326) not null,
  activo            boolean not null default true,
  creado_en         timestamptz not null default now()
);
```

### public.servicio_contacto (001:176)

```sql
create table public.servicio_contacto (
  servicio_id uuid primary key references public.servicios(id) on delete cascade,
  telefono    text not null check (telefono ~ '^[0-9+ ]{6,15}$'),
  autorizado  boolean not null default false
);
```

### public.servicio_trabajos (001:183)

```sql
create table public.servicio_trabajos (
  id          uuid primary key default gen_random_uuid(),
  servicio_id uuid not null references public.servicios(id) on delete cascade,
  titulo      text not null,
  creado_en   timestamptz not null default now()
);
```

### public.solicitudes_servicio (001:193)

```sql
create table public.solicitudes_servicio (
  id             uuid primary key default gen_random_uuid(),
  servicio_id    uuid not null references public.servicios(id) on delete cascade,
  solicitante_id uuid not null references public.perfiles(id) on delete cascade,
  estado         estado_solicitud not null default 'solicitada',
  mensaje        text,
  creado_en       timestamptz not null default now()
);
```

### public.recomendaciones (001:203)

```sql
create table public.recomendaciones (
  id          uuid primary key default gen_random_uuid(),
  servicio_id uuid not null references public.servicios(id) on delete cascade,
  autor_id    uuid not null references public.perfiles(id) on delete cascade,
  puntaje     smallint not null check (puntaje between 1 and 5),
  comentario  text,
  creado_en   timestamptz not null default now(),
  unique (servicio_id, autor_id)
);
```

### public.mi_zona (001:432)

```sql
create function public.mi_zona() returns uuid
language sql stable security definer set search_path = public as $$
  select zona_id from public.perfiles where id = auth.uid()
$$;
```

### public.tiene_visto_bueno (001:451)

```sql
create function public.tiene_visto_bueno(n bigint, promedio numeric) returns boolean
language sql immutable as $$
  select coalesce(n, 0) >= 3 and coalesce(promedio, 0) >= 4.0
$$;
```

### public.aproximar (001:457)

```sql
create function public.aproximar(g extensions.geography) returns extensions.geography
language sql immutable set search_path = public, extensions as $$
  select extensions.ST_SnapToGrid(g::extensions.geometry, 0.0015)::extensions.geography
$$;
```

### public.aplicar_aproximacion (001:463)

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

### public.actualizar_solicitud_servicio (001:1046)

```sql
create function public.actualizar_solicitud_servicio(
  p_solicitud uuid, p_estado estado_solicitud)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v   record;
  uid uuid := auth.uid();
begin
  select ss.estado as estado_actual, ss.solicitante_id, s.proveedor_id
    into v
    from public.solicitudes_servicio ss
    join public.servicios s on s.id = ss.servicio_id
   where ss.id = p_solicitud
   for update of ss;
  if not found then raise exception 'La solicitud no existe'; end if;

  if uid = v.proveedor_id then                         -- proveedor
    if not ((p_estado = 'contactado' and v.estado_actual = 'solicitada')
         or (p_estado = 'completada' and v.estado_actual in ('solicitada', 'contactado'))
         or (p_estado = 'cancelada'  and v.estado_actual in ('solicitada', 'contactado'))) then
      raise exception 'Transición no permitida';
    end if;
  elsif uid = v.solicitante_id then                    -- vecino que solicitó
    if not (p_estado = 'cancelada' and v.estado_actual in ('solicitada', 'contactado')) then
      raise exception 'Transición no permitida';
    end if;
  else
    raise exception 'No autorizado';
  end if;

  update public.solicitudes_servicio set estado = p_estado where id = p_solicitud;
end $$;
```

### public.mis_solicitudes_recibidas (001:1080)

```sql
create function public.mis_solicitudes_recibidas()
returns table (id uuid, servicio_id uuid, servicio text, solicitante text,
               estado estado_solicitud, mensaje text, creado_en timestamptz)
language sql stable security definer set search_path = public as $$
  select ss.id, s.id, s.titulo, pe.nombre_publico, ss.estado, ss.mensaje, ss.creado_en
    from public.solicitudes_servicio ss
    join public.servicios s  on s.id  = ss.servicio_id
    join public.perfiles  pe on pe.id = ss.solicitante_id
   where s.proveedor_id = auth.uid()
   order by ss.creado_en desc
$$;
```

### public.mis_solicitudes_enviadas (001:1093)

```sql
create function public.mis_solicitudes_enviadas()
returns table (id uuid, servicio_id uuid, servicio text, proveedor text,
               estado estado_solicitud, puedo_recomendar boolean, creado_en timestamptz)
language sql stable security definer set search_path = public as $$
  select ss.id, s.id, s.titulo, pe.nombre_publico, ss.estado,
         (ss.estado = 'completada'
          and not exists (select 1 from public.recomendaciones r
                           where r.servicio_id = s.id and r.autor_id = auth.uid())),
         ss.creado_en
    from public.solicitudes_servicio ss
    join public.servicios s  on s.id  = ss.servicio_id
    join public.perfiles  pe on pe.id = s.proveedor_id
   where ss.solicitante_id = auth.uid()
   order by ss.creado_en desc
$$;
```

### public.perfiles_publicos_de_mi_zona (001:1110)

```sql
create function public.perfiles_publicos_de_mi_zona()
returns table (id uuid, nombre_publico text, avatar_url text, zona_id uuid, vecino_confiable boolean)
language sql stable security definer set search_path = public as $$
  select p.id, p.nombre_publico, p.avatar_url, p.zona_id, (p.puntaje_confianza >= 80)
    from public.perfiles p
   where p.zona_id = public.mi_zona()
$$;
```

### public.buscar_servicios_cercanos (001:1120)

```sql
create function public.buscar_servicios_cercanos(
  p_lat double precision, p_lng double precision,
  p_radio_m int default 3000, p_texto text default null, p_min_estrellas numeric default 0)
returns table (id uuid, titulo text, categoria text, descripcion text, proveedor text,
               anios_experiencia smallint, distancia_m int, promedio numeric,
               recomendaciones bigint, visto_bueno boolean, lat double precision, lng double precision)
language sql stable set search_path = public, extensions as $$
  with origen as (select ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography as g),
       filtro as (select extensions.unaccent(lower(btrim(coalesce(p_texto, '')))) as txt)
  select s.id, s.titulo, c.nombre, s.descripcion, pp.nombre_publico, s.anios_experiencia,
         round(ST_Distance(s.ubicacion_aprox, o.g))::int,
         round(avg(r.puntaje), 1),
         count(r.id),
         public.tiene_visto_bueno(count(r.id), avg(r.puntaje)),
         ST_Y(s.ubicacion_aprox::geometry), ST_X(s.ubicacion_aprox::geometry)
    from origen o
    cross join filtro f
    cross join public.servicios s
    join public.categorias_servicio c on c.id = s.categoria_id
    join public.perfiles_publicos_de_mi_zona() pp on pp.id = s.proveedor_id
    left join public.recomendaciones r on r.servicio_id = s.id
   where s.activo
     and ST_DWithin(s.ubicacion_aprox, o.g, p_radio_m)
     and (f.txt = ''
          or extensions.unaccent(lower(s.titulo))      like '%' || f.txt || '%'
          or extensions.unaccent(lower(s.descripcion)) like '%' || f.txt || '%'
          or extensions.unaccent(lower(c.nombre))      like '%' || f.txt || '%')
   group by s.id, c.nombre, pp.nombre_publico, o.g
  having coalesce(avg(r.puntaje), 0) >= p_min_estrellas
   order by 7
$$;
```

### public.resenas_de_servicio (001:1153)

```sql
create function public.resenas_de_servicio(p_servicio uuid)
returns table (id uuid, autor text, puntaje smallint, comentario text, creado_en timestamptz)
language sql stable set search_path = public as $$
  select r.id, pp.nombre_publico, r.puntaje, r.comentario, r.creado_en
    from public.recomendaciones r
    join public.perfiles_publicos_de_mi_zona() pp on pp.id = r.autor_id
   where r.servicio_id = p_servicio
   order by r.creado_en desc
$$;
```

### public.puntos_mapa (001:1271)

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
