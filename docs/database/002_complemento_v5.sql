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
