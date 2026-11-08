-- VeciPulso MVP · COMPROBACIONES SIN EFECTOS COLATERALES
-- EJECUTE DESPUES de la instalacion unica; no crea usuarios.
-- Cada consulta debe interpretarse junto con su resultado.

-- A. Esperado: 26 tablas de aplicacion en public.
select count(*) as public_tablas from information_schema.tables
 where table_schema='public' and table_type='BASE TABLE';

-- B. Esperado: 0 tablas de public sin RLS.
select tablename from pg_tables
where schemaname='public' and not rowsecurity;

-- C. Esperado: 0 funciones ejecutables por anon.
select p.proname as funcion_insegura from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname='public' and has_function_privilege('anon',p.oid,'EXECUTE');

-- D. Esperado: 1 fila con postgis y pgcrypto ambos en extensions.
select extname, n.nspname as esquema
 from pg_extension e join pg_namespace n on n.oid=e.extnamespace
 where extname in ('postgis','pgcrypto','unaccent');

-- E. Esperado: filas con publicaciones, mensajes, alertas_sos, respuestas...
select pubname, schemaname, tablename
 from pg_publication_tables where pubname='supabase_realtime'
 order by tablename;

-- F. Esperado: 1 zona DEMO en base sin datos reales; sustituir antes de produccion.
select id, nombre, radio_m,
  extensions.ST_Y(centro::extensions.geometry) as lat,
  extensions.ST_X(centro::extensions.geometry) as lng
 from public.zonas order by nombre;

-- G. Esperado: false (sin permiso para registrar sin PIN con RPC interno).
select has_function_privilege('authenticated',
  'public.registrar_perfil(text,text,uuid,boolean)', 'EXECUTE') as registro_sin_pin_permitido;

-- H. Esperado: false (sin permiso de escribir membresia de brigadas por API).
select has_table_privilege('authenticated','public.grupo_miembros','INSERT') as puede_unirse_brigada;

-- I. PRUEBAS DE FLUJO: hacer desde Flutter con DOS sesiones ANONIMAS distintas.
-- 1. signInAnonymously -> registrar_completo -> verificar_pin
-- 2. crear servicio -> solicitud -> completar -> recomendacion
-- 3. publicar_rapido -> respuesta (aceptada false) -> aceptar (solo autor)
-- 4. emitir_alerta -> sos_respuestas -> actualizar_ayuda
-- 5. cancelar UNA ayuda no debe afectar otras respuestas
-- 6. enviar mensaje en chat como participantes -> observar Realtime
-- 7. probar RLS con tercer usuario de otra zona (requiere crear otra zona de prueba)
