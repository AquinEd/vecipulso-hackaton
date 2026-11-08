-- ================================================================
-- VeciPulso MVP · INSTALACION INICIAL EN UN SUPABASE LIMPIO
-- Origen: v5 aportado por el usuario + parche MVP de seguridad.
-- Orden: base 001 -> complemento 002 -> correcciones 003 -> semilla 004.
-- El archivo ejecuta base, complemento, correcciones y DATOS DEMO.
-- No ejecutar sobre una instancia donde el esquema ya existe.
-- REQUIERE: crear proyecto Supabase y habilitar Anonymous Sign-ins
--             antes de registrar usuarios desde Flutter.
-- POSTGIS: el esquema extensions es requerido por la v5.
-- IMPORTANTE: seed DEMO usa coordenadas de Lima: edite el centro
--             de la zona en la seccion final para su lugar de prueba.
-- NO PRODUCCION: validar seguridad y tests antes de publicar la app.
-- ================================================================

begin;
set local search_path = public, extensions;

-- =====================================================================
-- Migración 001 de 003 · Esquema base de VeciPulso
-- Aplicar en orden: 001 -> 002 -> 003.
-- Crea: extensiones, tipos, 22 tablas, índices, funciones, triggers,
--        permisos, RLS, realtime y funciones RPC de la app.
-- =====================================================================
-- =====================================================================
-- VeciPulso · Esquema de base de datos v4 (PostgreSQL + PostGIS / Supabase)
-- Consolidado y corregido: v3 + parche v3.1 + correcciones v4.
--
-- QUÉ CORRIGE ESTA VERSIÓN
--   1. El admin ya puede leer y resolver reportes (políticas + grant).
--   2. cerrar_alerta() cancela las ayudas pendientes (no quedan colgadas).
--   3. actualizar_ayuda() cancela las demás ofertas al completar/cancelar.
--   4. PUBLIC y anon ya NO pueden ejecutar ninguna función de public.
--   5. Búsqueda de servicios sin tildes (extensión unaccent).
--   6. GRANT USAGE explícito sobre el esquema extensions.
--   7. Índices que faltaban (claves foráneas + consultas de muro/alertas).
--   8. Límites de tasa por hora en publicaciones/respuestas/mensajes/reportes.
--   9. creado_local saneado (no se aceptan fechas futuras ni absurdas).
--  10. Confirmaciones: se cuentan sin exponer quién confirmó (RPC).
--  11. Se puede volver a solicitar un servicio tras cancelar (índice parcial).
--  12. Si se desmarca una respuesta aceptada, la publicación vuelve a abierta.
--  13. Carreras resueltas con bloqueo por fila en alertas y confirmaciones.
--  14. Realtime idempotente; crea la publicación si no existe.
--  15. Verificación clara de que PostGIS y unaccent vivan en "extensions".
--
-- PENDIENTE (fuera de este parche: requieren decisión de producto)
--   · Favoritos/guardados y comentarios en publicaciones.
--   · Membresía de brigadas (resuelto en la migración 002).
--   · Mensajes leídos (badge) y notificaciones push (device tokens).
--   · Bucket de storage para avatares y fotos de trabajos.
--   · Borrado de cuenta y limpieza programada (pg_cron).
--
-- CÓMO APLICARLO
--   1. Authentication > Sign In / Providers > activar "Allow anonymous sign-ins".
--   2. Supabase > SQL Editor > New query > pegar TODO este archivo > Run.
--   3. (Opcional) ejecutar el bloque "PRUEBAS RÁPIDAS" del final.
--   Crea todo desde cero: no es repetible sobre una base ya creada.
-- =====================================================================

-- 0. Extensiones y esquema privado ------------------------------------
create schema if not exists extensions;
create schema if not exists privado;

-- PostGIS debe vivir en "extensions" porque todo el script usa extensions.ST_*
do $$
declare ns text;
begin
  select n.nspname into ns
    from pg_extension e join pg_namespace n on n.oid = e.extnamespace
   where e.extname = 'postgis';
  if ns is null then
    execute 'create extension postgis with schema extensions';
  elsif ns <> 'extensions' then
    raise exception 'PostGIS está instalado en el esquema "%". Muévelo con: alter extension postgis set schema extensions;', ns;
  end if;
end $$;

-- pgcrypto: se crea si falta; las funciones lo resuelven por search_path
create extension if not exists pgcrypto with schema extensions;

-- unaccent: necesario para buscar sin tildes; se mueve si estaba en otro esquema
do $$
declare ns text;
begin
  select n.nspname into ns
    from pg_extension e join pg_namespace n on n.oid = e.extnamespace
   where e.extname = 'unaccent';
  if ns is null then
    execute 'create extension unaccent with schema extensions';
  elsif ns <> 'extensions' then
    execute 'alter extension unaccent set schema extensions';
  end if;
end $$;

-- La API (PostgREST) no expone "privado": ahí viven el PIN, la sal del DNI
-- y las funciones internas que la app no debe poder llamar.
revoke all on schema privado from public, anon, authenticated;
grant usage on schema public     to anon, authenticated;
grant usage on schema extensions to anon, authenticated;

-- 1. Tipos enumerados --------------------------------------------------
create type rol_usuario        as enum ('vecino', 'admin');
-- Muro: "Necesito / Ofrezco / Donación / Intercambio / Préstamo" (pantallas 05, 06, 15)
create type tipo_publicacion   as enum ('necesito', 'ofrezco', 'donacion', 'intercambio', 'prestamo');
create type categoria_favor    as enum ('herramientas', 'ropa', 'alimentos', 'habilidades', 'movilidad', 'ayuda_temporal', 'otro');
create type estado_publicacion as enum ('abierta', 'en_coordinacion', 'resuelta', 'cancelada');
-- SOS (pantallas 08, 18): "alerta" = sismo/incendio/seguridad/salud; "soporte" = solicitud crítica
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
create type estado_solicitud   as enum ('solicitada', 'contactado', 'completada', 'cancelada');
create type nivel_confianza    as enum ('confiable', 'normal', 'en_revision', 'restringido');

comment on type public.estado_alerta is
  'verificada = confirmada por vecinos (3 confirmaciones) o emitida por vecino confiable. NO es verificación oficial. Mostrar "Confirmada por vecinos", nunca "Verificada". sin_confirmar = cerrada sin poder confirmarse (no confundir con sin_verificar, que es una alerta abierta).';

-- 2. Tablas ------------------------------------------------------------
create table public.zonas (
  id      uuid primary key default gen_random_uuid(),
  nombre  text not null,
  sector  text,
  centro  extensions.geography(Point, 4326) not null,
  radio_m int  not null default 2000 check (radio_m > 0)
);

-- Perfil del vecino. Se crea con registrar_completo() (NO por trigger de Auth).
-- El DNI no se guarda en claro: solo un HMAC con sal secreta (privado.config).
-- DNI y nombre son autodeclarados: NO prueban identidad (no hay validación RENIEC).
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

-- Solo en esquema privado: nunca legible desde la app
create table privado.config (
  clave text primary key,
  valor text not null
);
-- Sal del DNI generada sin depender del esquema donde viva pgcrypto
insert into privado.config (clave, valor)
values ('dni_pepper',
        replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''))
on conflict do nothing;

create table privado.pin_credenciales (
  user_id           uuid primary key references auth.users(id) on delete cascade,
  pin_hash          text not null,                    -- bcrypt (crypt + gen_salt('bf'))
  intentos_fallidos int  not null default 0,
  bloqueado_hasta   timestamptz,
  actualizado_en    timestamptz not null default now()
);

create table public.categorias_servicio (
  id     serial primary key,
  nombre text not null unique,
  icono  text
);

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

-- Teléfono del servicio en tabla aparte: solo visible si el proveedor lo autoriza
create table public.servicio_contacto (
  servicio_id uuid primary key references public.servicios(id) on delete cascade,
  telefono    text not null check (telefono ~ '^[0-9+ ]{6,15}$'),
  autorizado  boolean not null default false
);

-- "Trabajos realizados" del perfil del proveedor (pantalla 04)
create table public.servicio_trabajos (
  id          uuid primary key default gen_random_uuid(),
  servicio_id uuid not null references public.servicios(id) on delete cascade,
  titulo      text not null,
  creado_en   timestamptz not null default now()
);

-- Botón "Solicitar servicio" (pantalla 04). No es una contratación ni un pago.
-- Solo quien tuvo una solicitud 'completada' puede dejar Visto Bueno (pantalla 22).
-- La unicidad es parcial: se puede volver a solicitar tras cancelar o completar.
create table public.solicitudes_servicio (
  id             uuid primary key default gen_random_uuid(),
  servicio_id    uuid not null references public.servicios(id) on delete cascade,
  solicitante_id uuid not null references public.perfiles(id) on delete cascade,
  estado         estado_solicitud not null default 'solicitada',
  mensaje        text,
  creado_en       timestamptz not null default now()
);

-- Visto Bueno Vecinal: una recomendación por vecino y por servicio
create table public.recomendaciones (
  id          uuid primary key default gen_random_uuid(),
  servicio_id uuid not null references public.servicios(id) on delete cascade,
  autor_id    uuid not null references public.perfiles(id) on delete cascade,
  puntaje     smallint not null check (puntaje between 1 and 5),
  comentario  text,
  creado_en   timestamptz not null default now(),
  unique (servicio_id, autor_id)
);

-- Muro de favores. El cliente genera el UUID (id): así la cola offline es idempotente.
create table public.publicaciones (
  id              uuid primary key default gen_random_uuid(),
  autor_id        uuid not null references public.perfiles(id) on delete cascade,
  tipo            tipo_publicacion not null,
  categoria       categoria_favor  not null default 'otro',
  titulo          text not null check (char_length(titulo) between 3 and 120),
  detalle         text,
  zona_id         uuid not null references public.zonas(id),
  ubicacion_aprox extensions.geography(Point, 4326) not null,
  estado          estado_publicacion not null default 'abierta',
  creado_local    timestamptz,                         -- momento en el dispositivo (offline)
  creado_en       timestamptz not null default now(),
  vence_en        timestamptz not null default now() + interval '7 days'
);

