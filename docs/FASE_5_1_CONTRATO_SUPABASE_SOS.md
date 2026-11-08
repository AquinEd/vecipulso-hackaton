# Fase 5.1 — Contrato Supabase de Modo SOS

Auditoría estática del repositorio, 2026-11-08. Las definiciones aquí descritas son las versionadas. El despliegue remoto queda pendiente de contrastar mediante lectura de catálogo.

## Orden efectivo

El instalador docs/database/INSTALACION_UNICA_VECIPULSO_MVP.sql declara base 001 → complemento 002 → correcciones 003 → semilla 004, dentro de una transacción. Es una alternativa a ejecutar los scripts separados. VERIFICAR_INSTALACION.sql comprueba tablas, extensiones, RLS y EXECUTE. La semilla 004 aporta zona, categorías, contactos y grupos ficticios, sin alertas ni voluntarios reales. Los números históricos dentro de comentarios no cambian el orden de los archivos.

002 elimina UNIQUE(alerta_id,voluntario_id) de sos_respuestas y lo sustituye por uq_sos_resp_activa con estado <> cancelada. 003 reemplaza emitir_alerta y actualizar_ayuda, corrige sos_conf_crear, crea uq_ayuda_sos_seleccionada_mvp y revoca INSERT/DELETE de grupo_miembros. Cerrar/cancelar alerta y las RPC de consulta conservan su cuerpo de 001. En el anexo se presenta la última definición de cada función y su procedencia con línea.

## Operaciones y RLS efectivas

| Tabla | Lectura | Creación | Actualización | Borrado |
|---|---|---|---|---|
| zonas | anon y authenticated, catálogo completo | Sin permiso cliente | Sin permiso cliente | Sin permiso cliente |
| perfiles | Solo propio. Ajeno por perfiles_publicos_de_mi_zona | Registro existente por RPC | Propio, columnas avatar_url,telefono,compartir_telefono,tutorial_visto,preferencias | Sin DELETE directo |
| alertas_sos | Mi zona, incluidos cerrados | emitir_alerta, sin INSERT directo | cerrar_alerta, cancelar_alerta, actualizar_ayuda y triggers, sin UPDATE directo | Sin DELETE directo |
| sos_respuestas | Voluntario, autor de alerta o admin | UID voluntario actual, estado ofrecida, alerta activa de otro vecino y de mi zona. Recurso opcional propio | Solo actualizar_ayuda | Sin DELETE directo |
| recursos_criticos | Mi zona, también no disponibles | UID propietario y zona propia | Propietario o admin de mi zona, solo cantidad,descripcion,disponible | Propietario |
| grupos_apoyo | Mi zona, contacto incluido | Sin permiso | Sin permiso | Sin permiso |
| grupo_miembros | Propio o grupo de mi zona | Revocado por 003 | Sin permiso | Revocado por 003 |
| sos_confirmaciones | Solo propia, conteo por confirmaciones_de | UID actual, alerta activa de otro vecino de mi zona tras 003 | Sin permiso | Sin permiso |
| vecinos_vulnerables | Propio o admin de mi zona | Propio, zona y consentimiento=true | Sin permiso | Propio |
| mensajes | Participantes de respuesta o ayuda | Autor actual y participante, texto 1–1000 | Solo leido_en como destinatario; preferir marcar_conversacion_leida | Sin permiso |
| notificaciones | Propias | Interna mediante trigger | Propias, solo leida | Sin permiso directo |
| eventos_confianza | Propio o admin | Interna | Sin permiso | Sin permiso |
| auditoria_sos | Admin | Interna | Sin permiso | Sin permiso |
| contactos_utiles | anon y authenticated | Sin permiso | Sin permiso | Sin permiso |

Todas estas tablas tienen RLS habilitada. Los grants y políticas deben evaluarse conjuntamente. anon significa ausencia de sesión API. Una sesión Supabase de inicio anónimo usa authenticated y puede invocar RPC otorgadas a ese rol incluso antes de registrar perfil. El PIN es un bloqueo de interfaz. SECURITY DEFINER depende de sus comprobaciones internas y puede omitir RLS. Los EXECUTE se revocan a PUBLIC y anon, se conceden a authenticated salvo registrar_perfil. No usar credenciales administrativas en Flutter.

## Estados y autorización

Alertas abiertas son sin_verificar y verificada. Los cierres son atendida, falsa_alarma, sin_confirmar y cancelada. El CHECK exige cerrado_en nulo exactamente en estados abiertos. Clase alerta admite sismo,incendio,seguridad,salud,dano_vivienda,otro. Clase soporte admite persona_atrapada,salud,agua_alimentos,traslado_refugio,otro. Urgencia es critica,urgente,normal. La UI debe presentar verificada como «Confirmada por vecinos», conforme al COMMENT del enum.

| Actor de ayuda | Estado inicial | Destino permitido |
|---|---|---|
| Autor de alerta | ofrecida | aceptada o cancelada |
| Autor de alerta | aceptada o en_camino | completada o cancelada |
| Voluntario | aceptada | en_camino, completada o cancelada |
| Voluntario | ofrecida | cancelada |
| Voluntario | en_camino | completada o cancelada |

Los estados terminales no se reabren. actualizar_ayuda exige sesión y estado no nulo, bloquea primero alerta y después respuesta y exige alerta abierta. Solo una respuesta puede estar aceptada/en_camino por alerta. Completar marca atendida y cancela otras ofertas activas. Cancelar una respuesta individual conserva las otras. cancelar_alerta solo permite al autor cancelar su alerta abierta y cancela las ayudas activas asociadas. cerrar_alerta pretende permitir solo admin o voluntario aceptado/en_camino/completado, excluye al autor incluso si fuera admin y cancela las ayudas activas. Ver el riesgo de NULL en la auditoría.

