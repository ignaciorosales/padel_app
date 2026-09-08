-- =============================================================================
-- Puntazo · 0017 · Las políticas que le faltaban a tournament_pairs
-- =============================================================================
-- La 0006 creó la tabla de parejas y se dejó sus políticas. Trece migraciones
-- después, el torneo de parejas estaba muerto en la base de datos y nadie se
-- había enterado: apuntar una pareja desde el panel devolvía
--
--     new row violates row-level security policy for table "tournament_pairs"
--
-- y la página pública de un torneo de parejas enseñaba los cruces sin nombres,
-- porque leer tampoco se podía.
--
-- POR QUÉ NO SALTÓ ANTES
-- ----------------------
-- Una tabla con RLS activado y CERO políticas no da error al crearse, ni al
-- migrar, ni al arrancar la aplicación, ni en los tests —que son todos de
-- TypeScript puro y no tocan Postgres—. Sólo falla cuando alguien intenta
-- escribir de verdad, y en este caso eso fue la primera vez que se probó a
-- mano un formato que hasta hoy sólo se había ejercitado en americano.
--
-- El resto de tablas sí las tienen: la 0001, la 0003 y la 0012 cierran las
-- suyas. Ésta se quedó sola, y el hueco duró desde la 0006.
--
-- Al final del fichero se añade una función que hace visible este agujero para
-- que la próxima vez lo cante `npm run comprobar` y no un sábado por la mañana.
-- =============================================================================

-- Idempotente y a propósito: en este proyecto la tabla ya tenía RLS activado
-- —Supabase lo pone en las tablas nuevas del esquema público— pero eso no está
-- escrito en ninguna migración, así que sobre una base recién montada podría no
-- estarlo. Y sin RLS la tabla no es que fallara: es que la leería cualquiera.
alter table public.tournament_pairs enable row level security;

-- ---- lectura ----
-- Dos políticas por rol, con la misma forma que dejó la 0013 en
-- `tournament_players`: cada una dice a quién deja pasar en vez de mezclar el
-- club y el anónimo en un `or` que hay que leer dos veces.

drop policy if exists "ver parejas del club" on public.tournament_pairs;
create policy "ver parejas del club"
  on public.tournament_pairs for select
  to authenticated
  using (public.can_read_club(public.club_de_torneo(tournament_id)));

-- La página pública las necesita: sin esto, un torneo de parejas publica un
-- cuadro donde todas las parejas se llaman «—».
drop policy if exists "ver parejas de un torneo público" on public.tournament_pairs;
create policy "ver parejas de un torneo público"
  on public.tournament_pairs for select
  to anon
  using (public.torneo_es_publico(tournament_id));

-- ---- escritura ----
-- Por `can_write_club()`, como todo lo demás: es la puerta única del corte por
-- impago, y una tabla que se la salte deja un club suspendido escribiendo.
drop policy if exists "el club gestiona sus parejas" on public.tournament_pairs;
create policy "el club gestiona sus parejas"
  on public.tournament_pairs for all
  to authenticated
  using (public.can_write_club(public.club_de_torneo(tournament_id)))
  with check (public.can_write_club(public.club_de_torneo(tournament_id)));

-- =============================================================================
-- Que esto no se pueda volver a colar
-- =============================================================================
-- Una tabla con RLS y sin políticas es invisible hasta que alguien intenta
-- usarla. Esta función la saca a la luz, y `npm run comprobar` la llama: el
-- mismo sitio donde ya se verifica que las tablas existen y que RLS bloquea al
-- anónimo.
--
-- Sólo devuelve nombres de tabla, pero eso ya es información del esquema, así
-- que no se le deja al anónimo.
create or replace function public.tablas_sin_politicas()
returns table (tabla text)
language sql
stable
security definer
set search_path = public
as $$
  select c.relname::text
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'r'
    and c.relrowsecurity
    and not exists (select 1 from pg_policy p where p.polrelid = c.oid)
  order by 1;
$$;

revoke execute on function public.tablas_sin_politicas() from anon;

comment on function public.tablas_sin_politicas() is
  'Tablas con RLS activado y ninguna política: nadie puede leerlas ni escribirlas, y no avisan. Así se coló tournament_pairs desde la 0006 hasta la 0017.';