-- Quienes responden a una publicación
create table public.respuestas (
  id              uuid primary key default gen_random_uuid(),
  publicacion_id  uuid not null references public.publicaciones(id) on delete cascade,
  receptor_id     uuid not null references public.perfiles(id) on delete cascade,
  mensaje         text,
  aceptada        boolean not null default false,
  ubicacion_aprox extensions.geography(Point, 4326),
  creado_en       timestamptz not null default now(),
  unique (publicacion_id, receptor_id)
);

-- Modo SOS: alertas vecinales y solicitudes de soporte crítico
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

-- Recursos que un vecino ofrece (agua, botiquín, herramientas, transporte, espacio seguro)
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

-- Ayuda a una alerta (pantallas 10 y 24): quien ayuda <-> solicitante, con estado propio
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

-- Chat 1 a 1: pertenece a UNA respuesta (favor) o a UNA ayuda SOS, nunca a un hilo grupal
create table public.mensajes (
  id           uuid primary key default gen_random_uuid(),
  respuesta_id uuid references public.respuestas(id)     on delete cascade,
  ayuda_id     uuid references public.sos_respuestas(id) on delete cascade,
  autor_id     uuid not null references public.perfiles(id) on delete cascade,
  texto        text not null check (char_length(texto) between 1 and 1000),
  creado_en    timestamptz not null default now(),
  check (num_nonnulls(respuesta_id, ayuda_id) = 1)
);

-- "Yo también lo veo": confirmación comunitaria
create table public.sos_confirmaciones (
  alerta_id uuid not null references public.alertas_sos(id) on delete cascade,
  vecino_id uuid not null references public.perfiles(id) on delete cascade,
  creado_en timestamptz not null default now(),
  primary key (alerta_id, vecino_id)
);

-- Brigadas y grupos (pantalla 09). El contacto es público dentro de la zona por diseño.
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

-- Solo con consentimiento explícito. Nunca se guarda la posición exacta.
create table public.vecinos_vulnerables (
  id              uuid primary key default gen_random_uuid(),
  vecino_id       uuid not null unique references public.perfiles(id) on delete cascade,
  zona_id         uuid not null references public.zonas(id),
  necesidad       text,
  ubicacion_aprox extensions.geography(Point, 4326),
  consentimiento  boolean not null check (consentimiento),
  creado_en       timestamptz not null default now()
);

create table public.eventos_confianza (
  id        uuid primary key default gen_random_uuid(),
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  alerta_id uuid references public.alertas_sos(id) on delete set null,
  delta     int not null,
  motivo    text,
  creado_en timestamptz not null default now()
);

-- Insignia del menú lateral (pantalla 01). Es una bandeja interna, no push.
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

-- Auditoría de alertas (creación, cancelaciones y cierres)
create table public.auditoria_sos (
  id        uuid primary key default gen_random_uuid(),
  alerta_id uuid not null,
  actor_id  uuid,
  accion    text not null,
  creado_en timestamptz not null default now()
);

-- Teléfonos oficiales de emergencia (disponibles también sin sesión)
create table public.contactos_utiles (
  id       serial primary key,
  nombre   text not null,
  telefono text not null,
  tipo     text not null default 'oficial',
  orden    int  not null default 0
);

create table public.reportes (
  id          uuid primary key default gen_random_uuid(),
  autor_id    uuid not null references public.perfiles(id) on delete cascade,
  tabla       text not null check (tabla in ('servicios', 'publicaciones', 'alertas_sos', 'recomendaciones', 'mensajes', 'perfiles')),
  registro_id uuid not null,
  motivo      text,
  estado      text not null default 'pendiente' check (estado in ('pendiente', 'revisado', 'descartado')),
  creado_en   timestamptz not null default now()
);

-- 3. Índices -----------------------------------------------------------
-- Geográficos
create index if not exists idx_servicios_geo      on public.servicios          using gist (ubicacion_aprox);
create index if not exists idx_publicaciones_geo  on public.publicaciones      using gist (ubicacion_aprox);
create index if not exists idx_alertas_geo        on public.alertas_sos        using gist (ubicacion_aprox);
create index if not exists idx_recursos_geo       on public.recursos_criticos  using gist (ubicacion_aprox);
create index if not exists idx_grupos_geo         on public.grupos_apoyo       using gist (ubicacion_aprox);
create index if not exists idx_vulnerables_geo    on public.vecinos_vulnerables using gist (ubicacion_aprox);

-- Claves foráneas y filtros
create index if not exists idx_perfiles_zona          on public.perfiles              (zona_id);
create index if not exists idx_servicios_zona         on public.servicios             (zona_id);
create index if not exists idx_servicios_proveedor    on public.servicios             (proveedor_id);
create index if not exists idx_servicios_categoria    on public.servicios             (categoria_id);
create index if not exists idx_trabajos_servicio      on public.servicio_trabajos     (servicio_id);
create index if not exists idx_solicitudes_solicitante on public.solicitudes_servicio (solicitante_id);
create index if not exists idx_solicitudes_servicio   on public.solicitudes_servicio  (servicio_id);
create index if not exists idx_recomendaciones_serv   on public.recomendaciones       (servicio_id);
create index if not exists idx_recomendaciones_autor  on public.recomendaciones       (autor_id);
create index if not exists idx_publicaciones_zona     on public.publicaciones         (zona_id, estado);
create index if not exists idx_publicaciones_autor    on public.publicaciones         (autor_id);
create index if not exists idx_publicaciones_fecha    on public.publicaciones         (zona_id, creado_en desc);
create index if not exists idx_respuestas_receptor    on public.respuestas            (receptor_id);
create index if not exists idx_alertas_zona_estado    on public.alertas_sos          (zona_id, estado, creado_en desc);
create index if not exists idx_alertas_autor          on public.alertas_sos          (autor_id, creado_en desc);
create index if not exists idx_alertas_fecha          on public.alertas_sos          (creado_en desc);
create index if not exists idx_recursos_zona          on public.recursos_criticos     (zona_id, disponible);
create index if not exists idx_recursos_prop          on public.recursos_criticos     (propietario_id);
create index if not exists idx_sos_resp_voluntario    on public.sos_respuestas        (voluntario_id);
create index if not exists idx_sos_resp_recurso       on public.sos_respuestas        (recurso_id);
create index if not exists idx_mensajes_respuesta     on public.mensajes              (respuesta_id, creado_en);
create index if not exists idx_mensajes_ayuda         on public.mensajes              (ayuda_id, creado_en);
create index if not exists idx_mensajes_autor         on public.mensajes              (autor_id);
create index if not exists idx_conf_vecino            on public.sos_confirmaciones    (vecino_id);
create index if not exists idx_grupos_zona            on public.grupos_apoyo          (zona_id);
create index if not exists idx_vulnerables_zona       on public.vecinos_vulnerables   (zona_id);
create index if not exists idx_eventos_perfil         on public.eventos_confianza     (perfil_id, creado_en desc);
create index if not exists idx_notificaciones_perfil  on public.notificaciones        (perfil_id, leida, creado_en desc);
create index if not exists idx_auditoria_alerta       on public.auditoria_sos         (alerta_id, creado_en);
create index if not exists idx_reportes_autor         on public.reportes              (autor_id);

-- Una sola solicitud "viva" por vecino y servicio (permite reintentar tras cancelar)
create unique index if not exists uq_solicitud_activa
  on public.solicitudes_servicio (servicio_id, solicitante_id)
  where estado in ('solicitada', 'contactado');

-- Evita reportes duplicados del mismo registro mientras siga pendiente
create unique index if not exists uq_reporte_pendiente
  on public.reportes (autor_id, tabla, registro_id)
  where estado = 'pendiente';

-- 4. Funciones auxiliares ---------------------------------------------
create function public.mi_zona() returns uuid
language sql stable security definer set search_path = public as $$
  select zona_id from public.perfiles where id = auth.uid()
$$;

create function public.mi_rol() returns rol_usuario
language sql stable security definer set search_path = public as $$
  select rol from public.perfiles where id = auth.uid()
$$;

create function public.nivel_de(p int) returns nivel_confianza
language sql immutable as $$
  select case when p >= 80 then 'confiable'::nivel_confianza
              when p >= 50 then 'normal'::nivel_confianza
              when p >= 25 then 'en_revision'::nivel_confianza
              else 'restringido'::nivel_confianza end
$$;

-- Sello "Visto Bueno Vecinal": al menos 3 recomendaciones y promedio >= 4.0.
create function public.tiene_visto_bueno(n bigint, promedio numeric) returns boolean
language sql immutable as $$
  select coalesce(n, 0) >= 3 and coalesce(promedio, 0) >= 4.0
$$;

-- Redondea la ubicación a una cuadrícula de ~166 m (privacidad)
create function public.aproximar(g extensions.geography) returns extensions.geography
language sql immutable set search_path = public, extensions as $$
  select extensions.ST_SnapToGrid(g::extensions.geometry, 0.0015)::extensions.geography
$$;

-- Aproxima la ubicación; si no llega ninguna usa el centro del barrio.
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

-- creado_local viene del dispositivo: nunca en el futuro, nunca más de 30 días atrás
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

-- Participantes del chat de un favor: el autor de la publicación y quien respondió
create function public.participa_respuesta(p_resp uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.respuestas r
                   join public.publicaciones p on p.id = r.publicacion_id
                  where r.id = p_resp and (r.receptor_id = auth.uid() or p.autor_id = auth.uid()))