emitir_alerta devuelve el UUID persistido. Reenviar el mismo UUID con el mismo autor devuelve el existente, sin comparar el contenido. Otro autor obtiene Identificador en uso. Exige perfil/zona, valida pares de coordenadas y rangos, limita creado_local al presente y el trigger lo acota a 30 días. Si no hay coordenadas o están fuera de dos radios de zona, el trigger utiliza el centro. La confirmación en Flutter debe esperar la RPC y reconsultar estado/UUID después de una respuesta perdida.

## Índices y triggers

Los índices relevantes y los triggers se reproducen en el anexo. GiST cubre ubicaciones de alertas, recursos, grupos y vecinos vulnerables. B-tree cubre zona/estado/fecha de alertas, autor/fecha, propietario/disponibilidad de recursos y voluntario/recurso de respuestas.

tg_preparar_alerta bloquea el perfil del autor, permite como máximo tres alertas por hora y asigna verificada si nivel_de(puntaje)=confiable (>=80). El valor inicial de confianza es 60. Tres confirmaciones comunitarias elevan una sin_verificar a verificada mediante bloqueo de alerta. tg_confianza suma 5 por atendida o resta 20 por falsa_alarma, acotando el perfil a 0–100 y registrando evento. tg_auditoria registra creación y cambios de estado. tg_notif_ayuda y tg_notif_estado_ayuda generan notificaciones internas. Mensajes tienen su trigger de notificación.

tg_aproximar usa ST_SnapToGrid de 0.0015 grados, aproximadamente 166 m, y centro de zona si existe zona_id y falta punto. Respuestas carece de zona_id y su punto puede seguir NULL. tg_sanear_creado procesa creado_local. recursos_criticos tiene tg_limite de 30 inserciones por hora. Las políticas no hacen una validación de distancia al centro para INSERT directo de recursos.

Realtime publica alertas_sos,sos_respuestas,recursos_criticos,notificaciones y mensajes, junto con tablas de favores. 002 añade comentarios. Grupos y confirmaciones no se añaden a esa publicación. No hay push por el solo hecho de insertar una notificación. privado.limpiar_datos puede eliminar alertas cerradas con más de 90 días y notificaciones leídas de más de 30 días si se programa pg_cron.

## Consultas sin GPS

alertas_cercanas requiere lat/lng y por defecto 5000 m, solo alertas abiertas creadas en 24 h, orden por urgencia y distancia. No incorpora fallback de coordenadas. resumen_emergencia no requiere GPS y resume la zona de perfil y las últimas 24 h. SELECT de alertas_sos bajo RLS permite listar por zona/fecha/estado sin metros. Para emitir, omitir ambas coordenadas sí está soportado. sugerir_coincidencias usa el punto de una alerta propia y recursos compatibles a 3000 m por defecto. puntos_mapa exige origen y retorna puntos aproximados, sin rutas viales.

## Hallazgos que condicionan la integración

- Crítico en cerrar_alerta. mi_rol() devuelve NULL para sesión sin perfil. IF NOT(NULL OR false) no ejecuta el rechazo, permitiendo alcanzar el UPDATE SECURITY DEFINER de una alerta ajena si se conoce su UUID. Es una deducción del cuerpo SQL, no una explotación remota ejecutada.
- Medio en confirmaciones_de. La función DEFINER cuenta por UUID sin verificar sesión de perfil, zona o visibilidad de la alerta. authenticated dispone de EXECUTE. Puede revelar un conteo de otra zona.
- Medio en recursos/ayudas. Un recurso propio puede asociarse a varias ayudas y no se consume ni reserva cantidad al aceptar o completar. La política no exige disponible=true para recurso_id. Hay exclusión por alerta, no por recurso.
- Medio de disponibilidad. Los cierres actualizan la alerta antes de sus respuestas, compatible con el orden principal del parche. Los INSERT de confirmaciones/ayudas disparan triggers que también bloquean/escriben alertas y perfiles. Hace falta prueba transaccional de carreras y reintentos, no inferir ausencia global de bloqueos a partir de una única RPC.

## Anexo literal de contrato

Los cuerpos siguientes se copian de los SQL de referencia y se contrastan con su aparición en el instalador. Sirven para inspección. Incluyen tipos, defaults, PK/FK/CHECK, firmas, resultados, errores y autorización.


### zonas

Procedencia: docs/database/001_esquema_base_v5.sql:108

```sql
create table public.zonas (
  id      uuid primary key default gen_random_uuid(),
  nombre  text not null,
  sector  text,
  centro  extensions.geography(Point, 4326) not null,
  radio_m int  not null default 2000 check (radio_m > 0)
);
```


### perfiles

Procedencia: docs/database/001_esquema_base_v5.sql:119

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


### alertas_sos

Procedencia: docs/database/001_esquema_base_v5.sql:242

```sql
create table public.alertas_sos (
  id              uuid primary key default gen_random_uuid(),
  autor_id        uuid not null references public.perfiles(id) on delete cascade,
  clase           clase_alerta    not null default 'alerta',
  tipo            tipo_emergencia not null,
  urgencia        urgencia_alerta not null default 'urgente',
  descripcion     text,
  zona_id         uuid not null references public.zonas(id),
  ubicacion_aprox extensions.geography(Point, 4326) not null,
  estado          estado_alerta not null default 'sin_verificar',
  creado_local    timestamptz,
  creado_en       timestamptz not null default now(),
  cerrado_en      timestamptz,
  check ((estado in ('sin_verificar', 'verificada')) = (cerrado_en is null)),
  check ((clase = 'alerta'  and tipo in ('sismo', 'incendio', 'seguridad', 'salud', 'dano_vivienda', 'otro'))
      or (clase = 'soporte' and tipo in ('persona_atrapada', 'salud', 'agua_alimentos', 'traslado_refugio', 'otro')))
);
```


### sos_respuestas

Procedencia: docs/database/001_esquema_base_v5.sql:275

