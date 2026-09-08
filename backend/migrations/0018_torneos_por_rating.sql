-- =============================================================================
-- Puntazo · 0018 · Torneos por rating
-- =============================================================================
-- "Americano de cuarta y quinta" es lo que el club ya escribe en el cartel. Esto
-- es escribirlo en el torneo, para que el panel pueda decir quién no encaja antes
-- del sábado por la mañana.
--
-- ## La decisión que da forma a todo: es un aviso, no un portero
--
-- Lo natural sería impedir la inscripción de quien no llega al rango. No se hace,
-- y no es por comodidad:
--
-- **Un inscrito es texto libre.** El sábado a las nueve el encargado pega
-- veinticuatro nombres del grupo de WhatsApp, y de esos veinticuatro puede que
-- cinco estén identificados como personas. De los otros diecinueve no se sabe el
-- rating porque **no se sabe quién son**. Un portero que sólo puede juzgar a cinco
-- de veinticuatro no es un portero: es una molestia que se salta sola.
--
-- Así que la restricción vive en el torneo, el panel marca a quien no encaja de
-- los que sí se pueden juzgar, y el organizador aprueba la excepción con un toque.
-- El día que todos los jugadores tengan ficha, la misma información sirve para
-- cerrar la puerta de verdad y no hay que cambiar el esquema.
--
-- ## Rango o divisiones, no las dos cosas a la vez
--
-- Se pueden guardar las dos —un rango de rating y una lista de divisiones— porque
-- son dos formas de decir cosas distintas: "de 1450 a 1750" es una línea fina,
-- "cuarta y quinta" es lo que la gente entiende. Un torneo que use las dos exige
-- las dos, y eso también es legítimo: un torneo de cuarta que además pide 1500
-- mínimo está excluyendo a la mitad baja de cuarta a propósito.
-- =============================================================================

-- ------------------------------------------------------------ el rango
-- Nulos los dos: la inmensa mayoría de los torneos no restringen nada, y un
-- torneo abierto no debería tener que escribir 0 y 9999.
alter table public.tournaments
  add column if not exists rating_minimo int,
  add column if not exists rating_maximo int;

alter table public.tournaments
  drop constraint if exists rango_de_rating_coherente;
alter table public.tournaments
  add constraint rango_de_rating_coherente check (
    rating_minimo is null
    or rating_maximo is null
    or rating_minimo <= rating_maximo
  );

-- Las divisiones se guardan por su nombre ("4ª"), que es el dato del código, y no
-- por un índice: recalibrar la escala no puede cambiar el significado de un torneo
-- que ya se jugó. Vacío es "cualquiera", igual que un rango nulo.
alter table public.tournaments
  add column if not exists divisiones_admitidas text[] not null default '{}';

comment on column public.tournaments.rating_minimo is
  'Rating mínimo para entrar, o NULL si no se restringe. Es un aviso en el panel, '
  'no un portero: la mayoría de los inscritos no están identificados todavía.';
comment on column public.tournaments.divisiones_admitidas is
  'Divisiones que entran, por nombre ("4ª"). Vacío es cualquiera. Por nombre y no '
  'por índice para que recalibrar la escala no cambie un torneo ya jugado.';

-- ------------------------------------------------------- la excepción
-- Quien no encaja pero el organizador deja entrar. Con motivo, porque un torneo
-- de cuarta con seis excepciones sin explicar no es un torneo de cuarta y alguien
-- va a preguntar.
alter table public.tournament_players
  add column if not exists excepcion_aprobada boolean not null default false,
  add column if not exists excepcion_motivo text;

comment on column public.tournament_players.excepcion_aprobada is
  'El organizador le deja entrar aunque no encaje en el rango o la división del '
  'torneo. Es una decisión suya y queda escrita.';

-- Sólo tiene sentido guardar el motivo de una excepción que existe.
alter table public.tournament_players
  drop constraint if exists motivo_solo_con_excepcion;
alter table public.tournament_players
  add constraint motivo_solo_con_excepcion check (
    excepcion_aprobada or excepcion_motivo is null
  );