$$;

-- Participantes de una ayuda SOS: quien ayuda y el autor de la alerta
create function public.participa_ayuda(p_resp uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.sos_respuestas s
                   join public.alertas_sos a on a.id = s.alerta_id
                  where s.id = p_resp and (s.voluntario_id = auth.uid() or a.autor_id = auth.uid()))
$$;

-- Recursos que sirven para cada tipo de emergencia (Match Solidario simple)
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

-- Internas (esquema privado: la app no puede llamarlas)
create function privado.hash_dni(p_dni text) returns text
language sql stable security definer set search_path = privado, public, extensions as $$
  select encode(hmac(p_dni, (select valor from privado.config where clave = 'dni_pepper'), 'sha256'), 'hex')
$$;

create function privado.notificar(p_perfil uuid, p_tipo text, p_titulo text, p_ref_tabla text, p_ref_id uuid)
returns void language sql security definer set search_path = public as $$
  insert into public.notificaciones (perfil_id, tipo, titulo, ref_tabla, ref_id)
  select p_perfil, p_tipo, p_titulo, p_ref_tabla, p_ref_id
   where p_perfil is not null and p_perfil is distinct from auth.uid()
$$;

-- Límite genérico: cuenta filas del mismo dueño en la última hora
create function privado.limitar(p_tabla regclass, p_columna text, p_uid uuid, p_max int)
returns void language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if p_uid is null then return; end if;
  execute format(
    'select count(*) from %s where %I = $1 and creado_en > now() - interval ''1 hour''',
    p_tabla, p_columna)
    into n using p_uid;
  if n >= p_max then
    raise exception 'Límite por hora alcanzado en %', p_tabla;
  end if;
end $$;

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

-- 5.4 Al crear una alerta: límite por hora y nivel de difusión según confianza
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

create trigger tg_preparar_alerta
  before insert on public.alertas_sos
  for each row execute function public.preparar_alerta();

-- 5.5 Tres confirmaciones de vecinos difunden una alerta sin verificar
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

create trigger tg_confirmaciones
  after insert on public.sos_confirmaciones
  for each row execute function public.revisar_confirmaciones();

-- 5.6 Ajustar la confianza cuando se confirma el resultado de una alerta
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

create trigger tg_confianza
  after update of estado on public.alertas_sos
  for each row execute function public.aplicar_confianza();

-- 5.7 Auditoría de alertas
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

create trigger tg_auditoria
  after insert or update of estado on public.alertas_sos
  for each row execute function public.auditar_alerta();

-- 5.8 Aceptar una respuesta pasa la publicación a "en coordinación".
--     Si se desmarca la última aceptada, vuelve a "abierta".
create function public.respuesta_aceptada() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.aceptada then
    update public.publicaciones set estado = 'en_coordinacion'
     where id = new.publicacion_id and estado = 'abierta';
  else
    update public.publicaciones set estado = 'abierta'
     where id = new.publicacion_id and estado = 'en_coordinacion'
       and not exists (select 1 from public.respuestas r
                        where r.publicacion_id = new.publicacion_id
                          and r.aceptada and r.id <> new.id);
  end if;
  return new;
end $$;

create trigger tg_respuesta_aceptada
  after update of aceptada on public.respuestas
  for each row when (new.aceptada is distinct from old.aceptada)
  execute function public.respuesta_aceptada();

-- 5.9 Notificaciones internas (bandeja de la app)
create function public.tg_notif_respuesta() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform privado.notificar((select autor_id from public.publicaciones where id = new.publicacion_id),
                            'respuesta', 'Un vecino respondió a tu publicación', 'publicaciones', new.publicacion_id);
  return new;
end $$;
create trigger tg_notif_respuesta after insert on public.respuestas
  for each row execute function public.tg_notif_respuesta();

create function public.tg_notif_ayuda() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform privado.notificar((select autor_id from public.alertas_sos where id = new.alerta_id),
                            'ayuda_ofrecida', 'Un vecino ofreció ayuda para tu solicitud', 'sos_respuestas', new.id);
  return new;
end $$;
create trigger tg_notif_ayuda after insert on public.sos_respuestas
  for each row execute function public.tg_notif_ayuda();

create function public.tg_notif_estado_ayuda() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_autor uuid;
begin
  if new.estado is not distinct from old.estado then return new; end if;
  select autor_id into v_autor from public.alertas_sos where id = new.alerta_id;
  perform privado.notificar(case when auth.uid() = new.voluntario_id then v_autor else new.voluntario_id end,
                            'estado_ayuda', 'Estado de la ayuda: ' || new.estado::text, 'sos_respuestas', new.id);
  return new;
end $$;
create trigger tg_notif_estado_ayuda after update of estado on public.sos_respuestas
  for each row execute function public.tg_notif_estado_ayuda();

create function public.tg_notif_mensaje() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_otro uuid;
begin
  if new.respuesta_id is not null then
    select case when r.receptor_id = new.autor_id then p.autor_id else r.receptor_id end into v_otro
      from public.respuestas r join public.publicaciones p on p.id = r.publicacion_id
     where r.id = new.respuesta_id;
    perform privado.notificar(v_otro, 'mensaje', 'Nuevo mensaje sobre un favor', 'respuestas', new.respuesta_id);
  else
    select case when s.voluntario_id = new.autor_id then a.autor_id else s.voluntario_id end into v_otro
      from public.sos_respuestas s join public.alertas_sos a on a.id = s.alerta_id
     where s.id = new.ayuda_id;
    perform privado.notificar(v_otro, 'mensaje', 'Nuevo mensaje sobre una ayuda SOS', 'sos_respuestas', new.ayuda_id);
  end if;
  return new;
end $$;
create trigger tg_notif_mensaje after insert on public.mensajes
  for each row execute function public.tg_notif_mensaje();

-- 6. Funciones que llama la app (RPC) ----------------------------------

-- 6.1 Registro (una sola vez por dispositivo). Requiere sesión anónima activa.
--     No se otorga a la app: se usa registrar_completo().
create function public.registrar_perfil(
  p_dni text, p_nombre_completo text, p_zona uuid, p_consentimiento boolean)
returns void
language plpgsql security definer set search_path = public, privado, extensions as $$
declare
  v_uid     uuid := auth.uid();
  v_nombre  text := regexp_replace(btrim(coalesce(p_nombre_completo, '')), '\s+', ' ', 'g');
  v_partes  text[];
  v_publico text;
begin
  if v_uid is null then raise exception 'Se requiere una sesión'; end if;
  if exists (select 1 from public.perfiles where id = v_uid) then
    raise exception 'Este dispositivo ya tiene un perfil';
  end if;
  if p_dni is null or p_dni !~ '^[0-9]{8}$' then
    raise exception 'DNI inválido: deben ser exactamente 8 dígitos';
  end if;
  if char_length(v_nombre) not between 3 and 80 then
    raise exception 'Nombre completo inválido';
  end if;
  if not coalesce(p_consentimiento, false) then
    raise exception 'Debes aceptar el tratamiento de tus datos para registrarte';
  end if;
  if not exists (select 1 from public.zonas where id = p_zona) then
    raise exception 'Barrio no válido';
  end if;

  v_partes  := string_to_array(v_nombre, ' ');
  v_publico := v_partes[1] ||
               case when array_length(v_partes, 1) >= 2
                    then ' ' || upper(left(v_partes[2], 1)) || '.' else '' end;

  begin
    insert into public.perfiles (id, dni_hash, nombre_completo, nombre_publico, zona_id, consentimiento_datos)
    values (v_uid, privado.hash_dni(p_dni), v_nombre, v_publico, p_zona, true);
  exception when unique_violation then
    raise exception 'Ese DNI ya está registrado en otro dispositivo';
  end;
end $$;

-- 6.2 Registro atómico: perfil + PIN en una sola operación
create function public.registrar_completo(
  p_dni text, p_nombre_completo text, p_zona uuid,
  p_consentimiento boolean, p_pin text)
returns void
language plpgsql security definer set search_path = public, privado, extensions as $$
begin
  perform public.registrar_perfil(p_dni, p_nombre_completo, p_zona, p_consentimiento);
  perform public.crear_pin(p_pin);
end $$;

-- 6.3 PIN de 6 dígitos validado en servidor (bcrypt + límite de intentos)
create function public.crear_pin(p_pin text) returns void
language plpgsql security definer set search_path = public, privado, extensions as $$
begin
  if auth.uid() is null or not exists (select 1 from public.perfiles where id = auth.uid()) then
    raise exception 'Primero completa el registro';
  end if;
  if p_pin is null or p_pin !~ '^[0-9]{6}$' then
    raise exception 'El PIN debe tener exactamente 6 dígitos';
  end if;
  if p_pin ~ '^(.)\1{5}$' or p_pin in ('123456', '654321') then
    raise exception 'Elige un PIN menos obvio';
  end if;
  if exists (select 1 from privado.pin_credenciales where user_id = auth.uid()) then
    raise exception 'Ya existe un PIN; usa cambiar_pin';
  end if;
  insert into privado.pin_credenciales (user_id, pin_hash)
  values (auth.uid(), crypt(p_pin, gen_salt('bf', 10)));
end $$;