```sql
create table public.sos_respuestas (
  id              uuid primary key default gen_random_uuid(),
  alerta_id       uuid not null references public.alertas_sos(id) on delete cascade,
  voluntario_id   uuid not null references public.perfiles(id) on delete cascade,
  recurso_id      uuid references public.recursos_criticos(id) on delete set null,
  estado          estado_ayuda not null default 'ofrecida',
  mensaje         text,
  ubicacion_aprox extensions.geography(Point, 4326),   -- origen de la "ruta orientativa"
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),
  unique (alerta_id, voluntario_id)
);
```


### recursos_criticos

Procedencia: docs/database/001_esquema_base_v5.sql:261

```sql
create table public.recursos_criticos (
  id              uuid primary key default gen_random_uuid(),
  zona_id         uuid not null references public.zonas(id),
  propietario_id  uuid not null references public.perfiles(id) on delete cascade,
  tipo            tipo_recurso not null,
  cantidad        int not null default 1 check (cantidad > 0),
  descripcion     text,
  ubicacion_aprox extensions.geography(Point, 4326),
  disponible      boolean not null default true,
  creado_local    timestamptz,
  creado_en       timestamptz not null default now()
);
```


### grupos_apoyo

Procedencia: docs/database/001_esquema_base_v5.sql:308

```sql
create table public.grupos_apoyo (
  id              uuid primary key default gen_random_uuid(),
  zona_id         uuid not null references public.zonas(id),
  nombre          text not null,
  tipo            tipo_grupo not null,
  especialidad    text,
  sector          text,
  integrantes     int check (integrantes >= 0),
  contacto        text,
  ubicacion_aprox extensions.geography(Point, 4326)
);
```


### grupo_miembros

Procedencia: docs/database/002_complemento_v5.sql:48

```sql
create table public.grupo_miembros (
  grupo_id  uuid not null references public.grupos_apoyo(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id)     on delete cascade,
  rol       text not null default 'integrante' check (rol in ('integrante', 'lider')),
  estado    text not null default 'activo'     check (estado in ('activo', 'inactivo')),
  creado_en timestamptz not null default now(),
  primary key (grupo_id, perfil_id)
);
```


### sos_confirmaciones

Procedencia: docs/database/001_esquema_base_v5.sql:300

```sql
create table public.sos_confirmaciones (
  alerta_id uuid not null references public.alertas_sos(id) on delete cascade,
  vecino_id uuid not null references public.perfiles(id) on delete cascade,
  creado_en timestamptz not null default now(),
  primary key (alerta_id, vecino_id)
);
```


### vecinos_vulnerables

Procedencia: docs/database/001_esquema_base_v5.sql:321

```sql
create table public.vecinos_vulnerables (
  id              uuid primary key default gen_random_uuid(),
  vecino_id       uuid not null unique references public.perfiles(id) on delete cascade,
  zona_id         uuid not null references public.zonas(id),
  necesidad       text,
  ubicacion_aprox extensions.geography(Point, 4326),
  consentimiento  boolean not null check (consentimiento),
  creado_en       timestamptz not null default now()
);
```


### mensajes

Procedencia: docs/database/001_esquema_base_v5.sql:289

```sql
create table public.mensajes (
  id           uuid primary key default gen_random_uuid(),
  respuesta_id uuid references public.respuestas(id)     on delete cascade,
  ayuda_id     uuid references public.sos_respuestas(id) on delete cascade,
  autor_id     uuid not null references public.perfiles(id) on delete cascade,
  texto        text not null check (char_length(texto) between 1 and 1000),
  creado_en    timestamptz not null default now(),
  check (num_nonnulls(respuesta_id, ayuda_id) = 1)
);
```


### eventos_confianza

Procedencia: docs/database/001_esquema_base_v5.sql:331

```sql
create table public.eventos_confianza (
  id        uuid primary key default gen_random_uuid(),
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  alerta_id uuid references public.alertas_sos(id) on delete set null,
  delta     int not null,
  motivo    text,
  creado_en timestamptz not null default now()
);
```


### notificaciones

Procedencia: docs/database/001_esquema_base_v5.sql:341

```sql
create table public.notificaciones (
  id        uuid primary key default gen_random_uuid(),
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  tipo      text not null,
  titulo    text not null,
  ref_tabla text,
  ref_id    uuid,
  leida     boolean not null default false,
  creado_en timestamptz not null default now()
);
```


### auditoria_sos

Procedencia: docs/database/001_esquema_base_v5.sql:353

```sql
create table public.auditoria_sos (
  id        uuid primary key default gen_random_uuid(),
  alerta_id uuid not null,
  actor_id  uuid,
  accion    text not null,
  creado_en timestamptz not null default now()
);
```


### contactos_utiles

Procedencia: docs/database/001_esquema_base_v5.sql:362

```sql
create table public.contactos_utiles (
  id       serial primary key,
  nombre   text not null,
  telefono text not null,
  tipo     text not null default 'oficial',
  orden    int  not null default 0
);
```


### emitir_alerta

Procedencia: docs/database/003_correcciones_mvp.sql:167

```sql
create or replace function public.emitir_alerta(
  p_id uuid, p_clase clase_alerta, p_tipo tipo_emergencia, p_urgencia urgencia_alerta,
  p_descripcion text default null,
  p_lat double precision default null, p_lng double precision default null,
  p_creado_local timestamptz default null)
returns uuid
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_uid    uuid := auth.uid();
  v_zona   uuid := public.mi_zona();
  v_pt     extensions.geography;
  v_creado timestamptz := least(coalesce(p_creado_local, now()), now());
begin
  if v_uid is null or v_zona is null then raise exception 'Perfil incompleto'; end if;

  if (p_lat is null) <> (p_lng is null) then
    raise exception 'Latitud y longitud deben enviarse juntas';
  end if;
  if p_lat is not null and (not (p_lat between -90 and 90)
      or not (p_lng between -180 and 180)
) then
    raise exception 'Coordenadas invalidas';
  end if;

  if exists (select 1 from public.alertas_sos where id = p_id) then
    if exists (select 1 from public.alertas_sos where id = p_id and autor_id = v_uid) then
      return p_id;
    end if;
    raise exception 'Identificador en uso';
  end if;
  if p_lat is not null and p_lng is not null then
    v_pt := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;
    if not exists (select 1 from public.zonas z where z.id = v_zona and ST_DWithin(z.centro, v_pt, z.radio_m * 2)) then
      v_pt := null;
    end if;
  end if;
  insert into public.alertas_sos (id, autor_id, clase, tipo, urgencia, descripcion, zona_id, ubicacion_aprox, creado_local)
  values (p_id, v_uid, p_clase, p_tipo, p_urgencia, p_descripcion, v_zona, v_pt, v_creado);
  return p_id;
end $$;
```


