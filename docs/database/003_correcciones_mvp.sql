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