-- Devuelve jsonb (no lanza excepciones) para que el contador de intentos no se revierta.
create function public.verificar_pin(p_pin text) returns jsonb
language plpgsql security definer set search_path = public, privado, extensions as $$
declare
  c privado.pin_credenciales%rowtype;
  n int;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'motivo', 'sin_sesion');
  end if;
  if p_pin is null or p_pin !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'motivo', 'formato');
  end if;
  select * into c from privado.pin_credenciales where user_id = auth.uid() for update;
  if not found then
    return jsonb_build_object('ok', false, 'motivo', 'sin_pin');
  end if;
  if c.bloqueado_hasta is not null and c.bloqueado_hasta > now() then
    return jsonb_build_object('ok', false, 'motivo', 'bloqueado', 'bloqueado_hasta', c.bloqueado_hasta);
  end if;

  if c.pin_hash = crypt(p_pin, c.pin_hash) then
    update privado.pin_credenciales
       set intentos_fallidos = 0, bloqueado_hasta = null where user_id = auth.uid();
    return jsonb_build_object('ok', true);
  end if;

  n := c.intentos_fallidos + 1;
  if n >= 5 then
    update privado.pin_credenciales
       set intentos_fallidos = 0, bloqueado_hasta = now() + interval '5 minutes'
     where user_id = auth.uid();
    return jsonb_build_object('ok', false, 'motivo', 'bloqueado',
                              'bloqueado_hasta', now() + interval '5 minutes');
  end if;
  update privado.pin_credenciales set intentos_fallidos = n where user_id = auth.uid();
  return jsonb_build_object('ok', false, 'motivo', 'incorrecto', 'intentos_restantes', 5 - n);
end $$;

create function public.cambiar_pin(p_actual text, p_nuevo text) returns jsonb
language plpgsql security definer set search_path = public, privado, extensions as $$
declare r jsonb;
begin
  r := public.verificar_pin(p_actual);
  if not (r ->> 'ok')::boolean then return r; end if;
  if p_nuevo is null or p_nuevo !~ '^[0-9]{6}$' or p_nuevo ~ '^(.)\1{5}$' or p_nuevo in ('123456', '654321') then
    raise exception 'PIN nuevo no válido';
  end if;
  update privado.pin_credenciales
     set pin_hash = crypt(p_nuevo, gen_salt('bf', 10)), actualizado_en = now()
   where user_id = auth.uid();
  return jsonb_build_object('ok', true);
end $$;

