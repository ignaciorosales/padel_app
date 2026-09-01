-- =============================================================================
-- Puntazo · 0008 · Cuadros grandes
-- =============================================================================
-- La 0006 dejó `rounds.fase` con una lista cerrada que se paraba en
-- 'dieciseisavos', es decir un cuadro de 32 parejas. Un barrido sobre todos los
-- tamaños (ver src/lib/torneo/tamanos.test.ts) enseñó que eso deja fuera
-- torneos que un club monta de verdad: 77 parejas repartidas en 20 grupos, con
-- dos clasificadas por grupo, dan 40 — y 40 necesitan un cuadro de 64.
--
-- Se amplía hasta 128 parejas (64 partidos en la primera ronda). Más allá de
-- ahí el código para con un error claro en vez de inventarse un nombre.
-- =============================================================================

-- La 0006 puso el CHECK dentro del ADD COLUMN, así que el nombre lo eligió
-- Postgres: normalmente 'rounds_fase_check', pero con un sufijo numérico si ya
-- existía otro igual. Adivinarlo sería dejar la migración a medias en cuanto no
-- se acertara, así que se busca por lo que dice y no por cómo se llama.
do $$
declare
  nombre text;
begin
  for nombre in
    select conname
    from pg_constraint
    where conrelid = 'public.rounds'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%dieciseisavos%'
  loop
    execute format('alter table public.rounds drop constraint %I', nombre);
  end loop;
end $$;

alter table public.rounds
  drop constraint if exists rounds_fase_valida;

alter table public.rounds
  add constraint rounds_fase_valida check (fase in (
    'grupo',
    'sesentaicuatroavos',
    'treintaidosavos',
    'dieciseisavos',
    'octavos',
    'cuartos',
    'semifinal',
    'final',
    'tercer_puesto'
  ));

comment on column public.rounds.fase is
  'De qué parte del torneo es esta ronda. ''grupo'' para una jornada de la '
  'fase de grupos (y para las rondas de un americano); el resto son rondas '
  'del cuadro eliminatorio, nombradas por cuántos partidos tienen.';