### actualizar_ayuda

Procedencia: docs/database/003_correcciones_mvp.sql:31

```sql
create or replace function public.actualizar_ayuda(p_resp uuid, p_estado public.estado_ayuda)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v record;
  v_alerta_estado public.estado_alerta;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Se requiere una sesion'; end if;
  if p_estado is null then raise exception 'Estado obligatorio'; end if;

  -- Primero bloquea la ALERTA (mismo orden para todas las RPC de ayuda).
  select a.estado into v_alerta_estado
  from public.alertas_sos a
  join public.sos_respuestas s on s.alerta_id = a.id
  where s.id = p_resp
  for update of a;
  if not found then raise exception 'La ayuda no existe'; end if;
  if v_alerta_estado not in ('sin_verificar','verificada') then
    raise exception 'La alerta ya fue cerrada';
  end if;

  select s.estado, s.voluntario_id, s.alerta_id, a.autor_id as autor
  into v
  from public.sos_respuestas s
  join public.alertas_sos a on a.id = s.alerta_id
  where s.id = p_resp
  for update of s;
  if not found then raise exception 'La ayuda no existe'; end if;

  if v_uid = v.autor then
    if not ((p_estado = 'aceptada' and v.estado = 'ofrecida')
      or (p_estado = 'completada' and v.estado in ('aceptada','en_camino'))
      or (p_estado = 'cancelada' and v.estado in ('ofrecida','aceptada','en_camino'))) then
      raise exception 'Transicion no permitida para el solicitante';
    end if;
  elsif v_uid = v.voluntario_id then
    if not ((p_estado = 'en_camino' and v.estado = 'aceptada')
      or (p_estado = 'completada' and v.estado in ('aceptada','en_camino'))
      or (p_estado = 'cancelada' and v.estado in ('ofrecida','aceptada','en_camino'))) then
      raise exception 'Transicion no permitida para el voluntario';
    end if;
  else
    raise exception 'No autorizado';
  end if;

  if p_estado = 'aceptada' and exists (
    select 1 from public.sos_respuestas x
    where x.alerta_id = v.alerta_id and x.id <> p_resp
      and x.estado in ('aceptada', 'en_camino')
  ) then
    raise exception 'Ya existe un voluntario aceptado para esta alerta';
  end if;

  update public.sos_respuestas
    set estado = p_estado, actualizado_en = now()
    where id = p_resp;

  -- Retirarse/cancelar UNA oferta NO cancela ofertas de otros voluntarios.
  if p_estado = 'completada' then
    update public.sos_respuestas
       set estado = 'cancelada', actualizado_en = now()
     where alerta_id = v.alerta_id and id <> p_resp
       and estado in ('ofrecida','aceptada','en_camino');
    update public.alertas_sos
       set estado = 'atendida', cerrado_en = now()
     where id = v.alerta_id and estado in ('sin_verificar','verificada');
  end if;
end $$;
```


### cerrar_alerta

Procedencia: docs/database/001_esquema_base_v5.sql:961

```sql
create function public.cerrar_alerta(p_alerta uuid, p_resultado estado_alerta) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_resultado not in ('atendida', 'falsa_alarma', 'sin_confirmar') then
    raise exception 'Resultado no válido';
  end if;
  if exists (select 1 from public.alertas_sos where id = p_alerta and autor_id = auth.uid()) then
    raise exception 'El autor no puede cerrar su propia alerta';
  end if;
  if not (public.mi_rol() = 'admin'
          or exists (select 1 from public.sos_respuestas
                      where alerta_id = p_alerta
                        and voluntario_id = auth.uid()
                        and estado in ('aceptada', 'en_camino', 'completada'))) then
    raise exception 'No autorizado: solo el admin o quien ofrecio la ayuda aceptada puede cerrarla';
  end if;
  update public.alertas_sos
     set estado = p_resultado, cerrado_en = now()
   where id = p_alerta and estado in ('sin_verificar', 'verificada');
  if not found then raise exception 'La alerta no existe o ya está cerrada'; end if;

  -- No dejar ayudas colgadas sobre una alerta cerrada
  update public.sos_respuestas set estado = 'cancelada', actualizado_en = now()
   where alerta_id = p_alerta and estado in ('ofrecida', 'aceptada', 'en_camino');
end $$;
```


### cancelar_alerta

Procedencia: docs/database/001_esquema_base_v5.sql:988

```sql
create function public.cancelar_alerta(p_alerta uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.alertas_sos
     set estado = 'cancelada', cerrado_en = now()
   where id = p_alerta and autor_id = auth.uid() and estado in ('sin_verificar', 'verificada');
  if not found then raise exception 'No puedes cancelar esta alerta'; end if;
  update public.sos_respuestas set estado = 'cancelada', actualizado_en = now()
   where alerta_id = p_alerta and estado in ('ofrecida', 'aceptada', 'en_camino');
end $$;
```


### alertas_cercanas

Procedencia: docs/database/001_esquema_base_v5.sql:1193

