-- =============================================================================
-- Puntazo · 0011 · Byes y huecos a medias
-- =============================================================================
-- Arregla una restricción que la 0006 dejó demasiado estricta.
--
-- Allí se escribió `parejas_completas`: o van las dos parejas de un partido o
-- no va ninguna, porque «una sí y otra no es siempre un error de programación».
-- Era cierto mientras sólo existían el americano y la fase de grupos.
--
-- Con el cuadro eliminatorio dejó de serlo, y de dos maneras a la vez:
--
--   · Un **bye**: cuando las clasificadas no son potencia de dos, las mejor
--     sembradas pasan sin jugar. Ese partido tiene una pareja y ningún rival.
--   · Un **hueco a medias**: la semifinal en la que ya se sabe quién llega por
--     un lado porque acabaron esos cuartos, pero no por el otro.
--
-- Las dos son estados legítimos y la restricción los rechazaba, así que el
-- cuadro no se podía ni crear. Lo que sí sigue siendo siempre un error es que
-- una pareja se enfrente a sí misma, y eso es lo único que se conserva.
--
-- Que un partido de grupos lleve siempre sus dos parejas lo garantiza el código
-- que los genera. La tabla ya no puede distinguir un formato de otro sin mirar
-- el torneo, y una restricción que necesita otra tabla para decidir es una
-- restricción que se salta sola el día que alguien inserta desde otro sitio.
-- =============================================================================

alter table public.matches
  drop constraint if exists parejas_completas;

alter table public.matches
  add constraint parejas_distintas check (
    pareja_a is null
    or pareja_b is null
    or pareja_a <> pareja_b
  );

comment on constraint parejas_distintas on public.matches is
  'Una pareja no puede jugar contra sí misma. Que falte una de las dos es '
  'normal en el cuadro: un bye, o un hueco cuya ronda anterior no ha acabado.';
