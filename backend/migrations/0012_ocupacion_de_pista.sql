-- =============================================================================
-- Puntazo · 0012 · Ocupación de pista
-- =============================================================================
-- La decisión que está en docs/producto/README.md, en la tabla de decisiones
-- cerradas: el objeto central del modelo es la OCUPACIÓN DE PISTA — una pista,
-- un rango horario y un motivo. Un torneo genera ocupaciones, una clase también,
-- una reserva *es* una. Si está bien puesto, la agenda de la fase 2 es una
-- pantalla nueva; si no, es una reescritura.
--
-- Se pone ahora, con un solo formato de torneo en marcha y ningún club en
-- producción, porque el coste de ponerlo crece con cada torneo guardado.
--
-- LO QUE ESTA MIGRACIÓN NO HACE, A PROPÓSITO
-- ------------------------------------------
-- No toca `matches`. La tentación era sustituir `matches.pista int` por un
-- enlace a la ocupación, y sería un error: `pista` es el número que el
-- organizador ve y cambia a dedo el sábado dentro de SU torneo, y el
-- `unique (round_id, pista)` que lo protege es lo que impide poner dos partidos
-- en la misma pista de la misma ronda. Eso sigue siendo verdad y sigue siendo
-- suyo.
--
-- La ocupación es la otra mitad: dónde cae ese partido en el calendario del
-- CLUB, junto a las clases y las reservas que todavía no existen. El torneo la
-- emite; no depende de ella para funcionar. Por eso el enlace va en sentido
-- ocupación -> partido y no al revés: si se regeneran las rondas, los partidos
-- se borran y las ocupaciones se van detrás en cascada, sin dejar huecos
-- fantasma en la agenda ni necesitar que nadie se acuerde de limpiarlos.
--
-- POR QUÉ `tsrange` Y NO `timestamptz`
-- ------------------------------------
-- Un club opera en hora de pared: el torneo es «el sábado a las 10», no un
-- instante UTC. No hay zona horaria guardada en ningún sitio y meterla ahora
-- sería inventarse un dato. `tsrange` sobre fecha + hora es exactamente lo que
-- ya se guarda hoy en `tournaments.fecha` y `rounds.hora`.
--
-- Cuando haga falta un club en otro huso, se añade `clubs.zona_horaria` y se
-- convierte al leer. Es una columna; volver de `timestamptz` a hora de pared,
-- en cambio, no tiene arreglo bonito.
-- =============================================================================

-- Para el `exclude using gist` de más abajo: gist no sabe comparar uuid por
-- igualdad sin esto. Viene de serie en Supabase.
create extension if not exists btree_gist;

-- ---------------------------------------------------------------- pistas
-- Las pistas de verdad del club, las que tienen nombre en la puerta.
--
-- Hasta ahora una pista era un número dentro de un torneo (`tournaments.pistas`
-- dice cuántas y `matches.pista` cuál). Eso vale para un sábado y no vale para
-- una agenda: «Pista 3» tiene que ser la misma pista el martes en una clase y
-- el sábado en un torneo, o los solapes no se pueden ni detectar.
create table public.courts (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs (id) on delete cascade,
  nombre     text not null check (length(trim(nombre)) > 0),
  orden      int  not null check (orden between 1 and 30),
  -- Una pista en obras no se borra: se apaga. Borrarla se llevaría por delante
  -- el histórico de lo que se jugó en ella.
  activa     boolean not null default true,
  created_at timestamptz not null default now(),
  unique (club_id, orden),
  unique (club_id, nombre)
);

create index courts_club_idx on public.courts (club_id, orden);

-- --------------------------------------------------- pistas de un torneo
-- Qué pista real es «la pista 1» de este torneo.
--
-- Un torneo de 4 pistas en un club de 8 no usa necesariamente las cuatro
-- primeras, y el sábado siguiente puede usar otras. Sin esta tabla, `pista 1`
-- no se puede traducir a una pista del club y la agenda no ve el torneo.
create table public.tournament_courts (
  tournament_id uuid not null references public.tournaments (id) on delete cascade,
  court_id      uuid not null references public.courts (id)      on delete cascade,
  -- El número que ve el organizador: `orden` = `matches.pista`.
  orden         int  not null check (orden between 1 and 30),
  primary key (tournament_id, orden),
  unique (tournament_id, court_id)
);

-- ------------------------------------------------------------- ocupación
create type public.occupancy_reason as enum (
  'torneo',
  'clase',      -- fase 3
  'reserva',    -- fase 2
  'bloqueo'     -- lluvia, obras, mantenimiento: no es de nadie pero ocupa
);