```sql
create function public.alertas_cercanas(
  p_lat double precision, p_lng double precision, p_radio_m int default 5000)
returns table (id uuid, clase clase_alerta, tipo tipo_emergencia, urgencia urgencia_alerta,
               estado estado_alerta, descripcion text, verificada boolean, es_mia boolean,
               distancia_m int, lat double precision, lng double precision, creado_en timestamptz)
language sql stable set search_path = public, extensions as $$
  with origen as (select ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography as g)
  select a.id, a.clase, a.tipo, a.urgencia, a.estado, a.descripcion,
         (a.estado = 'verificada'), (a.autor_id = auth.uid()),
         round(ST_Distance(a.ubicacion_aprox, o.g))::int,
         ST_Y(a.ubicacion_aprox::geometry), ST_X(a.ubicacion_aprox::geometry),
         a.creado_en
    from origen o
    cross join public.alertas_sos a
   where a.estado in ('sin_verificar', 'verificada')
     and a.creado_en > now() - interval '24 hours'
     and ST_DWithin(a.ubicacion_aprox, o.g, p_radio_m)
   order by case a.urgencia when 'critica' then 0 when 'urgente' then 1 else 2 end, 9
$$;
```


### resumen_emergencia

Procedencia: docs/database/001_esquema_base_v5.sql:1214

```sql
create function public.resumen_emergencia()
returns table (zona text, en_riesgo boolean, reportes_activos bigint, actualizado_en timestamptz)
language sql stable security definer set search_path = public as $$
  select z.nombre,
         exists (select 1 from public.alertas_sos a
                  where a.zona_id = z.id and a.estado = 'verificada' and a.urgencia = 'critica'
                    and a.creado_en > now() - interval '24 hours'),
         (select count(*) from public.alertas_sos a
           where a.zona_id = z.id and a.estado in ('sin_verificar', 'verificada')
             and a.creado_en > now() - interval '24 hours'),
         now()
    from public.zonas z
   where z.id = public.mi_zona()
$$;
```


### sugerir_coincidencias

Procedencia: docs/database/001_esquema_base_v5.sql:1230

```sql
create function public.sugerir_coincidencias(p_alerta uuid, p_radio_m int default 3000)
returns table (recurso_id uuid, tipo tipo_recurso, cantidad int, descripcion text,
               ofrece text, distancia_m int, lat double precision, lng double precision)
language sql stable security definer set search_path = public, extensions as $$
  select r.id, r.tipo, r.cantidad, r.descripcion, pe.nombre_publico,
         round(ST_Distance(r.ubicacion_aprox, a.ubicacion_aprox))::int,
         ST_Y(r.ubicacion_aprox::geometry), ST_X(r.ubicacion_aprox::geometry)
    from public.alertas_sos a
    join public.recursos_criticos r on r.zona_id = a.zona_id and r.disponible
                                    and r.propietario_id <> a.autor_id
    join public.perfiles pe on pe.id = r.propietario_id
   where a.id = p_alerta
     and a.autor_id = auth.uid()
     and a.estado in ('sin_verificar', 'verificada')
     and r.tipo = any (public.recursos_para(a.tipo))
     and ST_DWithin(r.ubicacion_aprox, a.ubicacion_aprox, p_radio_m)
   order by 6
$$;
```


### contraparte_ayuda

Procedencia: docs/database/001_esquema_base_v5.sql:1250

```sql
create function public.contraparte_ayuda(p_resp uuid)
returns table (nombre text, avatar_url text, soy_solicitante boolean, estado estado_ayuda,
               ayudas_completadas bigint, distancia_m int, lat double precision, lng double precision,
               telefono text)
language sql stable security definer set search_path = public, extensions as $$
  select pe.nombre_publico, pe.avatar_url, (a.autor_id = auth.uid()), s.estado,
         (select count(*) from public.sos_respuestas x
           where x.voluntario_id = pe.id and x.estado = 'completada'),
         round(ST_Distance(a.ubicacion_aprox, coalesce(s.ubicacion_aprox, a.ubicacion_aprox)))::int,
         ST_Y(case when a.autor_id = auth.uid() then s.ubicacion_aprox else a.ubicacion_aprox end::geometry),
         ST_X(case when a.autor_id = auth.uid() then s.ubicacion_aprox else a.ubicacion_aprox end::geometry),
         case when pe.compartir_telefono and s.estado in ('aceptada', 'en_camino') then pe.telefono end
    from public.sos_respuestas s
    join public.alertas_sos a on a.id = s.alerta_id
    join public.perfiles pe on pe.id = case when a.autor_id = auth.uid() then s.voluntario_id else a.autor_id end
   where s.id = p_resp
     and (s.voluntario_id = auth.uid() or a.autor_id = auth.uid())
$$;
```


### confirmaciones_de

Procedencia: docs/database/001_esquema_base_v5.sql:1331

```sql
create function public.confirmaciones_de(p_alerta uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select count(*) from public.sos_confirmaciones where alerta_id = p_alerta
$$;
```


### perfiles_publicos_de_mi_zona

Procedencia: docs/database/001_esquema_base_v5.sql:1110

```sql
create function public.perfiles_publicos_de_mi_zona()
returns table (id uuid, nombre_publico text, avatar_url text, zona_id uuid, vecino_confiable boolean)
language sql stable security definer set search_path = public as $$
  select p.id, p.nombre_publico, p.avatar_url, p.zona_id, (p.puntaje_confianza >= 80)
    from public.perfiles p
   where p.zona_id = public.mi_zona()
$$;
```


### mi_zona

Procedencia: docs/database/001_esquema_base_v5.sql:432

```sql
create function public.mi_zona() returns uuid
language sql stable security definer set search_path = public as $$
  select zona_id from public.perfiles where id = auth.uid()
$$;
```


### mi_rol

Procedencia: docs/database/001_esquema_base_v5.sql:437

```sql
create function public.mi_rol() returns rol_usuario
language sql stable security definer set search_path = public as $$
  select rol from public.perfiles where id = auth.uid()
$$;
```


