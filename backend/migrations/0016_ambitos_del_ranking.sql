-- =============================================================================
-- Puntazo · 0016 · Ámbitos del ranking
-- =============================================================================
-- El ranking de un club ya se puede calcular: están los ratings y está
-- `club_memberships`. Lo que no se puede es el de una ciudad ni el de un país,
-- porque un club no sabe dónde está.
--
-- Y hay un problema más gordo que las dos columnas que faltan: **RLS.** La
-- política de `player_ratings` deja ver el rating de quien comparte club contigo
-- o jugó un torneo público. Un ranking de Montevideo es exactamente lo contrario:
-- gente de doce clubes con los que no tienes nada que ver. Con la clave anónima,
-- esa consulta devuelve tu propio club y nada más — y no da error, que es peor.
--
-- La respuesta es la misma que en la 0004 con la página pública: **una función
-- `security definer` que devuelve sólo las columnas del ranking**, y no abrir la
-- tabla. Un ranking necesita nombre, rating, división y partidos; no necesita
-- teléfonos, ni cuentas, ni de qué club es cada uno más allá de para agrupar.
--
-- Lo que la función **no** hace es ordenar ni decidir quién entra. Eso ya está
-- escrito y probado en `lib/jugador/ranking.ts`, con las tres reglas que hacen
-- que un ranking se crea: los provisionales fuera, los empates comparten puesto,
-- y una tabla que junta gente que nunca se ha cruzado se marca como estimada.
-- Repetir esas reglas en SQL sería tener dos rankings que un día discrepan.
-- =============================================================================

-- ------------------------------------------------------------ dónde está el club
-- Texto y no una tabla de ciudades: hasta que haya cincuenta clubes, una tabla de
-- ciudades es una tabla con seis filas y un formulario más que rellenar. Cuando
-- haga falta normalizar se normaliza, y el dato ya estará.
alter table public.clubs
  add column if not exists ciudad text;

-- Dos letras, ISO 3166-1. Uruguay por defecto porque es donde arranca, y porque
-- un país nulo obligaría a tratar el caso en todas las consultas.
alter table public.clubs
  add column if not exists pais text not null default 'UY';

alter table public.clubs
  drop constraint if exists pais_de_dos_letras;
alter table public.clubs
  add constraint pais_de_dos_letras check (pais ~ '^[A-Z]{2}$');

create index if not exists clubs_ciudad_idx on public.clubs (pais, ciudad);

comment on column public.clubs.ciudad is
  'Ciudad del club, para el ranking de ciudad. Texto libre a propósito: una '
  'tabla de ciudades con seis filas es un formulario más y ninguna ventaja.';

-- ================================================== los jugadores de un ámbito
-- Ámbitos: 'club' (p_valor = uuid del club), 'ciudad' (p_valor = nombre),
-- 'pais' (p_valor = dos letras) y 'red' (p_valor se ignora).
--
-- La pertenencia sale de `club_memberships`, no de haber jugado un torneo. Es una
-- decisión del club y no un cálculo: quien fue de visita a un torneo abierto no
-- es del club, y quien entrena allí todas las semanas sí, aunque no haya jugado
-- ningún torneo. El panel escribe esa fila al identificar a alguien, que es el
-- momento en que el club dice "éste es de los nuestros".
create or replace function public.jugadores_del_ambito(
  p_ambito text,
  p_valor  text default null
)
returns table (
  player_id  uuid,
  nombre     text,
  apellido   text,
  apodo      text,
  rating     double precision,
  desviacion double precision,
  confianza  double precision,
  partidos_puntuados int,
  ultimo_partido date,
  division   text,
  escala     text
)
language sql
stable
security definer
set search_path = public
as $fn$
  select
    p.id,
    p.nombre,
    p.apellido,
    p.apodo,
    r.rating,
    r.desviacion,
    r.confianza,
    r.partidos_puntuados,
    r.ultimo_partido,
    r.division,
    r.escala
  from public.player_ratings r
  join public.players p on p.id = r.player_id
  where
    case p_ambito
      when 'red' then true
      when 'club' then exists (
        select 1
        from public.club_memberships m
        where m.player_id = p.id
          and m.activo
          and m.club_id = p_valor::uuid
      )
      when 'ciudad' then exists (
        select 1
        from public.club_memberships m
        join public.clubs c on c.id = m.club_id
        where m.player_id = p.id
          and m.activo
          and c.ciudad is not distinct from p_valor
      )
      when 'pais' then exists (
        select 1
        from public.club_memberships m
        join public.clubs c on c.id = m.club_id
        where m.player_id = p.id
          and m.activo
          and c.pais = p_valor
      )
      -- Un ámbito que no se reconoce devuelve vacío, no todo. Equivocarse en el
      -- nombre del ámbito no puede acabar enseñando la red entera.
      else false
    end;
$fn$;

comment on function public.jugadores_del_ambito(text, text) is
  'Los jugadores con rating de un ámbito (club, ciudad, país o red), con sólo las '
  'columnas que un ranking necesita. No ordena ni filtra provisionales: eso lo '
  'hace lib/jugador/ranking.ts, que es donde están las reglas y los tests.';

-- --------------------------------------------------- con quién ha jugado quién
-- Para poder decir si una tabla es un ranking o una estimación hace falta saber
-- quién ha coincidido con quién. La respuesta ya está en `rating_transactions`:
-- dos jugadores con una transacción del mismo partido jugaron ese partido.
--
-- Devuelve pares (partido, jugador) y no el grafo montado: el cálculo de
-- componentes conexas vive en `lib/jugador/ranking.ts` y no se duplica aquí.
create or replace function public.coincidencias_del_ambito(
  p_ambito text,
  p_valor  text default null
)
returns table (partido_id uuid, player_id uuid)
language sql
stable
security definer
set search_path = public
as $fn$
  select
    coalesce(t.match_id, t.friendly_match_id),
    t.player_id
  from public.rating_transactions t
  where t.player_id in (
    select a.player_id from public.jugadores_del_ambito(p_ambito, p_valor) a
  );
$fn$;

comment on function public.coincidencias_del_ambito(text, text) is
  'Pares (partido, jugador) de los jugadores de un ámbito, para calcular qué '
  'grupos se han cruzado. El grafo se monta en el cliente, donde están los tests.';

-- ------------------------------------------------------------------ permisos
-- Un ranking es público por diseño: es el canal de reparto del producto, y un
-- ranking que hay que iniciar sesión para ver no reparte nada. Estas dos
-- funciones son la puerta estrecha por la que sale, y devuelven sólo columnas de
-- ranking.
grant execute on function public.jugadores_del_ambito(text, text)
  to anon, authenticated;
grant execute on function public.coincidencias_del_ambito(text, text)
  to anon, authenticated;

-- ----------------------------------------------- las ciudades que hay ranking
-- Para llenar el desplegable sin exponer la tabla de clubes.
create or replace function public.ambitos_disponibles()
returns table (pais text, ciudad text, clubes int)
language sql
stable
security definer
set search_path = public
as $fn$
  select c.pais, c.ciudad, count(*)::int
  from public.clubs c
  where exists (
    select 1 from public.club_memberships m where m.club_id = c.id and m.activo
  )
  group by c.pais, c.ciudad
  order by c.pais, c.ciudad nulls last;
$fn$;

grant execute on function public.ambitos_disponibles() to anon, authenticated;

comment on function public.ambitos_disponibles() is
  'Qué países y ciudades tienen jugadores, para los filtros del ranking. Sólo '
  'cuenta clubes con al menos un jugador: una ciudad sin nadie no es un filtro.';
