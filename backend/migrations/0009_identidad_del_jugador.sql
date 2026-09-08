-- =============================================================================
-- Puntazo · 0009 · Identidad del jugador
-- =============================================================================
-- Hoy un inscrito es texto libre dentro de un torneo: "Nacho R." en el torneo de
-- marzo y "Ignacio Rosales" en el de abril son dos filas sin ninguna relación.
-- Esta migración añade la persona detrás de esas filas.
--
-- Es la pieza que sostiene la app del jugador (docs/producto/app-jugador.md),
-- pero entra ahora, con el panel, y no cuando se construya la app: retrofitear
-- identidad sobre dos años de nombres sueltos cuesta diez veces más. A partir de
-- aquí el historial se acumula solo, aunque nadie lo mire todavía.
--
-- Deliberadamente mínima. No hay foto, ni nivel, ni categoría, ni cuenta de
-- acceso: todo eso es de la app y son columnas que se añaden en una línea
-- cuando existan. Lo que no se puede añadir después sin dolor es la relación.
--
-- No toca `tournament_players` más que para colgarle la referencia, y no toca
-- nada de lo que hacen los torneos de parejas: los cuatro jugadores de un
-- partido siguen estando donde estaban.
-- =============================================================================

-- ---------------------------------------------------------------- personas
-- Una fila por persona real, para siempre. Vive fuera del club a propósito:
-- un jugador puede jugar en varios clubes y el ranking entre clubes depende de
-- que sea la misma fila en todos.
--
-- A qué club pertenece no se guarda: es "los clubes de los torneos que ha
-- jugado", y calcularlo evita que las dos cosas se contradigan. Mismo criterio
-- que el de quién descansa en una ronda.
create table if not exists public.players (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null check (length(trim(nombre)) > 0),
  apellido   text,
  -- En el club te llaman por el apodo. Sirve para reconocerte en la pantalla de
  -- unificación cuando el nombre del torneo no coincide con el del documento.
  apodo      text,
  -- Llave con la que un jugador reclama su ficha. No es única a propósito: una
  -- pareja o una familia comparten teléfono más a menudo de lo que parece, y
  -- quien decide si dos filas son la misma persona es el club, no una
  -- restricción de la base de datos.
  telefono   text,
  created_at timestamptz not null default now(),

  -- Para la pantalla de "estos nombres parecen la misma persona". Generada, y
  -- por tanto imposible de dejar desincronizada con el nombre.
  busqueda   text generated always as (
    lower(trim(coalesce(nombre, '') || ' ' || coalesce(apellido, '')))
  ) stored
);

create index if not exists players_busqueda_idx on public.players (busqueda);
create index if not exists players_telefono_idx on public.players (telefono)
  where telefono is not null;

comment on table public.players is
  'La persona detrás de los inscritos. Un jugador tiene una fila aquí y tantas '
  'filas en tournament_players como torneos haya jugado.';
comment on column public.players.busqueda is
  'Nombre y apellido en minúsculas, para buscar y para proponer unificaciones. '
  'Generada: no se escribe a mano.';

-- ------------------------------------------------- el inscrito, y quién es
-- Nulo es el estado normal: el club apunta los nombres el sábado por la mañana
-- y la unificación viene después, o nunca. Nada del panel depende de esto.
alter table public.tournament_players
  add column if not exists player_id uuid
    references public.players (id) on delete set null;

create index if not exists tournament_players_player_idx
  on public.tournament_players (player_id)
  where player_id is not null;

-- La misma persona no puede estar inscrita dos veces en el mismo torneo. Los
-- nulos no chocan entre sí en Postgres, así que los inscritos sin unificar
-- siguen conviviendo sin problema.
create unique index if not exists tournament_players_persona_unica_idx
  on public.tournament_players (tournament_id, player_id)
  where player_id is not null;

comment on column public.tournament_players.player_id is
  'Qué persona es este inscrito, cuando se sabe. NULL mientras nadie lo haya '
  'unificado, que es el estado normal el día del torneo.';

-- ------------------------------------------------------------------- RLS
-- Una persona se ve si se ve alguno de sus torneos: misma puerta que los
-- inscritos, ni más ni menos. Y como los torneos públicos se leen sin sesión,
-- la página pública de un torneo puede enseñar a quién enlaza cada nombre.
alter table public.players enable row level security;

create policy "ver personas de torneos que ya puedes ver"
  on public.players for select
  using (
    public.is_platform_admin()
    or exists (
      select 1
      from public.tournament_players tp
      where tp.player_id = players.id
        and (
          public.can_read_club(public.club_de_torneo(tp.tournament_id))
          or public.torneo_es_publico(tp.tournament_id)
        )
    )
    -- Una persona recién creada todavía no está en ningún torneo. Sin esto, el
    -- club no podría leer la fila que acaba de escribir.
    or not exists (
      select 1 from public.tournament_players tp where tp.player_id = players.id
    )
  );

-- Escribe el club que está unificando a sus inscritos. Al crear la fila todavía
-- no cuelga de ningún torneo, así que basta con ser de algún club: el daño
-- posible es una persona huérfana, y la referencia desde el inscrito es la que
-- lleva de verdad el permiso.
create policy "un club puede dar de alta y corregir personas"
  on public.players for insert
  to authenticated
  with check (true);

create policy "corregir personas de tus torneos"
  on public.players for update
  using (
    public.is_platform_admin()
    or exists (
      select 1
      from public.tournament_players tp
      where tp.player_id = players.id
        and public.can_write_club(public.club_de_torneo(tp.tournament_id))
    )
  );

create policy "la plataforma borra personas"
  on public.players for delete
  using (public.is_platform_admin());
