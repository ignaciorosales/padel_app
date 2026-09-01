-- =============================================================================
-- Puntazo · 0005 · Desempates configurables
-- =============================================================================
-- No hay un criterio de desempate correcto: unos clubes cuentan juegos a favor
-- y otros partidos ganados, y los dos tienen razón. Lo que no puede pasar es
-- discutirlo el sábado con la clasificación ya impresa, así que se elige al
-- montar el torneo y queda escrito.
--
-- Es un array ordenado: la posición 1 es el criterio principal y los
-- siguientes sólo se miran si hay empate. El valor por defecto es el orden que
-- ya usaba el código antes de esta migración, así que los torneos existentes
-- no cambian de clasificación al aplicarla.
--
-- El orden lo aplica el cliente en src/lib/torneo/clasificacion.ts. Aquí sólo
-- se guarda y se comprueba que lo guardado tiene sentido.
-- =============================================================================

alter table public.tournaments
  add column if not exists desempates text[] not null
    default array['juegos_favor', 'diferencia', 'ganados'];

-- Al menos un criterio (una clasificación sin criterios sería un orden
-- arbitrario) y sólo criterios que el código sepa aplicar.
--
-- El coalesce no es decorativo: sobre un array vacío array_length() devuelve
-- NULL, no 0, y un CHECK que da NULL se considera cumplido. Sin él, '{}' se
-- colaría por el hueco que esta restricción existe para tapar.
alter table public.tournaments
  drop constraint if exists desempates_validos;

alter table public.tournaments
  add constraint desempates_validos check (
    coalesce(array_length(desempates, 1), 0) between 1 and 4
    and desempates <@ array['juegos_favor', 'diferencia', 'ganados', 'juegos_contra']::text[]
  );

comment on column public.tournaments.desempates is
  'Criterios de desempate en orden de prioridad. El primero manda; los demás '
  'sólo deciden empates. Valores: juegos_favor, diferencia, ganados, '
  'juegos_contra (este último, menos es mejor).';