-- 6.4 Publicación exprés (máx. 3 acciones). Idempotente: el cliente envía su UUID.
create function public.publicar_rapido(
  p_id uuid, p_tipo tipo_publicacion, p_titulo text,
  p_detalle text default null, p_categoria categoria_favor default 'otro',
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

  -- Reintento de la cola offline: mismo id, mismo autor => devolver el existente
  if exists (select 1 from public.publicaciones where id = p_id) then
    if exists (select 1 from public.publicaciones where id = p_id and autor_id = v_uid) then
      return p_id;
    end if;
    raise exception 'Identificador en uso';
  end if;
  if p_lat is not null and p_lng is not null then
    v_pt := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;
    -- Fuera del barrio: se usa el centro del barrio (el trigger lo completa)
    if not exists (select 1 from public.zonas z where z.id = v_zona and ST_DWithin(z.centro, v_pt, z.radio_m * 2)) then
      v_pt := null;
    end if;
  end if;
  insert into public.publicaciones (id, autor_id, tipo, categoria, titulo, detalle, zona_id, ubicacion_aprox, creado_local)
  values (p_id, v_uid, p_tipo, p_categoria, p_titulo, p_detalle, v_zona, v_pt, v_creado);
  return p_id;
end $$;

-- 6.5 Emitir alerta o solicitar soporte. Idempotente (no repite el límite al reintentar).
create function public.emitir_alerta(
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

-- 6.6 Cerrar una alerta: el admin, o el vecino cuya ayuda fue aceptada. Cancela las ayudas vivas.
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

-- 6.7 El autor cancela su propia alerta (sin penalización; queda en auditoría)
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

-- 6.8 Cambiar el estado de una ayuda (solo transiciones válidas según quién actúa).
--     Al completar/cancelar se cancelan las demás ofertas de la misma alerta.
create function public.actualizar_ayuda(p_resp uuid, p_estado estado_ayuda) returns void
language plpgsql security definer set search_path = public as $$
declare
  v   record;
  uid uuid := auth.uid();
begin
  select s.estado, s.voluntario_id, s.alerta_id, a.autor_id as autor
    into v
    from public.sos_respuestas s join public.alertas_sos a on a.id = s.alerta_id
   where s.id = p_resp
   for update of s;
  if not found then raise exception 'La ayuda no existe'; end if;

  if uid = v.autor then                                   -- solicitante
    if not ((p_estado = 'aceptada'   and v.estado = 'ofrecida')
         or (p_estado = 'completada' and v.estado in ('aceptada', 'en_camino'))
         or (p_estado = 'cancelada'  and v.estado in ('ofrecida', 'aceptada', 'en_camino'))) then
      raise exception 'Transición no permitida';
    end if;
  elsif uid = v.voluntario_id then                        -- quien ofrece la ayuda
    if not ((p_estado = 'en_camino'  and v.estado = 'aceptada')
         or (p_estado = 'completada' and v.estado in ('aceptada', 'en_camino'))
         or (p_estado = 'cancelada'  and v.estado in ('ofrecida', 'aceptada', 'en_camino'))) then
      raise exception 'Transición no permitida';
    end if;
  else
    raise exception 'No autorizado';
  end if;

  update public.sos_respuestas set estado = p_estado, actualizado_en = now() where id = p_resp;

  -- Esta ayuda terminó: las demás ofertas de la misma alerta ya no aplican
  if p_estado in ('completada', 'cancelada') then
    update public.sos_respuestas set estado = 'cancelada', actualizado_en = now()
     where alerta_id = v.alerta_id and id <> p_resp
       and estado in ('ofrecida', 'aceptada', 'en_camino');
  end if;

  if p_estado = 'completada' then
    update public.alertas_sos set estado = 'atendida', cerrado_en = now()
     where id = v.alerta_id and estado in ('sin_verificar', 'verificada');
  end if;
end $$;

-- 6.9 Solicitudes de servicio: transiciones validadas por RPC
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

-- Bandeja del proveedor: solicitudes que le llegaron
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

-- Mis solicitudes enviadas: alimenta la pantalla 22
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

-- 6.10 Perfiles visibles de mi zona (sin DNI, sin puntaje, sin nombre completo)
create function public.perfiles_publicos_de_mi_zona()
returns table (id uuid, nombre_publico text, avatar_url text, zona_id uuid, vecino_confiable boolean)
language sql stable security definer set search_path = public as $$
  select p.id, p.nombre_publico, p.avatar_url, p.zona_id, (p.puntaje_confianza >= 80)
    from public.perfiles p
   where p.zona_id = public.mi_zona()
$$;

-- 6.11 Servicios cercanos con filtros de la pantalla 03 (distancia, estrellas, búsqueda)
--      La búsqueda ignora tildes y mayúsculas (unaccent + lower).
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

-- Reseñas de un servicio (pantalla 04)
create function public.resenas_de_servicio(p_servicio uuid)
returns table (id uuid, autor text, puntaje smallint, comentario text, creado_en timestamptz)
language sql stable set search_path = public as $$
  select r.id, pp.nombre_publico, r.puntaje, r.comentario, r.creado_en
    from public.recomendaciones r
    join public.perfiles_publicos_de_mi_zona() pp on pp.id = r.autor_id
   where r.servicio_id = p_servicio
   order by r.creado_en desc
$$;

-- 6.12 Muro de favores cercano (definer para contar respuestas sin exponerlas)
create function public.buscar_publicaciones_cercanas(
  p_lat double precision, p_lng double precision,
  p_radio_m int default 3000, p_tipo tipo_publicacion default null)
returns table (id uuid, tipo tipo_publicacion, categoria categoria_favor, titulo text, detalle text,
               autor text, autor_id uuid, vecino_confiable boolean, distancia_m int,
               estado estado_publicacion, respuestas bigint, ya_respondi boolean,
               lat double precision, lng double precision, creado_en timestamptz)
language sql stable security definer set search_path = public, extensions as $$
  with origen as (select ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography as g)
  select p.id, p.tipo, p.categoria, p.titulo, p.detalle,
         pe.nombre_publico, p.autor_id, (pe.puntaje_confianza >= 80),
         round(ST_Distance(p.ubicacion_aprox, o.g))::int,
         p.estado,
         (select count(*) from public.respuestas r where r.publicacion_id = p.id),
         exists (select 1 from public.respuestas r where r.publicacion_id = p.id and r.receptor_id = auth.uid()),
         ST_Y(p.ubicacion_aprox::geometry), ST_X(p.ubicacion_aprox::geometry),
         p.creado_en
    from origen o
    cross join public.publicaciones p
    join public.perfiles pe on pe.id = p.autor_id
   where p.zona_id = public.mi_zona()
     and p.estado in ('abierta', 'en_coordinacion')
     and p.vence_en > now()
     and ST_DWithin(p.ubicacion_aprox, o.g, p_radio_m)
     and (p_tipo is null or p.tipo = p_tipo)
   order by p.creado_en desc
$$;

-- 6.13 Reportes SOS cercanos (pantalla 08)
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

-- Cabecera del tablero: "Zona de riesgo activa" según reportes de vecinos (no oficial)
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

-- Match Solidario simple: SUGIERE recursos al solicitante; no asigna a nadie
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

-- Tarjeta de la contraparte en "Ayuda en curso" (pantallas 10 y 24)
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

-- Mapa: una sola llamada con todas las capas de la leyenda
--   comercio (azul) | recurso (verde) | alerta (rojo/naranja) | brigada (celeste)
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

-- Pestaña "Mensajes": conversaciones (favores y ayudas SOS) con el último mensaje
create function public.mis_conversaciones()
returns table (tipo text, ref_id uuid, titulo text, contraparte text, ultimo_mensaje text, ultimo_en timestamptz)
language sql stable security definer set search_path = public as $$
  with conv as (
    select 'favor'::text as tipo, r.id as ref_id, p.titulo as titulo,
           case when r.receptor_id = auth.uid() then p.autor_id else r.receptor_id end as otro
      from public.respuestas r join public.publicaciones p on p.id = r.publicacion_id
     where r.receptor_id = auth.uid() or p.autor_id = auth.uid()
    union all
    select 'sos', s.id, 'Ayuda SOS: ' || replace(a.tipo::text, '_', ' '),
           case when s.voluntario_id = auth.uid() then a.autor_id else s.voluntario_id end
      from public.sos_respuestas s join public.alertas_sos a on a.id = s.alerta_id
     where s.voluntario_id = auth.uid() or a.autor_id = auth.uid()
  )
  select c.tipo, c.ref_id, c.titulo, po.nombre_publico, m.texto, m.creado_en
    from conv c
    join public.perfiles po on po.id = c.otro
    left join lateral (
      select mm.texto, mm.creado_en from public.mensajes mm
       where (c.tipo = 'favor' and mm.respuesta_id = c.ref_id)
          or (c.tipo = 'sos'   and mm.ayuda_id     = c.ref_id)
       order by mm.creado_en desc limit 1) m on true
   order by m.creado_en desc nulls last
$$;

-- Cuántos vecinos confirmaron una alerta, sin exponer quiénes
create function public.confirmaciones_de(p_alerta uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select count(*) from public.sos_confirmaciones where alerta_id = p_alerta
$$;

-- 7. Permisos (tablas y funciones) ------------------------------------
-- Partimos de cero: Supabase concede todo por defecto y aquí se recorta.
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

-- 8. Seguridad por filas (RLS) ----------------------------------------
do $$
declare t text;
begin
  foreach t in array array['zonas','perfiles','categorias_servicio','servicios','servicio_contacto',
    'servicio_trabajos','solicitudes_servicio','recomendaciones','publicaciones','respuestas',
    'mensajes','alertas_sos','sos_respuestas','sos_confirmaciones','recursos_criticos',
    'grupos_apoyo','vecinos_vulnerables','eventos_confianza','notificaciones','auditoria_sos',
    'contactos_utiles','reportes']
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;
alter table privado.config           enable row level security;   -- sin políticas: inaccesibles
alter table privado.pin_credenciales enable row level security;

-- Catálogos
create policy zonas_lectura on public.zonas
  for select to anon, authenticated using (true);
create policy categorias_lectura on public.categorias_servicio
  for select to anon, authenticated using (true);
create policy contactos_lectura on public.contactos_utiles
  for select to anon, authenticated using (true);

-- Perfiles: cada vecino solo ve y edita el suyo (los demás, vía perfiles_publicos_de_mi_zona)
create policy perfiles_propio on public.perfiles
  for select to authenticated using (id = auth.uid());
create policy perfiles_editar on public.perfiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Servicios
create policy servicios_lectura on public.servicios
  for select to authenticated using (zona_id = public.mi_zona());
create policy servicios_crear on public.servicios
  for insert to authenticated with check (proveedor_id = auth.uid() and zona_id = public.mi_zona());
create policy servicios_editar on public.servicios
  for update to authenticated using (proveedor_id = auth.uid()) with check (proveedor_id = auth.uid());
create policy servicios_borrar on public.servicios
  for delete to authenticated using (proveedor_id = auth.uid());

-- Teléfono del servicio: visible a la zona solo si el proveedor lo autorizó
create policy contacto_lectura on public.servicio_contacto
  for select to authenticated
  using (exists (select 1 from public.servicios s
                  where s.id = servicio_contacto.servicio_id
                    and (s.proveedor_id = auth.uid()
                         or (servicio_contacto.autorizado and s.zona_id = public.mi_zona()))));
create policy contacto_crear on public.servicio_contacto
  for insert to authenticated
  with check (exists (select 1 from public.servicios s
                       where s.id = servicio_contacto.servicio_id and s.proveedor_id = auth.uid()));
create policy contacto_editar on public.servicio_contacto
  for update to authenticated
  using (exists (select 1 from public.servicios s
                  where s.id = servicio_contacto.servicio_id and s.proveedor_id = auth.uid()));
create policy contacto_borrar on public.servicio_contacto
  for delete to authenticated
  using (exists (select 1 from public.servicios s
                  where s.id = servicio_contacto.servicio_id and s.proveedor_id = auth.uid()));

create policy trabajos_lectura on public.servicio_trabajos
  for select to authenticated
  using (exists (select 1 from public.servicios s
                  where s.id = servicio_trabajos.servicio_id and s.zona_id = public.mi_zona()));
create policy trabajos_crear on public.servicio_trabajos
  for insert to authenticated
  with check (exists (select 1 from public.servicios s
                       where s.id = servicio_trabajos.servicio_id and s.proveedor_id = auth.uid()));
create policy trabajos_borrar on public.servicio_trabajos
  for delete to authenticated
  using (exists (select 1 from public.servicios s
                  where s.id = servicio_trabajos.servicio_id and s.proveedor_id = auth.uid()));

-- Solicitudes de servicio: las ven el solicitante y el proveedor; el estado se cambia por RPC
create policy solicitudes_lectura on public.solicitudes_servicio
  for select to authenticated
  using (solicitante_id = auth.uid()
         or exists (select 1 from public.servicios s
                     where s.id = solicitudes_servicio.servicio_id and s.proveedor_id = auth.uid()));
create policy solicitudes_crear on public.solicitudes_servicio
  for insert to authenticated
  with check (solicitante_id = auth.uid() and estado = 'solicitada'
              and exists (select 1 from public.servicios s
                           where s.id = solicitudes_servicio.servicio_id and s.activo
                             and s.proveedor_id <> auth.uid() and s.zona_id = public.mi_zona()));

-- Visto Bueno Vecinal: solo vecinos de la zona que usaron el servicio (solicitud 'completada')
create policy recomendaciones_lectura on public.recomendaciones
  for select to authenticated
  using (exists (select 1 from public.servicios s
                  where s.id = recomendaciones.servicio_id and s.zona_id = public.mi_zona()));
create policy recomendaciones_crear on public.recomendaciones
  for insert to authenticated
  with check (autor_id = auth.uid()
              and exists (select 1 from public.servicios s
                           where s.id = recomendaciones.servicio_id and s.proveedor_id <> auth.uid()
                             and s.zona_id = public.mi_zona())
              and exists (select 1 from public.solicitudes_servicio ss
                           where ss.servicio_id = recomendaciones.servicio_id
                             and ss.solicitante_id = auth.uid() and ss.estado = 'completada'));
create policy recomendaciones_editar on public.recomendaciones
  for update to authenticated using (autor_id = auth.uid()) with check (autor_id = auth.uid());
create policy recomendaciones_borrar on public.recomendaciones
  for delete to authenticated using (autor_id = auth.uid());

-- Muro de favores
create policy publicaciones_lectura on public.publicaciones
  for select to authenticated using (zona_id = public.mi_zona());
create policy publicaciones_editar on public.publicaciones
  for update to authenticated using (autor_id = auth.uid()) with check (autor_id = auth.uid());
create policy publicaciones_borrar on public.publicaciones
  for delete to authenticated using (autor_id = auth.uid());

create policy respuestas_lectura on public.respuestas
  for select to authenticated
  using (receptor_id = auth.uid()
         or exists (select 1 from public.publicaciones p
                     where p.id = respuestas.publicacion_id and p.autor_id = auth.uid()));
create policy respuestas_crear on public.respuestas
  for insert to authenticated
  with check (receptor_id = auth.uid()
              and exists (select 1 from public.publicaciones p
                           where p.id = respuestas.publicacion_id and p.autor_id <> auth.uid()
                             and p.zona_id = public.mi_zona()
                             and p.estado in ('abierta', 'en_coordinacion')));
create policy respuestas_aceptar on public.respuestas
  for update to authenticated
  using (exists (select 1 from public.publicaciones p
                  where p.id = respuestas.publicacion_id and p.autor_id = auth.uid()));
create policy respuestas_borrar on public.respuestas
  for delete to authenticated using (receptor_id = auth.uid());

-- Chat 1 a 1
create policy mensajes_lectura on public.mensajes
  for select to authenticated
  using ((respuesta_id is not null and public.participa_respuesta(respuesta_id))
      or (ayuda_id     is not null and public.participa_ayuda(ayuda_id)));
create policy mensajes_crear on public.mensajes
  for insert to authenticated
  with check (autor_id = auth.uid()
              and ((respuesta_id is not null and public.participa_respuesta(respuesta_id))
                or (ayuda_id     is not null and public.participa_ayuda(ayuda_id))));

-- SOS: las alertas no se editan directamente; se cierran con RPC
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

-- Confianza, notificaciones, auditoría y reportes
create policy confianza_propia on public.eventos_confianza
  for select to authenticated using (perfil_id = auth.uid());
create policy confianza_admin on public.eventos_confianza
  for select to authenticated using (public.mi_rol() = 'admin');

create policy notif_propias on public.notificaciones
  for select to authenticated using (perfil_id = auth.uid());
create policy notif_marcar on public.notificaciones
  for update to authenticated using (perfil_id = auth.uid()) with check (perfil_id = auth.uid());

create policy auditoria_admin on public.auditoria_sos
  for select to authenticated using (public.mi_rol() = 'admin');

create policy reportes_crear on public.reportes
  for insert to authenticated with check (autor_id = auth.uid());
create policy reportes_propios on public.reportes
  for select to authenticated using (autor_id = auth.uid());
create policy reportes_admin_lectura on public.reportes
  for select to authenticated using (public.mi_rol() = 'admin');
create policy reportes_admin_editar on public.reportes
  for update to authenticated using (public.mi_rol() = 'admin')
  with check (public.mi_rol() = 'admin');

-- 9. Tiempo real ------------------------------------------------------
do $$
declare t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    execute 'create publication supabase_realtime';
  end if;
  foreach t in array array['publicaciones','respuestas','mensajes','alertas_sos',
                           'sos_respuestas','recursos_criticos','notificaciones']
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;   -- ya estaba agregada
    end;
  end loop;
end $$;

-- =====================================================================

-- VeciPulso, complemento v5 (original).
-- VeciPulso · Migración 002 · Completar el modelo (v5)
-- Se aplica DESPUÉS de 001_esquema_base.sql.
--
-- QUÉ AGREGA
--   · Favoritos / guardados (publicaciones y servicios)
--   · Comentarios en publicaciones (distintos de las respuestas)
--   · Membresía de brigadas y grupos (unirse / salir)
--   · Mensajes leídos: badge real de no leídos por conversación
--   · Préstamos: a quién se prestó y cuándo se devolvió
--   · Dispositivos push (tokens por vecino)
--   · Borrado de cuenta (derecho al olvido)
--   · Limpieza programada de datos viejos (pg_cron, si está disponible)
--   · Políticas de Storage para avatares y fotos de trabajos (si existe storage)
--   · Un vecino puede volver a ofrecer ayuda tras cancelar
--
-- SIGUE PENDIENTE Y ES DELIBERADO
--   · Envío real de push (eso es Edge Function / backend, no SQL)
--   · Verificación de identidad con RENIEC (requiere servicio externo)
--   · Zonas como polígono (hoy círculo: centro + radio)
--   · Panel admin completo (suspender usuario, ocultar contenido)
-- =====================================================================

-- ---------------------------------------------------------------------
-- A. Tablas nuevas
-- ---------------------------------------------------------------------

-- Favoritos: sirve para publicaciones del muro y para servicios
create table public.favoritos (
  id             uuid primary key default gen_random_uuid(),
  perfil_id      uuid not null references public.perfiles(id) on delete cascade,
  publicacion_id uuid references public.publicaciones(id) on delete cascade,
  servicio_id    uuid references public.servicios(id)     on delete cascade,
  creado_en      timestamptz not null default now(),
  check (num_nonnulls(publicacion_id, servicio_id) = 1)
);

-- Comentarios dentro de una publicación (las respuestas son 1 a 1 y abren chat)
create table public.comentarios_publicacion (
  id             uuid primary key default gen_random_uuid(),
  publicacion_id uuid not null references public.publicaciones(id) on delete cascade,
  autor_id       uuid not null references public.perfiles(id)     on delete cascade,
  texto          text not null check (char_length(texto) between 1 and 500),
  creado_en      timestamptz not null default now()
);

-- Membresía de brigadas (pantalla 09: unirse a un grupo de la zona)
create table public.grupo_miembros (
  grupo_id  uuid not null references public.grupos_apoyo(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id)     on delete cascade,
  rol       text not null default 'integrante' check (rol in ('integrante', 'lider')),
  estado    text not null default 'activo'     check (estado in ('activo', 'inactivo')),
  creado_en timestamptz not null default now(),
  primary key (grupo_id, perfil_id)
);

-- Tokens de notificación push (el envío lo hace el backend, aquí solo se guardan)
create table public.dispositivos_push (
  id             uuid primary key default gen_random_uuid(),
  perfil_id      uuid not null references public.perfiles(id) on delete cascade,
  token          text not null unique,
  plataforma     text not null check (plataforma in ('android', 'ios', 'web')),
  actualizado_en timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- B. Columnas nuevas
-- ---------------------------------------------------------------------

-- Mensajes leídos: permite el badge "no leídos" por conversación
alter table public.mensajes add column leido_en timestamptz;

-- Préstamos: quién lo recibió y cuándo volvió
alter table public.publicaciones add column prestado_a  uuid references public.perfiles(id) on delete set null;
alter table public.publicaciones add column devuelto_en timestamptz;
alter table public.publicaciones
  add constraint chk_prestamo check (
    tipo = 'prestamo' or (prestado_a is null and devuelto_en is null)
  );

-- ---------------------------------------------------------------------
-- C. Un vecino puede volver a ofrecer ayuda después de cancelar
-- ---------------------------------------------------------------------
alter table public.sos_respuestas
  drop constraint if exists sos_respuestas_alerta_id_voluntario_id_key;
create unique index if not exists uq_sos_resp_activa
  on public.sos_respuestas (alerta_id, voluntario_id)
  where estado <> 'cancelada';

-- ---------------------------------------------------------------------
-- D. Índices
-- ---------------------------------------------------------------------
create unique index if not exists uq_fav_publicacion
  on public.favoritos (perfil_id, publicacion_id) where publicacion_id is not null;
create unique index if not exists uq_fav_servicio
  on public.favoritos (perfil_id, servicio_id)    where servicio_id is not null;
create index if not exists idx_fav_perfil
  on public.favoritos (perfil_id, creado_en desc);

create index if not exists idx_comentarios_pub
  on public.comentarios_publicacion (publicacion_id, creado_en);
create index if not exists idx_comentarios_autor
  on public.comentarios_publicacion (autor_id);

create index if not exists idx_grupo_miembros_perfil
  on public.grupo_miembros (perfil_id);

create index if not exists idx_push_perfil
  on public.dispositivos_push (perfil_id);

create index if not exists idx_mensajes_no_leidos
  on public.mensajes (respuesta_id, ayuda_id)
  where leido_en is null;

-- ---------------------------------------------------------------------
-- E. Funciones nuevas
-- ---------------------------------------------------------------------

-- Marca como leídos los mensajes de una conversación (favor o ayuda SOS)
create function public.marcar_conversacion_leida(p_tipo text, p_ref uuid)
returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if auth.uid() is null then raise exception 'Se requiere sesión'; end if;

  if p_tipo = 'favor' then
    if not public.participa_respuesta(p_ref) then raise exception 'No autorizado'; end if;
    update public.mensajes set leido_en = now()
     where respuesta_id = p_ref and autor_id <> auth.uid() and leido_en is null;
  elsif p_tipo = 'sos' then
    if not public.participa_ayuda(p_ref) then raise exception 'No autorizado'; end if;
    update public.mensajes set leido_en = now()
     where ayuda_id = p_ref and autor_id <> auth.uid() and leido_en is null;
  else
    raise exception 'Tipo de conversación no válido';
  end if;

  get diagnostics n = row_count;
  return n;
end $$;

-- Total de mensajes sin leer (badge del menú lateral)
create function public.no_leidos() returns bigint
language sql stable security definer set search_path = public as $$
  select count(*)
    from public.mensajes m
   where m.autor_id <> auth.uid()
     and m.leido_en is null
     and ((m.respuesta_id is not null and public.participa_respuesta(m.respuesta_id))
       or (m.ayuda_id     is not null and public.participa_ayuda(m.ayuda_id)))
$$;

-- v2 de la lista de conversaciones: agrega el contador de no leídos
drop function if exists public.mis_conversaciones();
create function public.mis_conversaciones()
returns table (tipo text, ref_id uuid, titulo text, contraparte text,
               ultimo_mensaje text, ultimo_en timestamptz, no_leidos bigint)
language sql stable security definer set search_path = public as $$
  with conv as (
    select 'favor'::text as tipo, r.id as ref_id, p.titulo as titulo,
           case when r.receptor_id = auth.uid() then p.autor_id else r.receptor_id end as otro
      from public.respuestas r join public.publicaciones p on p.id = r.publicacion_id
     where r.receptor_id = auth.uid() or p.autor_id = auth.uid()
    union all
    select 'sos', s.id, 'Ayuda SOS: ' || replace(a.tipo::text, '_', ' '),
           case when s.voluntario_id = auth.uid() then a.autor_id else s.voluntario_id end
      from public.sos_respuestas s join public.alertas_sos a on a.id = s.alerta_id
     where s.voluntario_id = auth.uid() or a.autor_id = auth.uid()
  )
  select c.tipo, c.ref_id, c.titulo, po.nombre_publico, m.texto, m.creado_en,
         (select count(*) from public.mensajes mm
           where mm.leido_en is null
             and mm.autor_id <> auth.uid()
             and ((c.tipo = 'favor' and mm.respuesta_id = c.ref_id)
               or (c.tipo = 'sos'   and mm.ayuda_id     = c.ref_id)))
    from conv c
    join public.perfiles po on po.id = c.otro
    left join lateral (
      select mm.texto, mm.creado_en from public.mensajes mm
       where (c.tipo = 'favor' and mm.respuesta_id = c.ref_id)
          or (c.tipo = 'sos'   and mm.ayuda_id     = c.ref_id)
       order by mm.creado_en desc limit 1) m on true
   order by m.creado_en desc nulls last
$$;

-- Registrar el préstamo de un objeto (solo el autor de una publicación "prestamo")
create function public.prestar_publicacion(p_pub uuid, p_receptor uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare v record;
begin
  select tipo, autor_id, estado, zona_id, prestado_a
    into v from public.publicaciones where id = p_pub for update;
  if not found then raise exception 'La publicación no existe'; end if;
  if v.autor_id <> auth.uid() then raise exception 'Solo el autor puede registrar el préstamo'; end if;
  if v.tipo <> 'prestamo' then raise exception 'La publicación no es un préstamo'; end if;
  if v.estado not in ('abierta', 'en_coordinacion') then raise exception 'La publicación ya está cerrada'; end if;
  if p_receptor = auth.uid() then raise exception 'No puedes prestarte a ti mismo'; end if;
  if v.prestado_a is not null then raise exception 'Este préstamo ya fue registrado'; end if;
  if not exists (select 1 from public.perfiles p where p.id = p_receptor and p.zona_id = v.zona_id) then
    raise exception 'El receptor no pertenece a tu zona';
  end if;
  update public.publicaciones
     set prestado_a = p_receptor, estado = 'en_coordinacion'
   where id = p_pub;
end $$;

-- Confirmar la devolución (autor o quien recibió el préstamo)
create function public.marcar_devuelto(p_pub uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v record;
begin
  select autor_id, tipo, prestado_a, devuelto_en
    into v from public.publicaciones where id = p_pub for update;
  if not found then raise exception 'La publicación no existe'; end if;
  if v.autor_id <> auth.uid() and v.prestado_a is distinct from auth.uid() then
    raise exception 'No autorizado';
  end if;
  if v.tipo <> 'prestamo' or v.prestado_a is null then
    raise exception 'No hay un préstamo activo en esta publicación';
  end if;
  if v.devuelto_en is not null then raise exception 'El préstamo ya fue devuelto'; end if;

  update public.publicaciones
     set devuelto_en = now(), estado = 'resuelta'
   where id = p_pub;
end $$;

-- Baja de cuenta (derecho al olvido). Borra el perfil y todo lo asociado en cascada.
create function public.borrar_mi_cuenta() returns void
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Se requiere sesión'; end if;

  -- La auditoría se conserva sin identificar a la persona
  update public.auditoria_sos set actor_id = null where actor_id = v_uid;
  delete from public.auditoria_sos
   where alerta_id in (select id from public.alertas_sos where autor_id = v_uid);

  -- El resto cae por las claves foráneas: perfil, servicios, publicaciones,
  -- respuestas, mensajes, ayudas, notificaciones, favoritos, push, PIN...
  delete from auth.users where id = v_uid;
end $$;

-- Limpieza de datos viejos. Vive en privado: la app no la puede llamar.
create function privado.limpiar_datos() returns jsonb
language plpgsql security definer set search_path = public, privado as $$
declare
  n_notif int; n_pubs int; n_alertas int; n_tokens int; n_msg int;
begin
  delete from public.notificaciones
   where leida and creado_en < now() - interval '30 days';
  get diagnostics n_notif = row_count;

  delete from public.publicaciones
   where vence_en < now() - interval '30 days';
  get diagnostics n_pubs = row_count;

  delete from public.alertas_sos
   where cerrado_en is not null and cerrado_en < now() - interval '90 days';
  get diagnostics n_alertas = row_count;

  delete from public.dispositivos_push
   where actualizado_en < now() - interval '60 days';
  get diagnostics n_tokens = row_count;

  delete from public.mensajes
   where leido_en is not null and leido_en < now() - interval '90 days';
  get diagnostics n_msg = row_count;

  return jsonb_build_object('notificaciones', n_notif, 'publicaciones', n_pubs,
                            'alertas', n_alertas, 'tokens', n_tokens, 'mensajes', n_msg);
end $$;

-- Límite de comentarios por hora (reusa la función tg_limite de la 001)
create trigger tg_limite before insert on public.comentarios_publicacion
  for each row execute function public.tg_limite('public.comentarios_publicacion', 'autor_id', '60');

-- ---------------------------------------------------------------------
-- F. Permisos
-- ---------------------------------------------------------------------
-- Solo sobre las tablas nuevas: no se repite el "revoke all" general.
revoke all on public.favoritos, public.comentarios_publicacion,
              public.grupo_miembros, public.dispositivos_push
  from anon, authenticated;

grant select on public.favoritos, public.comentarios_publicacion,
                public.grupo_miembros, public.dispositivos_push
  to authenticated;

grant insert on public.favoritos, public.comentarios_publicacion,
                public.grupo_miembros, public.dispositivos_push
  to authenticated;
grant delete on public.favoritos, public.comentarios_publicacion,
                public.grupo_miembros, public.dispositivos_push
  to authenticated;
grant update (token, plataforma, actualizado_en) on public.dispositivos_push to authenticated;
grant update (leido_en)                          on public.mensajes          to authenticated;

-- Funciones nuevas: sin acceso anónimo, y el registro directo sigue cerrado
revoke execute on all functions in schema public from public, anon;
grant  execute on all functions in schema public to authenticated;
revoke execute on function public.registrar_perfil(text, text, uuid, boolean) from authenticated;

-- ---------------------------------------------------------------------
-- G. RLS de las tablas nuevas
-- ---------------------------------------------------------------------
alter table public.favoritos              enable row level security;
alter table public.comentarios_publicacion enable row level security;
alter table public.grupo_miembros         enable row level security;
alter table public.dispositivos_push      enable row level security;

-- Favoritos: cada vecino ve y gestiona los suyos; solo de su zona
create policy favoritos_lectura on public.favoritos
  for select to authenticated using (perfil_id = auth.uid());
create policy favoritos_crear on public.favoritos
  for insert to authenticated
  with check (perfil_id = auth.uid()
    and ((publicacion_id is not null
          and exists (select 1 from public.publicaciones p
                       where p.id = favoritos.publicacion_id and p.zona_id = public.mi_zona()))
      or (servicio_id is not null
          and exists (select 1 from public.servicios s
                       where s.id = favoritos.servicio_id and s.zona_id = public.mi_zona()))));
create policy favoritos_borrar on public.favoritos
  for delete to authenticated using (perfil_id = auth.uid());

-- Comentarios: visibles para la zona; se borran solo los propios
create policy comentarios_lectura on public.comentarios_publicacion
  for select to authenticated
  using (exists (select 1 from public.publicaciones p
                  where p.id = comentarios_publicacion.publicacion_id
                    and p.zona_id = public.mi_zona()));
create policy comentarios_crear on public.comentarios_publicacion
  for insert to authenticated
  with check (autor_id = auth.uid()
    and exists (select 1 from public.publicaciones p
                 where p.id = comentarios_publicacion.publicacion_id
                   and p.zona_id = public.mi_zona()
                   and p.estado <> 'cancelada'));
create policy comentarios_borrar on public.comentarios_publicacion
  for delete to authenticated using (autor_id = auth.uid());

-- Brigadas: se ve la membresía de los grupos de mi zona; cada uno se une y sale solo
create policy miembros_lectura on public.grupo_miembros
  for select to authenticated
  using (perfil_id = auth.uid()
    or exists (select 1 from public.grupos_apoyo g
                where g.id = grupo_miembros.grupo_id and g.zona_id = public.mi_zona()));
create policy miembros_crear on public.grupo_miembros
  for insert to authenticated
  with check (perfil_id = auth.uid()
    and exists (select 1 from public.grupos_apoyo g
                 where g.id = grupo_miembros.grupo_id and g.zona_id = public.mi_zona()));
create policy miembros_borrar on public.grupo_miembros
  for delete to authenticated using (perfil_id = auth.uid());

-- Push: cada vecino gestiona sus propios tokens
create policy push_propios on public.dispositivos_push
  for select to authenticated using (perfil_id = auth.uid());
create policy push_crear on public.dispositivos_push
  for insert to authenticated with check (perfil_id = auth.uid());
create policy push_editar on public.dispositivos_push
  for update to authenticated using (perfil_id = auth.uid()) with check (perfil_id = auth.uid());
create policy push_borrar on public.dispositivos_push
  for delete to authenticated using (perfil_id = auth.uid());

-- Mensajes: solo el destinatario puede marcarlos como leídos
create policy mensajes_marcar_leido on public.mensajes
  for update to authenticated
  using (autor_id <> auth.uid()
    and ((respuesta_id is not null and public.participa_respuesta(respuesta_id))
      or (ayuda_id     is not null and public.participa_ayuda(ayuda_id))))
  with check (autor_id <> auth.uid()
    and ((respuesta_id is not null and public.participa_respuesta(respuesta_id))
      or (ayuda_id     is not null and public.participa_ayuda(ayuda_id))));

-- ---------------------------------------------------------------------
-- H. Tiempo real: los comentarios también se transmiten
-- ---------------------------------------------------------------------
do $do$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      execute 'alter publication supabase_realtime add table public.comentarios_publicacion';
    exception when duplicate_object then null;
    end;
  end if;
end $do$;

-- ---------------------------------------------------------------------
-- I. Storage (solo en Supabase; si no existe el esquema, se omite)
--    Convención: <bucket>/<uuid-del-vecino>/archivo.jpg
-- ---------------------------------------------------------------------
do $do$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public)
    values ('avatares', 'avatares', true), ('trabajos', 'trabajos', true)
    on conflict (id) do nothing;

    execute $p$ drop policy if exists avatares_lectura on storage.objects $p$;
    execute $p$ create policy avatares_lectura on storage.objects
                 for select to public using (bucket_id = 'avatares') $p$;
    execute $p$ drop policy if exists avatares_subir on storage.objects $p$;
    execute $p$ create policy avatares_subir on storage.objects
                 for insert to authenticated
                 with check (bucket_id = 'avatares'
                             and (storage.foldername(name))[1] = auth.uid()::text) $p$;
    execute $p$ drop policy if exists avatares_editar on storage.objects $p$;
    execute $p$ create policy avatares_editar on storage.objects
                 for update to authenticated
                 using (bucket_id = 'avatares'
                        and (storage.foldername(name))[1] = auth.uid()::text) $p$;
    execute $p$ drop policy if exists avatares_borrar on storage.objects $p$;
    execute $p$ create policy avatares_borrar on storage.objects
                 for delete to authenticated
                 using (bucket_id = 'avatares'
                        and (storage.foldername(name))[1] = auth.uid()::text) $p$;

    execute $p$ drop policy if exists trabajos_lectura on storage.objects $p$;
    execute $p$ create policy trabajos_lectura on storage.objects
                 for select to public using (bucket_id = 'trabajos') $p$;
    execute $p$ drop policy if exists trabajos_subir on storage.objects $p$;
    execute $p$ create policy trabajos_subir on storage.objects
                 for insert to authenticated
                 with check (bucket_id = 'trabajos'
                             and (storage.foldername(name))[1] = auth.uid()::text) $p$;
    execute $p$ drop policy if exists trabajos_borrar on storage.objects $p$;
    execute $p$ create policy trabajos_borrar on storage.objects
                 for delete to authenticated
                 using (bucket_id = 'trabajos'
                        and (storage.foldername(name))[1] = auth.uid()::text) $p$;
  end if;
end $do$;

-- ---------------------------------------------------------------------
-- J. Limpieza programada (solo si pg_cron está habilitado en el proyecto)
--    Si no, se puede llamar a mano: select privado.limpiar_datos();
-- ---------------------------------------------------------------------
do $do$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      perform cron.unschedule('vecipulso-limpieza');
    exception when others then null;
    end;
    begin
      perform cron.schedule('vecipulso-limpieza', '0 3 * * *',
                            'select privado.limpiar_datos()');
    exception when others then
      raise notice 'No se pudo programar la limpieza: %', sqlerrm;
    end;
  end if;
end $do$;

-- ---------------------------------------------------------------------
-- K. Verificación rápida de esta migración
-- ---------------------------------------------------------------------
-- select count(*) from information_schema.tables
--  where table_schema = 'public' and table_type = 'BASE TABLE';        -- 26
-- select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
--  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;  -- 0
-- select has_function_privilege('anon', 'public.mis_conversaciones()', 'EXECUTE');  -- false
-- =====================================================================

-- =====================================================================
-- VeciPulso · Parche MVP 004
-- Aplicar solo DESPUES de instalar 001 + 002.
-- Corrige permisos y transiciones de negocio para demo de hackathon.
-- No toca datos, no elimina tablas, no requiere Flutter.
-- =====================================================================

-- 1. Una respuesta no se puede autoaceptar; solo autor de publicacion puede aceptar.
drop policy if exists respuestas_crear on public.respuestas;
create policy respuestas_crear on public.respuestas
for insert to authenticated with check (
  receptor_id = auth.uid() and aceptada = false
  and exists (
    select 1 from public.publicaciones p
    where p.id = respuestas.publicacion_id
      and p.autor_id <> auth.uid()
      and p.zona_id = public.mi_zona()
      and p.estado in ('abierta','en_coordinacion')
  )
);
-- Para el flujo de MVP, una publicacion solo tiene una respuesta aceptada.
create unique index if not exists uq_respuesta_aceptada_mvp
  on public.respuestas (publicacion_id) where aceptada = true;

-- 2. No permitir varias ayudas seleccionadas a la vez en un mismo SOS.
-- El bloqueo de fila de la alerta en la RPC serializa aceptaciones simultaneas.
create unique index if not exists uq_ayuda_sos_seleccionada_mvp
  on public.sos_respuestas (alerta_id)
  where estado in ('aceptada', 'en_camino');

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

-- 3. No permitir confirmar alertas cerradas o de otra zona.
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

-- 5. Endurecimiento de validacion de ubicaciones en RPC de creacion.
-- Ambas funciones siguen conservando su firma original para Flutter.

create or replace function public.publicar_rapido(
  p_id uuid, p_tipo tipo_publicacion, p_titulo text,
  p_detalle text default null, p_categoria categoria_favor default 'otro',
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


  -- Reintento de la cola offline: mismo id, mismo autor => devolver el existente
  if exists (select 1 from public.publicaciones where id = p_id) then
    if exists (select 1 from public.publicaciones where id = p_id and autor_id = v_uid) then
      return p_id;
    end if;
    raise exception 'Identificador en uso';
  end if;
  if p_lat is not null and p_lng is not null then
    v_pt := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;
    -- Fuera del barrio: se usa el centro del barrio (el trigger lo completa)
    if not exists (select 1 from public.zonas z where z.id = v_zona and ST_DWithin(z.centro, v_pt, z.radio_m * 2)) then
      v_pt := null;
    end if;
  end if;
  insert into public.publicaciones (id, autor_id, tipo, categoria, titulo, detalle, zona_id, ubicacion_aprox, creado_local)
  values (p_id, v_uid, p_tipo, p_categoria, p_titulo, p_detalle, v_zona, v_pt, v_creado);
  return p_id;
end $$;

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

-- 6. Comprobar que pgcrypto sea visible para las funciones PIN y HMAC.
-- El script v5 espera pgcrypto en extensions: no continuar silenciosamente si no es asi.
do $$
declare v_schema text;
begin
  select n.nspname into v_schema
    from pg_extension e join pg_namespace n on n.oid = e.extnamespace
    where e.extname = 'pgcrypto';
  if v_schema is distinct from 'extensions' then
    raise exception 'pgcrypto debe encontrarse en extensions (esquema actual: %). Revise Database > Extensions.', coalesce(v_schema, 'no instalado');
  end if;
end $$;

-- 7. No conceder acceso publico a funciones nuevas del parche.
revoke execute on all functions in schema public from public, anon;
grant execute on function public.actualizar_ayuda(uuid, public.estado_ayuda) to authenticated;
grant execute on function public.publicar_rapido(uuid,public.tipo_publicacion,text,text,public.categoria_favor,double precision,double precision,timestamptz) to authenticated;
grant execute on function public.emitir_alerta(uuid,public.clase_alerta,public.tipo_emergencia,public.urgencia_alerta,text,double precision,double precision,timestamptz) to authenticated;
revoke execute on function public.registrar_perfil(text,text,uuid,boolean) from authenticated;

-- SOLO DESARROLLO / DEMO. Ejecute por separado una vez instalado el esquema.
-- Migración 003 de 003 · Datos de demostración (solo desarrollo)
-- NO ejecutar en producción: crea un barrio ficticio, categorías,
-- teléfonos de emergencia y brigadas de ejemplo.
-- =====================================================================
-- 10. Datos base (no dependen de usuarios) -----------------------------
-- Cambia estas coordenadas por las de tu zona de prueba: el GPS del celular
-- debe quedar dentro de ~2 km del centro para que las distancias tengan sentido.
insert into public.zonas (nombre, sector, centro, radio_m)
values ('Barrio Los Álamos', 'Demo',
        extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0428, -12.0464), 4326)::extensions.geography, 2000);

insert into public.categorias_servicio (nombre, icono) values
  ('Gasfitería', 'plumbing'), ('Electricidad', 'bolt'), ('Carpintería', 'carpenter'),
  ('Cerrajería', 'lock'), ('Clases particulares', 'school'), ('Cocina', 'restaurant'),
  ('Jardinería', 'yard');

-- Números nacionales de emergencia de Perú. VERIFÍCALOS antes de la demo pública.
insert into public.contactos_utiles (nombre, telefono, tipo, orden) values
  ('Policía Nacional',            '105', 'oficial', 1),
  ('Bomberos',                    '116', 'oficial', 2),
  ('SAMU (emergencias médicas)',  '106', 'oficial', 3),
  ('INDECI / Defensa Civil',      '115', 'oficial', 4);

-- Brigadas y grupos de la pantalla 09 (datos DEMO, ficticios)
insert into public.grupos_apoyo (zona_id, nombre, tipo, especialidad, sector, integrantes, contacto, ubicacion_aprox)
select z.id, g.nombre, g.tipo::tipo_grupo, g.especialidad, g.sector, g.integrantes, null,
       extensions.ST_Translate(z.centro::extensions.geometry, g.dx, g.dy)::extensions.geography
  from public.zonas z,
       (values ('Brigada Los Álamos',   'brigada',    'Seguridad vecinal', 'Cuadra 1–5',   12,  0.004,  0.003),
               ('Grupo El Progreso',    'voluntarios','General',           'Cuadra 6–10',   8, -0.005,  0.002),
               ('Equipo Salud Vecinal', 'voluntarios','Salud',             'Cuadra 11–15',  6,  0.002, -0.005),
               ('Movilidad Solidaria',  'voluntarios','Movilidad',         'Cuadra 16–20', 11, -0.003, -0.004))
       as g(nombre, tipo, especialidad, sector, integrantes, dx, dy)
 where z.nombre = 'Barrio Los Álamos';

-- =====================================================================
-- 11. PRUEBAS RÁPIDAS (opcional, ejecutar por separado en el SQL Editor)
-- =====================================================================
-- a) El esquema quedó bien instalado:
--    select count(*) as tablas from information_schema.tables
--     where table_schema='public' and table_type='BASE TABLE';   -- esperado: 22
--
-- b) Ninguna tabla de public quedó sin RLS:
--    select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
--     where n.nspname='public' and c.relkind='r' and not c.relrowsecurity;  -- 0 filas
--
-- c) Ninguna función de public ejecutable por PUBLIC/anon:
--    select p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
--     where n.nspname='public' and has_function_privilege('anon', p.oid, 'EXECUTE');
--    -- solo podría salir "registrar_perfil" si te equivocaste al revocar; debe ser 0.
--
-- d) Toda función security definer tiene search_path fijo:
--    select p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
--     where n.nspname='public' and p.prosecdef
--       and not exists (select 1 from unnest(coalesce(p.proconfig,'{}')) x where x like 'search_path=%');
--    -- 0 filas
--
-- e) Flujo completo con un usuario real (desde la app o con la sesión anónima):
--    select public.registrar_completo('12345678','Juan Perez',
--           (select id from public.zonas limit 1), true, '246813');
--    select public.verificar_pin('246813');                       -- {"ok": true}
--    select public.emitir_alerta(gen_random_uuid(),'soporte','agua_alimentos','urgente','Falta agua');
--    select * from public.alertas_cercanas(-12.0464, -77.0428);   -- 1 alerta, sin_verificar
--
-- f) Búsqueda sin tildes:
--    select * from public.buscar_servicios_cercanos(-12.0464, -77.0428, 3000, 'gasfiteria');
--
-- g) Dar rol de admin (no hay flujo en la app, se hace a mano):
--    update public.perfiles set rol='admin' where id = '<uuid-del-perfil>';
--
-- =====================================================================

commit;