### recursos_para

Procedencia: docs/database/001_esquema_base_v5.sql:509

```sql
create function public.recursos_para(p_tipo tipo_emergencia) returns tipo_recurso[]
language sql immutable as $$
  select case p_tipo
    when 'persona_atrapada' then array['herramientas', 'botiquin']::tipo_recurso[]
    when 'salud'            then array['botiquin']::tipo_recurso[]
    when 'agua_alimentos'   then array['agua']::tipo_recurso[]
    when 'traslado_refugio' then array['transporte', 'espacio_seguro']::tipo_recurso[]
    when 'incendio'         then array['herramientas']::tipo_recurso[]
    else array[]::tipo_recurso[] end
$$;
```


### participa_ayuda

Procedencia: docs/database/001_esquema_base_v5.sql:501

```sql
create function public.participa_ayuda(p_resp uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.sos_respuestas s
                   join public.alertas_sos a on a.id = s.alerta_id
                  where s.id = p_resp and (s.voluntario_id = auth.uid() or a.autor_id = auth.uid()))
$$;
```


### aproximar

Procedencia: docs/database/001_esquema_base_v5.sql:457

```sql
create function public.aproximar(g extensions.geography) returns extensions.geography
language sql immutable set search_path = public, extensions as $$
  select extensions.ST_SnapToGrid(g::extensions.geometry, 0.0015)::extensions.geography
$$;
```


### aplicar_aproximacion

Procedencia: docs/database/001_esquema_base_v5.sql:463

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


### sanear_creado_local

Procedencia: docs/database/001_esquema_base_v5.sql:480

```sql
create function public.sanear_creado_local() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.creado_local is not null then
    new.creado_local := least(new.creado_local, now());
    if new.creado_local < now() - interval '30 days' then
      new.creado_local := now();
    end if;
  end if;
  return new;
end $$;
```


### preparar_alerta

Procedencia: docs/database/001_esquema_base_v5.sql:595

```sql
create function public.preparar_alerta() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_puntaje   int;
  v_recientes int;
begin
  -- Serializa las alertas del mismo autor para que el límite no se pueda saltar
  -- con dos inserts simultáneos.
  perform 1 from public.perfiles where id = new.autor_id for update;

  select puntaje_confianza into v_puntaje from public.perfiles where id = new.autor_id;
  if v_puntaje is null then
    raise exception 'Perfil no encontrado';
  end if;

  select count(*) into v_recientes from public.alertas_sos
   where autor_id = new.autor_id and creado_en > now() - interval '1 hour';
  if v_recientes >= 3 then
    raise exception 'Límite de alertas por hora alcanzado';
  end if;

  new.estado := case when public.nivel_de(v_puntaje) = 'confiable'
                     then 'verificada'::estado_alerta
                     else 'sin_verificar'::estado_alerta end;
  new.cerrado_en := null;
  return new;
end $$;
```


### revisar_confirmaciones

Procedencia: docs/database/001_esquema_base_v5.sql:628

```sql
create function public.revisar_confirmaciones() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- Evita la carrera de tres confirmaciones simultáneas
  perform 1 from public.alertas_sos where id = new.alerta_id for update;

  if (select count(*) from public.sos_confirmaciones where alerta_id = new.alerta_id) >= 3 then
    update public.alertas_sos set estado = 'verificada'
     where id = new.alerta_id and estado = 'sin_verificar';
  end if;
  return new;
end $$;
```


### aplicar_confianza

Procedencia: docs/database/001_esquema_base_v5.sql:646

```sql
create function public.aplicar_confianza() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_delta int;
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  v_delta := case new.estado when 'falsa_alarma' then -20
                             when 'atendida'     then 5
                             else 0 end;
  if v_delta <> 0 then
    insert into public.eventos_confianza (perfil_id, alerta_id, delta, motivo)
    values (new.autor_id, new.id, v_delta, new.estado::text);
    update public.perfiles
       set puntaje_confianza = greatest(0, least(100, puntaje_confianza + v_delta))
     where id = new.autor_id;
  end if;
  return new;
end $$;
```


### auditar_alerta

Procedencia: docs/database/001_esquema_base_v5.sql:671

```sql
create function public.auditar_alerta() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.auditoria_sos (alerta_id, actor_id, accion) values (new.id, auth.uid(), 'creada');
  elsif new.estado is distinct from old.estado then
    insert into public.auditoria_sos (alerta_id, actor_id, accion)
    values (new.id, auth.uid(), old.estado::text || ' -> ' || new.estado::text);
  end if;
  return new;
end $$;
```


### Enums SOS

Procedencia: docs/database/001_esquema_base_v5.sql:90

```sql
create type clase_alerta       as enum ('alerta', 'soporte');
create type tipo_emergencia    as enum ('sismo', 'incendio', 'seguridad', 'salud', 'persona_atrapada',
                                        'agua_alimentos', 'traslado_refugio', 'dano_vivienda', 'otro');
create type urgencia_alerta    as enum ('critica', 'urgente', 'normal');
-- 'verificada' = confirmada por vecinos (3 confirmaciones) o emitida por vecino
-- confiable. NO es verificación oficial: en la app mostrar "Confirmada por vecinos".
create type estado_alerta      as enum ('sin_verificar', 'verificada', 'atendida', 'falsa_alarma', 'sin_confirmar', 'cancelada');
-- Ciclo de la ayuda (pantallas 10, 24): ofrecida -> aceptada -> en camino -> completada / cancelada
create type estado_ayuda       as enum ('ofrecida', 'aceptada', 'en_camino', 'completada', 'cancelada');
create type tipo_recurso       as enum ('agua', 'botiquin', 'herramientas', 'transporte', 'espacio_seguro', 'otro');
create type tipo_grupo         as enum ('brigada', 'voluntarios');

```

### Políticas SOS

Procedencia: docs/database/001_esquema_base_v5.sql:1522

