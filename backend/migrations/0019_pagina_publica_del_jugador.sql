-- =============================================================================
-- Puntazo · 0019 · Página pública del jugador
-- =============================================================================
-- El último trozo del MVP, y a propósito: es el canal de reparto. Un jugador
-- manda su enlace al grupo de WhatsApp, tres personas lo abren y ven un rating,
-- una división y una lista de logros que ellos no tienen. Eso es lo que trae al
-- siguiente club, y no funciona hasta que hay algo que enseñar — de ahí que vaya
-- después del rating, del perfil y de los logros y no antes.
--
-- ## Consentimiento, no cortesía
--
-- Un rating es un dato personal: dice lo bueno que eres y con qué frecuencia
-- juegas. Que sea interesante no lo hace público. Así que la página **está
-- apagada por defecto** y hay que encenderla, y el enlace lleva el uuid en vez de
-- un slug con el nombre: quien no ha encendido su página no aparece, y quien la
-- enciende no queda expuesto a que le encuentren por su nombre.
--
-- ## Lo que la página NO enseña, y por qué es una decisión de esquema
--
-- **Los nombres de los demás.** El historial de alguien lleva dentro con quién
-- jugó, y esas otras tres personas no han encendido nada. Las funciones de abajo
-- devuelven ids y nunca nombres de terceros, así que la página no puede enseñarlos
-- ni por descuido: no los tiene.
--
-- Tampoco el teléfono, ni la cuenta, ni de qué club es. Misma técnica que la 0004
-- con la página pública del torneo: funciones `security definer` que devuelven
-- exactamente las columnas de la página, y ninguna tabla abierta.
--
-- ## Por qué tres funciones y no una vista
--
-- Porque la página monta el perfil con el mismo código que el panel
-- (`lib/jugador/perfil.ts`) y calcula los logros con el mismo catálogo. Lo que
-- necesita, por tanto, son las mismas tres cosas que el panel: la ficha, los
-- partidos y las transacciones. Una vista con todo aplanado obligaría a escribir
-- una segunda versión del perfil, y dos perfiles discrepan.
-- =============================================================================

-- ---------------------------------------------------------- el interruptor
alter table public.players
  add column if not exists publico boolean not null default false;

create index if not exists players_publicos_idx on public.players (id)
  where publico;

comment on column public.players.publico is
  'Si su página /j/<id> se puede abrir sin sesión. Apagada por defecto: un rating '
  'es un dato personal, y que sea interesante no lo hace público.';

-- ------------------------------------------------------------ la ficha
create or replace function public.jugador_publico(p_id uuid)
returns table (
  id       uuid,
  nombre   text,
  apellido text,
  apodo    text,
  rating   double precision,
  desviacion double precision,
  confianza  double precision,
  partidos_puntuados int,
  ultimo_partido date,
  division text,
  escala   text,
  partidos_en_zona_de_ascenso  int,
  partidos_en_zona_de_descenso int
)
language sql
stable
security definer
set search_path = public
as $fn$
  select
    p.id, p.nombre, p.apellido, p.apodo,
    r.rating, r.desviacion, r.confianza, r.partidos_puntuados, r.ultimo_partido,
    r.division, r.escala,
    r.partidos_en_zona_de_ascenso, r.partidos_en_zona_de_descenso
  from public.players p
  -- `left join`: alguien puede encender su página antes de tener rating, y la
  -- página tiene que salir igual con la barra a cero. Es el estado del primer día.
  left join public.player_ratings r on r.player_id = p.id
  where p.id = p_id
    and p.publico;
$fn$;

comment on function public.jugador_publico(uuid) is
  'La ficha de un jugador con la página encendida, o ninguna fila. Sin teléfono, '
  'sin cuenta y sin club: sólo lo que la página enseña.';

