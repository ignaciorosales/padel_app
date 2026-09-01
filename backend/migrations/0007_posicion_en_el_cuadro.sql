-- =============================================================================
-- Puntazo · 0007 · Posición en el cuadro eliminatorio
-- =============================================================================
-- Un partido del cuadro necesita saber QUÉ hueco ocupa dentro de su fase, y no
-- vale reutilizar `pista` para eso.
--
-- La regla de avance es «el ganador del partido n pasa al partido n/2 de la
-- ronda siguiente». Si esa n fuera el número de pista, el organizador movería
-- un partido de la 3 a la 1 —algo perfectamente normal el día del torneo, y
-- que la pantalla de correcciones ya permite— y estaría reescribiendo el
-- cuadro sin querer: la semifinal cambiaría de rival sola.
--
-- Por eso van separados. `pista` es dónde se juega y se puede cambiar cuantas
-- veces haga falta; `orden` es la posición en el cuadro y no la toca nadie.
--
-- En un americano y en la fase de grupos `orden` no se usa y se queda a 0.
-- =============================================================================

alter table public.matches
  add column if not exists orden int not null default 0 check (orden >= 0);

comment on column public.matches.orden is
  'Posición del partido dentro de su fase del cuadro (0..n-1). El ganador del '
  'partido n pasa al partido n/2 de la ronda siguiente, al lado A si n es par '
  'y al lado B si es impar. Sin uso (0) en americanos y fases de grupos.';