```sql
create policy alertas_lectura on public.alertas_sos
  for select to authenticated using (zona_id = public.mi_zona());

-- Ayudas: solo las ven quienes participan (o admin). Se crean aquí y se actualizan con RPC.
create policy sos_resp_lectura on public.sos_respuestas
  for select to authenticated
  using (voluntario_id = auth.uid()
         or public.mi_rol() = 'admin'
         or exists (select 1 from public.alertas_sos a
                     where a.id = sos_respuestas.alerta_id and a.autor_id = auth.uid()));
create policy sos_resp_crear on public.sos_respuestas
  for insert to authenticated
  with check (voluntario_id = auth.uid()
              and estado = 'ofrecida'
              and exists (select 1 from public.alertas_sos a
                           where a.id = sos_respuestas.alerta_id and a.autor_id <> auth.uid()
                             and a.zona_id = public.mi_zona()
                             and a.estado in ('sin_verificar', 'verificada'))
              and (recurso_id is null
                   or exists (select 1 from public.recursos_criticos r
                               where r.id = sos_respuestas.recurso_id and r.propietario_id = auth.uid())));

-- Confirmaciones: cada vecino ve solo su propia fila; el conteo va por confirmaciones_de()
create policy sos_conf_propia on public.sos_confirmaciones
  for select to authenticated using (vecino_id = auth.uid());
create policy sos_conf_crear on public.sos_confirmaciones
  for insert to authenticated
  with check (vecino_id = auth.uid()
              and exists (select 1 from public.alertas_sos a
                           where a.id = sos_confirmaciones.alerta_id and a.autor_id <> auth.uid()));

-- Recursos: cualquier vecino puede ofrecer
create policy recursos_lectura on public.recursos_criticos
  for select to authenticated using (zona_id = public.mi_zona());
create policy recursos_crear on public.recursos_criticos
  for insert to authenticated with check (propietario_id = auth.uid() and zona_id = public.mi_zona());
create policy recursos_editar on public.recursos_criticos
  for update to authenticated
  using (propietario_id = auth.uid() or (public.mi_rol() = 'admin' and zona_id = public.mi_zona()));
create policy recursos_borrar on public.recursos_criticos
  for delete to authenticated using (propietario_id = auth.uid());

create policy grupos_lectura on public.grupos_apoyo
  for select to authenticated using (zona_id = public.mi_zona());

-- Vecinos vulnerables: solo con consentimiento; los ve el propio vecino y el admin de la zona
create policy vulnerables_lectura on public.vecinos_vulnerables
  for select to authenticated
  using (vecino_id = auth.uid()
         or (public.mi_rol() = 'admin' and zona_id = public.mi_zona()));
create policy vulnerables_crear on public.vecinos_vulnerables
  for insert to authenticated
  with check (vecino_id = auth.uid() and consentimiento and zona_id = public.mi_zona());
create policy vulnerables_borrar on public.vecinos_vulnerables
  for delete to authenticated using (vecino_id = auth.uid());


```

### Permisos

Procedencia: docs/database/001_esquema_base_v5.sql:1338

```sql
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon;
alter default privileges in schema public revoke execute on functions from public, anon;

-- Catálogos visibles antes de registrarse (elegir barrio) y teléfonos de emergencia
grant select on public.zonas, public.categorias_servicio, public.contactos_utiles to anon, authenticated;

grant select on all tables in schema public to authenticated;

-- INSERT directo permitido solo donde la RLS valida todo.
-- alertas_sos y publicaciones NO están aquí: solo entran por emitir_alerta()/publicar_rapido().
grant insert on public.servicios, public.servicio_contacto, public.servicio_trabajos,
                public.solicitudes_servicio, public.recomendaciones, public.respuestas,
                public.mensajes, public.sos_respuestas, public.sos_confirmaciones,
                public.recursos_criticos, public.vecinos_vulnerables, public.reportes
  to authenticated;

grant delete on public.servicios, public.servicio_contacto, public.servicio_trabajos,
                public.recomendaciones, public.publicaciones, public.respuestas,
                public.recursos_criticos, public.vecinos_vulnerables
  to authenticated;

-- UPDATE por columnas: nadie puede subirse el puntaje, el rol, el DNI ni la zona
grant update (avatar_url, telefono, compartir_telefono, tutorial_visto, preferencias)
  on public.perfiles to authenticated;
grant update (titulo, descripcion, anios_experiencia, activo) on public.servicios        to authenticated;
grant update (telefono, autorizado)                           on public.servicio_contacto to authenticated;
grant update (puntaje, comentario)                            on public.recomendaciones   to authenticated;
grant update (categoria, titulo, detalle, estado)             on public.publicaciones     to authenticated;
grant update (aceptada)                                       on public.respuestas        to authenticated;
grant update (cantidad, descripcion, disponible)              on public.recursos_criticos to authenticated;
grant update (leida)                                          on public.notificaciones    to authenticated;
grant update (estado)                                         on public.reportes          to authenticated;

-- Funciones: solo usuarios con sesión. Las internas viven en "privado".
grant execute on all functions in schema public to authenticated;
-- El registro directo sin PIN queda cerrado; la app usa registrar_completo()
revoke execute on function public.registrar_perfil(text, text, uuid, boolean) from authenticated;


```

### Triggers geográficos

Procedencia: docs/database/001_esquema_base_v5.sql:548