create table public.court_occupancies (
  id         uuid primary key default gen_random_uuid(),
  -- Repetido a propósito: se puede deducir por `court_id`, pero las políticas
  -- RLS y la consulta de la agenda («todo lo del club este día») lo miran en
  -- cada fila. Un join por fila para saber de quién es algo se paga caro.
  club_id    uuid not null references public.clubs (id)  on delete cascade,
  court_id   uuid not null references public.courts (id) on delete cascade,
  durante    tsrange not null,
  motivo     public.occupancy_reason not null,

  -- De dónde sale. Nulos mientras el motivo no los use; cada fase añadirá el
  -- suyo (`class_id`, `booking_id`) sin tocar lo que ya funciona.
  tournament_id uuid references public.tournaments (id) on delete cascade,
  match_id      uuid unique references public.matches (id) on delete cascade,

  nota       text,
  created_at timestamptz not null default now(),

  -- Un rango abierto por un lado ocuparía la pista hasta el fin de los tiempos.
  constraint rango_con_principio_y_fin check (
    lower(durante) is not null and upper(durante) is not null and not isempty(durante)
  ),
  constraint origen_coherente check (
    (motivo = 'torneo' and tournament_id is not null)
    or (motivo <> 'torneo' and tournament_id is null and match_id is null)
  ),

  -- LA razón de ser de la tabla: dos cosas no pueden ocupar la misma pista a la
  -- vez. En la interfaz esto es un aviso amable; aquí es imposible. El día que
  -- alguien reserve por teléfono la pista donde hay un torneo, la base de datos
  -- dice que no aunque la pantalla se haya despistado.
  constraint pista_sin_solapes exclude using gist (
    court_id with =,
    durante  with &&
  )
);

-- La consulta de la agenda: «qué pasa en este club este día».
create index court_occupancies_club_idx
  on public.court_occupancies using gist (club_id, durante);

create index court_occupancies_torneo_idx
  on public.court_occupancies (tournament_id)
  where tournament_id is not null;

comment on table public.court_occupancies is
  'Pista + rango horario + motivo. Objeto central del calendario del club: el torneo la genera, la clase y la reserva la generarán. Ver docs/producto/README.md.';

-- =============================================================================
-- Funciones para las políticas
-- =============================================================================

create or replace function public.club_de_pista(p_pista uuid)
returns uuid
language sql stable security definer set search_path = public
as $$ select c.club_id from public.courts c where c.id = p_pista; $$;

-- =============================================================================
-- RLS
-- =============================================================================
-- Sin puerta pública, al contrario que los torneos: la página que se pega en
-- WhatsApp enseña cruces y clasificación, no la agenda del club. Cuándo está
-- libre una pista es información del negocio.

alter table public.courts             enable row level security;
alter table public.tournament_courts  enable row level security;
alter table public.court_occupancies  enable row level security;

-- ---- courts ----
create policy "ver las pistas del club"
  on public.courts for select
  using (public.can_read_club(club_id));

create policy "el club gestiona sus pistas"
  on public.courts for all
  using (public.can_write_club(club_id))
  with check (public.can_write_club(club_id));

-- ---- tournament_courts ----
create policy "ver las pistas de un torneo del club"
  on public.tournament_courts for select
  using (public.can_read_club(public.club_de_torneo(tournament_id)));

create policy "el club gestiona las pistas de sus torneos"
  on public.tournament_courts for all
  using (public.can_write_club(public.club_de_torneo(tournament_id)))
  with check (public.can_write_club(public.club_de_torneo(tournament_id)));

-- ---- court_occupancies ----
create policy "ver la agenda del club"
  on public.court_occupancies for select
  using (public.can_read_club(club_id));

create policy "el club gestiona su agenda"
  on public.court_occupancies for all
  using (public.can_write_club(club_id))
  with check (public.can_write_club(club_id));

-- =============================================================================
-- Traer lo que ya existe
-- =============================================================================
-- Los torneos guardados hasta hoy sólo saben de números de pista. Se les
-- inventan las pistas del club a partir del torneo más grande que tenga cada
-- uno; es una suposición razonable y el club la corrige renombrando.

insert into public.courts (club_id, nombre, orden)
select c.id, 'Pista ' || g.n, g.n
from public.clubs c
cross join lateral (
  select max(t.pistas) as maximo
  from public.tournaments t
  where t.club_id = c.id
) m
cross join lateral generate_series(1, coalesce(m.maximo, 0)) as g(n)
where not exists (select 1 from public.courts x where x.club_id = c.id);

insert into public.tournament_courts (tournament_id, court_id, orden)
select t.id, c.id, c.orden
from public.tournaments t
join public.courts c
  on c.club_id = t.club_id and c.orden <= t.pistas
on conflict do nothing;

-- Una ocupación por partido que sepa a qué hora se juega. Un torneo sin hora de
-- inicio no aparece en la agenda, y es correcto: no se sabe cuándo es.
--
-- `on conflict do nothing` por el `exclude`: si dos torneos viejos del mismo
-- club se pisaron en el calendario (nada lo impedía hasta hoy), entra el
-- primero y el segundo se queda fuera de la agenda. Es preferible a que la
-- migración se caiga a la mitad; el club lo ve en la agenda y lo recoloca.
insert into public.court_occupancies
  (club_id, court_id, durante, motivo, tournament_id, match_id)
select
  t.club_id,
  tc.court_id,
  tsrange(
    (t.fecha + coalesce(r.hora, t.hora_inicio))::timestamp,
    (t.fecha + coalesce(r.hora, t.hora_inicio))::timestamp
      + make_interval(mins => t.minutos_por_ronda),
    '[)'
  ),
  'torneo',
  t.id,
  m.id
from public.matches m
join public.rounds r             on r.id = m.round_id
join public.tournaments t        on t.id = r.tournament_id
join public.tournament_courts tc on tc.tournament_id = t.id and tc.orden = m.pista
where coalesce(r.hora, t.hora_inicio) is not null
on conflict do nothing;
