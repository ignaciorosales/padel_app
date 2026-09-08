-- =============================================================================
-- Puntazo · 0006 · Torneo de parejas (fase de grupos y eliminatorias)
-- =============================================================================
-- Hasta aquí sólo existía el americano: cada uno se apunta solo, cambia de
-- compañero cada ronda y la clasificación es individual. El torneo tradicional
-- es otra cosa: la pareja se apunta junta y no cambia, se juega una fase de
-- grupos y las mejores parejas pasan a un cuadro (cuartos, semifinal, final).
--
-- La decisión que evita duplicarlo todo: **`matches` no cambia de forma**.
-- Un partido de parejas sigue teniendo sus cuatro jugadores en a1/a2/b1/b2,
-- que es lo que ya saben leer la página pública, el texto de WhatsApp y la
-- impresión. Lo que se añade es de qué PAREJA es cada lado, para poder llevar
-- la clasificación por parejas en vez de por persona.
--
-- Así, todo lo construido para el americano sigue funcionando sin tocarlo.
-- =============================================================================

-- ------------------------------------------------------------------ formato
-- La columna existe desde la 0003 con default 'americano', pero sin validar.
alter table public.tournaments
  drop constraint if exists formato_valido;

alter table public.tournaments
  add constraint formato_valido check (formato in ('americano', 'parejas'));

-- ------------------------------------------------- ajustes del de parejas
alter table public.tournaments
  add column if not exists grupos int not null default 1
    check (grupos between 1 and 16);

-- Cuántas parejas de cada grupo pasan al cuadro final.
alter table public.tournaments
  add column if not exists clasifican_por_grupo int not null default 2
    check (clasifican_por_grupo between 1 and 8);

-- Qué significan los dos números del marcador. No cambia ningún cálculo: la
-- clasificación suma lo que haya. Sirve para que la interfaz diga la palabra
-- que usa el club en vez de llamar "juegos" a lo que son sets.
alter table public.tournaments
  add column if not exists unidad_marcador text not null default 'juegos'
    check (unidad_marcador in ('juegos', 'sets', 'puntos'));

-- ----------------------------------------------------------------- parejas
create table if not exists public.tournament_pairs (
  id            uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments (id) on delete cascade,
  jugador1      uuid not null references public.tournament_players (id) on delete cascade,
  jugador2      uuid not null references public.tournament_players (id) on delete cascade,
  grupo         int  not null default 1 check (grupo > 0),
  orden         int  not null default 0,
  created_at    timestamptz not null default now(),

  constraint pareja_de_dos_distintos check (jugador1 <> jugador2),

  -- Impiden que el mismo jugador ocupe la misma posición dos veces. NO
  -- impiden que esté como jugador1 de una pareja y jugador2 de otra: eso no
  -- se puede expresar en una restricción de tabla sin un disparador, y se
  -- comprueba al inscribir (ver src/lib/torneo/parejas.ts).
  unique (tournament_id, jugador1),
  unique (tournament_id, jugador2)
);

create index if not exists tournament_pairs_torneo_idx
  on public.tournament_pairs (tournament_id, grupo, orden);

-- -------------------------------------------------------- fase de la ronda
-- Una ronda es de una sola fase: o es una jornada de grupos, o es una ronda
-- del cuadro. Ponerlo aquí y no en cada partido evita que se contradigan.
alter table public.rounds
  add column if not exists fase text not null default 'grupo'
    check (fase in (
      'grupo', 'dieciseisavos', 'octavos', 'cuartos',
      'semifinal', 'final', 'tercer_puesto'
    ));

-- ------------------------------------------------------ partidos y parejas
alter table public.matches
  add column if not exists pareja_a uuid
    references public.tournament_pairs (id) on delete cascade;

alter table public.matches
  add column if not exists pareja_b uuid
    references public.tournament_pairs (id) on delete cascade;

-- En un americano los dos son NULL; en uno de parejas van los dos. Uno sí y
-- otro no es siempre un error de programación, y es mejor que reviente al
-- escribir que dejar media clasificación mal calculada.
alter table public.matches
  drop constraint if exists parejas_completas;

alter table public.matches
  add constraint parejas_completas check (
    (pareja_a is null and pareja_b is null)
    or (pareja_a is not null and pareja_b is not null and pareja_a <> pareja_b)
  );

comment on table public.tournament_pairs is
  'Parejas fijas de un torneo tradicional. En un americano esta tabla queda '
  'vacía: allí el compañero cambia cada ronda y la clasificación es individual.';

comment on column public.matches.pareja_a is
  'De qué pareja es el lado A. NULL en los americanos. Los cuatro jugadores '
  'siguen estando en a1/a2/b1/b2 pase lo que pase, para que todo lo que ya '
  'sabe pintar un partido siga funcionando sin enterarse del formato.';