```sql
-- 5. Triggers ----------------------------------------------------------
-- 5.1 Aproximar ubicaciones antes de guardarlas
do $$
declare t text;
begin
  foreach t in array array['servicios','publicaciones','respuestas','alertas_sos','sos_respuestas',
                           'recursos_criticos','vecinos_vulnerables','grupos_apoyo']
  loop
    execute format(
      'create trigger tg_aproximar before insert or update of ubicacion_aprox on public.%I
       for each row execute function public.aplicar_aproximacion()', t);
  end loop;
end $$;

-- 5.2 Saneamiento de creado_local
do $$
declare t text;
begin
  foreach t in array array['publicaciones','alertas_sos','recursos_criticos']
  loop
    execute format(
      'create trigger tg_sanear_creado before insert or update of creado_local on public.%I
       for each row execute function public.sanear_creado_local()', t);
  end loop;
end $$;

-- 5.3 Límites de tasa (una sola función, parámetros por trigger)
create function public.tg_limite() returns trigger
language plpgsql security definer set search_path = public, privado as $$
begin
  perform privado.limitar(TG_ARGV[0]::regclass, TG_ARGV[1],
                          (to_jsonb(new) ->> TG_ARGV[1])::uuid, TG_ARGV[2]::int);
  return new;
end $$;

create trigger tg_limite before insert on public.publicaciones
  for each row execute function public.tg_limite('public.publicaciones', 'autor_id', '20');
create trigger tg_limite before insert on public.respuestas
  for each row execute function public.tg_limite('public.respuestas', 'receptor_id', '60');
create trigger tg_limite before insert on public.mensajes
  for each row execute function public.tg_limite('public.mensajes', 'autor_id', '300');
create trigger tg_limite before insert on public.reportes
  for each row execute function public.tg_limite('public.reportes', 'autor_id', '20');
create trigger tg_limite before insert on public.recursos_criticos
  for each row execute function public.tg_limite('public.recursos_criticos', 'propietario_id', '30');


```

### Índices y triggers — 001_esquema_base_v5.sql

```sql
create index if not exists idx_alertas_geo        on public.alertas_sos        using gist (ubicacion_aprox);
create index if not exists idx_recursos_geo       on public.recursos_criticos  using gist (ubicacion_aprox);
create index if not exists idx_grupos_geo         on public.grupos_apoyo       using gist (ubicacion_aprox);
create index if not exists idx_alertas_zona_estado    on public.alertas_sos          (zona_id, estado, creado_en desc);
create index if not exists idx_alertas_autor          on public.alertas_sos          (autor_id, creado_en desc);
create index if not exists idx_alertas_fecha          on public.alertas_sos          (creado_en desc);
create index if not exists idx_recursos_zona          on public.recursos_criticos     (zona_id, disponible);
create index if not exists idx_recursos_prop          on public.recursos_criticos     (propietario_id);
create index if not exists idx_sos_resp_voluntario    on public.sos_respuestas        (voluntario_id);
create index if not exists idx_sos_resp_recurso       on public.sos_respuestas        (recurso_id);
create index if not exists idx_conf_vecino            on public.sos_confirmaciones    (vecino_id);
create index if not exists idx_grupos_zona            on public.grupos_apoyo          (zona_id);
create index if not exists idx_auditoria_alerta       on public.auditoria_sos         (alerta_id, creado_en);
create trigger tg_aproximar before insert or update of ubicacion_aprox on public.%I
       for each row execute function public.aplicar_aproximacion()', t);
create trigger tg_sanear_creado before insert or update of creado_local on public.%I
       for each row execute function public.sanear_creado_local()', t);
create trigger tg_limite before insert on public.recursos_criticos
  for each row execute function public.tg_limite('public.recursos_criticos', 'propietario_id', '30');
create trigger tg_preparar_alerta
  before insert on public.alertas_sos
  for each row execute function public.preparar_alerta();
create trigger tg_confirmaciones
  after insert on public.sos_confirmaciones
  for each row execute function public.revisar_confirmaciones();
create trigger tg_confianza
  after update of estado on public.alertas_sos
  for each row execute function public.aplicar_confianza();
create trigger tg_auditoria
  after insert or update of estado on public.alertas_sos
  for each row execute function public.auditar_alerta();
create trigger tg_notif_ayuda after insert on public.sos_respuestas
  for each row execute function public.tg_notif_ayuda();
create trigger tg_notif_estado_ayuda after update of estado on public.sos_respuestas
  for each row execute function public.tg_notif_estado_ayuda();
```

### Índices y triggers — 002_complemento_v5.sql

```sql
alter table public.sos_respuestas
  drop constraint if exists sos_respuestas_alerta_id_voluntario_id_key;
create unique index if not exists uq_sos_resp_activa
  on public.sos_respuestas (alerta_id, voluntario_id)
  where estado <> 'cancelada';
create index if not exists idx_grupo_miembros_perfil
  on public.grupo_miembros (perfil_id);
```

### Índices y triggers — 003_correcciones_mvp.sql

```sql
create unique index if not exists uq_ayuda_sos_seleccionada_mvp
  on public.sos_respuestas (alerta_id)
  where estado in ('aceptada', 'en_camino');
revoke insert, delete on public.grupo_miembros from authenticated;
```

Las políticas sos_conf_crear y el bloqueo de membresías finales están en 003:100–120. La política inicial de confirmaciones del anexo se sustituye por la versión 003. Ver también 002:346–358 para lectura de grupo_miembros.

## Políticas finales de confirmación y brigadas

Procedencia: docs/database/003_correcciones_mvp.sql:100

```sql
drop policy if exists sos_conf_crear on public.sos_confirmaciones;
create policy sos_conf_crear on public.sos_confirmaciones
for insert to authenticated with check (
  vecino_id = auth.uid()
  and exists (
    select 1 from public.alertas_sos a
    where a.id = sos_confirmaciones.alerta_id
      and a.autor_id <> auth.uid()
      and a.zona_id = public.mi_zona()
      and a.estado in ('sin_verificar','verificada')
  )
);

-- 4. Brigadas en solo lectura en el MVP (evita autopromocion a rol lider).
revoke insert, delete on public.grupo_miembros from authenticated;
drop policy if exists miembros_crear on public.grupo_miembros;
drop policy if exists miembros_borrar on public.grupo_miembros;


```

## Firma auxiliar de mapa

Procedencia: docs/database/001_esquema_base_v5.sql:1271

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
