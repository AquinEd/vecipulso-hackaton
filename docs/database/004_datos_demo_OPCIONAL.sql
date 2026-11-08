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
