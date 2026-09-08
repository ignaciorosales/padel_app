-- =============================================================================
-- Puntazo · 0010 · Huecos del cuadro
-- =============================================================================
-- (Nació como 0009 y se renumeró: la otra lane estaba escribiendo su propia
-- 0009 al mismo tiempo. Son independientes y el orden entre ellas da igual.)
--
-- `matches` nació para el americano, donde un partido siempre tiene sus cuatro
-- jugadores desde que se genera. En un cuadro eliminatorio no: la semifinal
-- existe desde el primer momento —el club quiere ver el cuadro entero— pero no
-- se sabe quién la juega hasta que terminan los cuartos.
--
-- La alternativa era no crear esas filas hasta tener ganadores, e ir
-- materializándolas resultado a resultado. Se descartó: obliga a que crear
-- partidos sea un efecto secundario de guardar un marcador, y ahí es donde un
-- cuadro se queda a medias si algo falla en mitad de la cadena. Es preferible
-- que el cuadro exista entero desde el principio, con huecos.
--
-- Los cuatro jugadores pasan a ser opcionales. Un partido de americano o de
-- fase de grupos los sigue llevando siempre: eso lo garantiza el código que
-- los genera, no la tabla.
-- =============================================================================

alter table public.matches alter column a1 drop not null;
alter table public.matches alter column a2 drop not null;
alter table public.matches alter column b1 drop not null;
alter table public.matches alter column b2 drop not null;

-- La restricción de que los cuatro sean distintos se mantiene y sigue
-- funcionando: en SQL, comparar contra NULL da NULL y un CHECK que da NULL se
-- considera cumplido, así que un hueco vacío no la dispara.

-- Un partido del cuadro no puede tener media pareja: o se sabe quién juega ese
-- lado o no se sabe, pero no un jugador sí y el otro no.
alter table public.matches
  drop constraint if exists lados_completos;

alter table public.matches
  add constraint lados_completos check (
    (a1 is null) = (a2 is null)
    and (b1 is null) = (b2 is null)
  );

comment on column public.matches.a1 is
  'Primer jugador del lado A. NULL sólo en un hueco del cuadro eliminatorio '
  'que todavía no tiene ocupante. En americanos y fases de grupos va siempre.';