-- --------------------------------------------------------- los partidos
-- En la forma exacta del tipo `Partido` de la app, para que la página use el mismo
-- `perfilDe()` que el panel. Los cuatro jugadores salen como ids y nunca como
-- nombres: las otras tres personas no han encendido ninguna página.
create or replace function public.partidos_publicos(p_id uuid)
returns table (
  id        uuid,
  evento_id uuid,
  fecha     date,
  origen    text,
  formato   text,
  unidad    text,
  a1 uuid, a2 uuid, b1 uuid, b2 uuid,
  marcador_a int,
  marcador_b int
)
language sql
stable
security definer
set search_path = public
as $fn$
  with permitido as (
    select 1 from public.players p where p.id = p_id and p.publico
  )
  -- Los de torneo: el origen es 'torneo' y la fecha y la unidad son del torneo,
  -- igual que en `desde-el-panel.ts`.
  select
    m.id,
    t.id,
    t.fecha,
    'torneo'::text,
    t.formato,
    t.unidad_marcador,
    tpa1.player_id, tpa2.player_id, tpb1.player_id, tpb2.player_id,
    m.juegos_a,
    m.juegos_b
  from public.matches m
  join public.rounds rd on rd.id = m.round_id
  join public.tournaments t on t.id = rd.tournament_id
  join public.tournament_players tpa1 on tpa1.id = m.a1
  join public.tournament_players tpa2 on tpa2.id = m.a2
  join public.tournament_players tpb1 on tpb1.id = m.b1
  join public.tournament_players tpb2 on tpb2.id = m.b2
  where exists (select 1 from permitido)
    and m.juegos_a is not null
    and m.juegos_b is not null
    and p_id in (tpa1.player_id, tpa2.player_id, tpb1.player_id, tpb2.player_id)

  union all

  -- Los amistosos, con el origen que les toca según su estado. La misma regla que
  -- `lib/rating/amistosos.ts`, y la única vez que se repite: aquí hace falta para
  -- no traerse a la app dos columnas que sólo sirven para derivar una.
  select
    f.id,
    null::uuid,
    f.fecha,
    case when f.estado = 'confirmado' then f.origen_confirmado else 'sin_puntuar' end,
    'amistoso'::text,
    f.unidad,
    f.a1, f.a2, f.b1, f.b2,
    f.marcador_a,
    f.marcador_b
  from public.friendly_matches f
  where exists (select 1 from permitido)
    and p_id in (f.a1, f.a2, f.b1, f.b2);
$fn$;

comment on function public.partidos_publicos(uuid) is
  'El historial de un jugador público en la forma del tipo Partido de la app. '
  'Devuelve ids de jugador y nunca nombres: las otras tres personas de cada '
  'partido no han encendido ninguna página.';

-- ------------------------------------------------------- las transacciones
-- Para el gráfico de evolución, el techo histórico y los logros de gesta.
create or replace function public.transacciones_publicas(p_id uuid)
returns table (
  match_id uuid,
  friendly_match_id uuid,
  player_id uuid,
  fecha date,
  rating_antes double precision,
  rating_despues double precision,
  delta double precision,
  probabilidad_esperada double precision,
  rating_rivales double precision,
  resultado double precision
)
language sql
stable
security definer
set search_path = public
as $fn$
  select
    t.match_id, t.friendly_match_id, t.player_id, t.fecha,
    t.rating_antes, t.rating_despues, t.delta,
    t.probabilidad_esperada, t.rating_rivales, t.resultado
  from public.rating_transactions t
  join public.players p on p.id = t.player_id
  where t.player_id = p_id
    and p.publico
  order by t.fecha, t.created_at;
$fn$;

-- --------------------------------------------------- los cambios de división
create or replace function public.divisiones_publicas(p_id uuid)
returns table (
  player_id uuid,
  fecha date,
  anterior text,
  nueva text,
  tipo text,
  rating_al_cambiar double precision
)
language sql
stable
security definer
set search_path = public
as $fn$
  select h.player_id, h.fecha, h.anterior, h.nueva, h.tipo, h.rating_al_cambiar
  from public.player_division_history h
  join public.players p on p.id = h.player_id
  where h.player_id = p_id
    and p.publico
  order by h.fecha;
$fn$;

-- --------------------------------------------------------------- permisos
grant execute on function public.jugador_publico(uuid)        to anon, authenticated;
grant execute on function public.partidos_publicos(uuid)      to anon, authenticated;
grant execute on function public.transacciones_publicas(uuid) to anon, authenticated;
grant execute on function public.divisiones_publicas(uuid)    to anon, authenticated;

-- --------------------------------------------- quién enciende el interruptor
-- El club, desde el perfil del jugador en el panel. No es lo ideal —debería
-- encenderlo el jugador desde su app— y se dice aquí para que no se olvide: en
-- cuanto exista la app, esta política se estrecha a `user_id = auth.uid()`.
--
-- Mientras tanto lo enciende quien tiene la relación con la persona y puede
-- preguntarle, que es el club. La política de UPDATE de la 0009 ya se lo permite.
comment on index public.players_publicos_idx is
  'Sólo las fichas encendidas. Hoy las enciende el club desde el panel; cuando '
  'exista la app del jugador, la política pasa a user_id = auth.uid().';
