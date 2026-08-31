-- =============================================================================
-- Puntazo · 0003 · Torneos
-- =============================================================================
-- Todo cuelga del club, y toda escritura pasa por can_write_club(): un club
-- suspendido puede consultar sus torneos pero no tocar nada.
--
-- La lectura tiene una segunda puerta: si el torneo está marcado como público,
-- lo puede leer cualquiera sin sesión. Es lo que permite que la página pública
-- funcione con la clave anónima, sin claves secretas ni servidor intermedio.
-- =============================================================================

create type public.tournament_status as enum (
  'borrador',   -- se está montando: aún no hay rondas
  'en_juego',   -- rondas generadas, metiendo resultados
  'terminado'
);

-- ---------------------------------------------------------------- torneos
create table public.tournaments (
  id                uuid primary key default gen_random_uuid(),
  club_id           uuid not null references public.clubs (id) on delete cascade,
  slug              text not null
                    check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug) between 2 and 60),
  nombre            text not null check (length(trim(nombre)) > 0),
  fecha             date not null,
  hora_inicio       time,
  pistas            int  not null check (pistas between 1 and 30),
  rondas            int  not null check (rondas between 1 and 40),
  minutos_por_ronda int  not null default 20 check (minutos_por_ronda between 5 and 180),
  formato           text not null default 'americano',
  estado            public.tournament_status not null default 'borrador',
  -- Semilla con la que se generaron las rondas: guardarla permite reproducir
  -- exactamente el mismo cuadro más adelante.
  semilla           int,
  publico           boolean not null default true,
  created_at        timestamptz not null default now(),
  unique (club_id, slug)
);

create index tournaments_club_idx on public.tournaments (club_id, fecha desc);

-- ------------------------------------------------------------- inscritos
-- Nombres sueltos: no son cuentas de usuario y no hace falta que lo sean.
create table public.tournament_players (
  id            uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments (id) on delete cascade,
  nombre        text not null check (length(trim(nombre)) > 0),
  telefono      text,
  orden         int  not null default 0,
  created_at    timestamptz not null default now()
);

create index tournament_players_torneo_idx
  on public.tournament_players (tournament_id, orden);

-- ---------------------------------------------------------------- rondas
create table public.rounds (
  id            uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments (id) on delete cascade,
  numero        int not null check (numero > 0),
  hora          time,
  unique (tournament_id, numero)
);

-- -------------------------------------------------------------- partidos
-- Quién descansa no se guarda: es "los inscritos que no juegan esta ronda",
-- y calcularlo evita que las dos cosas se contradigan.
create table public.matches (
  id        uuid primary key default gen_random_uuid(),
  round_id  uuid not null references public.rounds (id) on delete cascade,
  pista     int not null check (pista > 0),
  a1        uuid not null references public.tournament_players (id) on delete cascade,
  a2        uuid not null references public.tournament_players (id) on delete cascade,
  b1        uuid not null references public.tournament_players (id) on delete cascade,
  b2        uuid not null references public.tournament_players (id) on delete cascade,
  juegos_a  int check (juegos_a >= 0),
  juegos_b  int check (juegos_b >= 0),
  unique (round_id, pista),
  -- O están los dos resultados o no está ninguno: no existe medio partido.
  constraint resultado_completo check (
    (juegos_a is null and juegos_b is null)
    or (juegos_a is not null and juegos_b is not null)
  ),
  constraint jugadores_distintos check (
    a1 <> a2 and a1 <> b1 and a1 <> b2 and a2 <> b1 and a2 <> b2 and b1 <> b2
  )
);

create index matches_round_idx on public.matches (round_id, pista);

-- =============================================================================
-- Funciones para las políticas
-- =============================================================================

create or replace function public.club_de_torneo(p_torneo uuid)
returns uuid
language sql stable security definer set search_path = public
as $$ select t.club_id from public.tournaments t where t.id = p_torneo; $$;

create or replace function public.torneo_es_publico(p_torneo uuid)
returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce((select t.publico from public.tournaments t where t.id = p_torneo), false); $$;

create or replace function public.torneo_de_ronda(p_ronda uuid)
returns uuid
language sql stable security definer set search_path = public
as $$ select r.tournament_id from public.rounds r where r.id = p_ronda; $$;

-- =============================================================================
-- RLS
-- =============================================================================

alter table public.tournaments        enable row level security;
alter table public.tournament_players enable row level security;
alter table public.rounds             enable row level security;
alter table public.matches            enable row level security;

-- ---- tournaments ----
create policy "ver torneos del club o públicos"
  on public.tournaments for select
  using (public.can_read_club(club_id) or publico);

create policy "el club gestiona sus torneos"
  on public.tournaments for all
  using (public.can_write_club(club_id))
  with check (public.can_write_club(club_id));

-- ---- tournament_players ----
create policy "ver inscritos del club o de torneos públicos"
  on public.tournament_players for select
  using (
    public.can_read_club(public.club_de_torneo(tournament_id))
    or public.torneo_es_publico(tournament_id)
  );

create policy "el club gestiona sus inscritos"
  on public.tournament_players for all
  using (public.can_write_club(public.club_de_torneo(tournament_id)))
  with check (public.can_write_club(public.club_de_torneo(tournament_id)));

-- ---- rounds ----
create policy "ver rondas del club o de torneos públicos"
  on public.rounds for select
  using (
    public.can_read_club(public.club_de_torneo(tournament_id))
    or public.torneo_es_publico(tournament_id)
  );

create policy "el club gestiona sus rondas"
  on public.rounds for all
  using (public.can_write_club(public.club_de_torneo(tournament_id)))
  with check (public.can_write_club(public.club_de_torneo(tournament_id)));

-- ---- matches ----
create policy "ver partidos del club o de torneos públicos"
  on public.matches for select
  using (
    public.can_read_club(public.club_de_torneo(public.torneo_de_ronda(round_id)))
    or public.torneo_es_publico(public.torneo_de_ronda(round_id))
  );

create policy "el club gestiona sus partidos"
  on public.matches for all
  using (public.can_write_club(public.club_de_torneo(public.torneo_de_ronda(round_id))))
  with check (public.can_write_club(public.club_de_torneo(public.torneo_de_ronda(round_id))));
