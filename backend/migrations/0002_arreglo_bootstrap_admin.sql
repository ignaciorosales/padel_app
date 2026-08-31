-- =============================================================================
-- Puntazo · 0002 · Arreglo: no se podía nombrar al primer administrador
-- =============================================================================
-- Sólo hace falta si ya ejecutaste la primera versión de 0001_fundacion.sql.
-- En una base de datos nueva, 0001 ya viene con esto corregido y ejecutar este
-- fichero no cambia nada (es `create or replace`).
--
-- El problema: el trigger dejaba pasar el cambio de is_platform_admin cuando
-- `auth.role()` valía 'service_role', suponiendo que el editor SQL de Supabase
-- se identificaba así. No lo hace — entra por conexión directa a Postgres, sin
-- JWT — de modo que ni había rol de servicio ni había administrador todavía, y
-- el propio arranque del sistema quedaba bloqueado:
--
--   ERROR: Sólo un administrador de plataforma puede cambiar is_platform_admin
--
-- La condición correcta es "no hay usuario final detrás". Sigue siendo seguro
-- porque una petición anónima por la API nunca llega a este trigger: la corta
-- antes la política RLS de profiles, que exige id = auth.uid().
-- =============================================================================

create or replace function public.protect_platform_admin_flag()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_platform_admin is distinct from old.is_platform_admin then
    -- Editor SQL, psql, migraciones o clave de servicio: no hay usuario final.
    if auth.uid() is null then
      return new;
    end if;

    if not public.is_platform_admin() then
      raise exception 'Sólo un administrador de plataforma puede cambiar is_platform_admin';
    end if;
  end if;
  return new;
end;
$$;

-- =============================================================================
-- Y ahora sí, nómbrate administrador (cambia el correo por el tuyo):
-- =============================================================================

-- update public.profiles set is_platform_admin = true
-- where id = (select id from auth.users where email = 'tu@correo.com');
