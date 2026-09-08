-- =============================================================================
-- Puntazo · 0014 · Esquema del rating
-- =============================================================================
-- El motor de rating ya existe entero y con tests en `web/src/lib/rating/`, pero
-- vive en memoria: entra una lista de partidos y sale un estado que se tira al
-- terminar. Esta migración es donde ese estado aterriza.
--
-- La regla que da forma a todo lo de abajo: **el rating se reconstruye, no se
-- acumula.** Estas tablas no son la fuente de verdad — la fuente de verdad son
-- los partidos. Son el resultado de pasar el historial por el motor, guardado
-- para no recalcularlo en cada pantalla. Cuando cambie la fórmula (y va a
-- cambiar), no se migra nada: se vuelve a pasar y se reescriben.
--
-- De ahí salen dos consecuencias que explican decisiones raras a primera vista:
--
-- 1. **Se puede borrar todo y regenerarlo.** Por eso `rating_transactions`
--    cuelga de `matches` con `on delete cascade` aunque sea una tabla de
--    auditoría: un partido borrado no tiene rating que explicar.
-- 2. **Reprocesar tiene que ser inofensivo.** El motor ya ignora los partidos
--    repetidos dentro de una pasada; lo que hace falta aquí es que dos pasadas
--    concurrentes tampoco puedan puntuar dos veces el mismo partido. Eso lo
--    sostiene el índice único de `rating_transactions`, no la marca de tiempo.
--    Ver la nota de `matches.rating_processed_at` más abajo.
--
-- El rating es del **jugador**, nunca del club: todo lo de aquí cuelga de
-- `players`, y `club_memberships` sólo existe para poder agrupar en rankings
-- locales. Detalle del sistema en docs/producto/puntazo-rating.md.
--
-- Quién escribe: **sólo el servicio de rating**, con la clave de servicio. No
-- hay políticas de escritura a propósito; ver la sección de RLS al final.
-- =============================================================================

-- ------------------------------------------------------ el rating de cada uno
-- Una fila por persona, para toda la red. No hay club_id: quien tiene 1650 lo
-- tiene juegue donde juegue, y meter el club aquí sería la primera grieta por
-- donde se cuela un rating por club.
--
-- Las tres columnas de división guardan el estado de la histéresis, que no se
-- puede derivar del rating de hoy: para subir hay que sostener el umbral cinco
-- partidos, y esa cuenta vive con el jugador. Sin ella, cada reconstrucción
-- ascendería a quien roza el límite.
create table if not exists public.player_ratings (
  player_id  uuid primary key references public.players (id) on delete cascade,

  rating     double precision not null,
  -- Incertidumbre. Arranca en 350 y se estrecha con cada partido; nunca baja de
  -- 50, porque nunca se sabe del todo.
  desviacion double precision not null check (desviacion > 0),
  -- 0..1, lo que se enseña como "confianza 87 %". Se deriva de la desviación, y
  -- se guarda calculada para no repetir la fórmula en cada consulta.
  confianza  double precision not null check (confianza >= 0 and confianza <= 1),
  -- Por debajo del umbral de provisionalidad no se sale en rankings. El umbral
  -- es del algoritmo (15 en v1) y por eso no está en una restricción: cambiarlo
  -- no puede obligar a una migración.
  partidos_puntuados int not null default 0 check (partidos_puntuados >= 0),
  -- Fecha del último partido que le movió el rating. Es lo que decide si está
  -- oxidado, no la fecha de la última sesión.
  ultimo_partido date,

  -- Qué calibración de divisiones se usó. La escala es un dato del código
  -- (`ESCALA_UY` es 'uy-v1'), y guardarla permite recalibrar sin confundir un
  -- "3ª" de antes con uno de después.
  escala     text not null default 'uy-v1',
  division   text not null,
  partidos_en_zona_de_ascenso  int not null default 0
    check (partidos_en_zona_de_ascenso >= 0),
  partidos_en_zona_de_descenso int not null default 0
    check (partidos_en_zona_de_descenso >= 0),

  -- Con qué versión del algoritmo se calculó esta fila. Es lo que permite
  -- reprocesar sólo lo que se quedó atrás cuando cambie la fórmula.
  version      text not null,
  calculado_at timestamptz not null default now()
);

-- Los dos órdenes de los rankings: la tabla general y la de una división.
create index if not exists player_ratings_orden_idx
  on public.player_ratings (rating desc);
create index if not exists player_ratings_division_idx
  on public.player_ratings (escala, division, rating desc);

comment on table public.player_ratings is
  'El rating de cada persona, global a toda la red. Es una caché del resultado '
  'de pasar el historial por el motor: se puede borrar y regenerar.';
comment on column public.player_ratings.partidos_en_zona_de_ascenso is
  'Partidos seguidos por encima del umbral de la división siguiente. Es la '
  'cuenta de la histéresis; sin ella cada reconstrucción ascendería de más.';

-- -------------------------------------------------------------- la auditoría
-- Nunca se toca un rating sin dejar escrito cómo se llegó a él. Cada partido
-- puntuado deja cuatro filas aquí, una por jugador, con el antes, el después,
-- lo que el sistema esperaba y contra quién.
--
-- No es lujo: es la mitad de que alguien se crea el número. "Bajaste 12 porque
-- perdiste contra una pareja 90 puntos más floja" se puede discutir; "bajaste
-- 12" no.
create table if not exists public.rating_transactions (
  id        uuid primary key default gen_random_uuid(),
  match_id  uuid not null references public.matches (id) on delete cascade,
  player_id uuid not null references public.players (id) on delete cascade,
  fecha     date not null,

  rating_antes   double precision not null,
  rating_despues double precision not null,
  delta          double precision not null,
  -- Lo que el sistema daba por probable, de 0 a 1. Es la otra mitad de la
  -- explicación: un delta grande con una probabilidad de 0,9 es una sorpresa.
  probabilidad_esperada double precision not null
    check (probabilidad_esperada >= 0 and probabilidad_esperada <= 1),
  -- Fuerza de la pareja rival en el momento del partido. Se congela aquí porque
  -- dentro de un mes será otra, y la explicación tiene que seguir siendo cierta.
  rating_rivales double precision not null,
  -- El `S` que entró en la fórmula: 1 ganó, 0,5 empató, 0 perdió.
  resultado double precision not null check (resultado in (0, 0.5, 1)),

  version    text not null,
  created_at timestamptz not null default now()
);

-- **Ésta es la restricción que hace idempotente el proceso.** El motor ya
-- ignora los partidos repetidos dentro de una pasada, pero eso no protege de
-- dos pasadas a la vez: las dos leen el partido sin puntuar y las dos lo
-- puntúan. Con este índice, la segunda choca y su transacción entera se cae —
-- que es exactamente lo que se quiere, porque el rating no se acumula.
create unique index if not exists rating_transactions_una_por_partido_idx
  on public.rating_transactions (match_id, player_id);

-- Para el gráfico de evolución del perfil: las transacciones de uno, en orden.
create index if not exists rating_transactions_jugador_idx
  on public.rating_transactions (player_id, fecha, created_at);

comment on table public.rating_transactions is
  'El apunte contable de cada cambio de rating: cuatro filas por partido '
  'puntuado. De aquí salen el gráfico del perfil, la explicación de por qué '
  'bajó alguien y la reconstrucción cuando cambie la fórmula.';

-- ------------------------------------------------------------ subir y bajar
-- Cambiar de división es lo que la gente cuenta en el club, así que queda
-- fechado y con el partido que lo provocó.
--
-- `match_id` es nullable y se pone a null si el partido desaparece: a
-- diferencia de las transacciones, un ascenso ocurrido no se borra porque se
-- corrija el torneo donde ocurrió. La reconstrucción lo vuelve a poner en su
-- sitio.
create table if not exists public.player_division_history (
  id        uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players (id) on delete cascade,
  match_id  uuid references public.matches (id) on delete set null,
  fecha     date not null,

  escala    text not null default 'uy-v1',
  anterior  text not null,
  nueva     text not null,
  tipo      text not null check (tipo in ('ascenso', 'descenso')),
  rating_al_cambiar double precision not null,
  created_at timestamptz not null default now(),

  constraint division_cambia check (anterior <> nueva)
);

-- Mismo motivo que en las transacciones: reprocesar no puede duplicar ascensos.
create unique index if not exists player_division_history_una_por_partido_idx
  on public.player_division_history (player_id, match_id)
  where match_id is not null;

create index if not exists player_division_history_jugador_idx
  on public.player_division_history (player_id, fecha);

comment on table public.player_division_history is
  'Cada ascenso y descenso, con fecha, rating y el partido que lo provocó.';

-- ----------------------------------------------------- a qué club pertenece
-- OJO con el nombre: `club_members` (0001) son las **personas con cuenta** que
-- administran un club — dueño y staff. Esto es otra cosa: los **jugadores** que
-- ese club considera suyos, que no tienen por qué tener cuenta de nada.
--
-- Hasta ahora "el club de un jugador" se calculaba: los clubes de los torneos
-- que ha jugado. Eso vale para el historial y deja de valer para el ranking —
-- alguien que fue a un torneo de visita no debería salir en el ranking de ese
-- club, y alguien que entrena allí cada semana sí, aunque no haya jugado
-- torneos. Es una decisión del club, no un cálculo, y por eso es una tabla.
create table if not exists public.club_memberships (
  id        uuid primary key default gen_random_uuid(),
  club_id   uuid not null references public.clubs (id) on delete cascade,
  player_id uuid not null references public.players (id) on delete cascade,
  desde     date not null default current_date,
  -- Se da de baja, no se borra: "estuvo en este club" explica rankings viejos.
  activo    boolean not null default true,
  created_at timestamptz not null default now(),

  unique (club_id, player_id)
);

create index if not exists club_memberships_club_idx
  on public.club_memberships (club_id)
  where activo;
create index if not exists club_memberships_player_idx
  on public.club_memberships (player_id);

comment on table public.club_memberships is
  'Qué jugadores considera suyos un club, para los rankings locales. No '
  'confundir con club_members, que son las cuentas que administran el club.';

-- ------------------------------------------------ qué partidos ya puntuaron
-- La marca de "este partido ya pasó por el motor". Sirve para dos cosas
-- prácticas: buscar lo pendiente sin recorrer la historia entera, y saber de un
-- vistazo si un partido cargado hace un mes llegó a puntuar.
--
-- **No es lo que da la idempotencia**, aunque lo parezca. Entre leer que está a
-- null y escribirle la fecha hay una ventana, y dos procesos a la vez caben en
-- ella. Lo que cierra esa puerta es el índice único de `rating_transactions`;
-- esto es el índice de trabajo.
alter table public.matches
  add column if not exists rating_processed_at timestamptz;

-- Parcial y sobre `id`, no sobre la fecha: la columna indexada dentro del índice
-- siempre valdría null, así que no sirve de nada. Lo que importa es que el
-- índice contenga sólo lo pendiente, que es lo que se cuenta.
create index if not exists matches_pendientes_de_puntuar_idx
  on public.matches (id)
  where rating_processed_at is null;

comment on column public.matches.rating_processed_at is
  'Cuándo pasó este partido por el motor de rating. NULL es pendiente. Es un '
  'índice de trabajo, no la garantía de idempotencia: ésa la da el índice '
  'único de rating_transactions.';

-- ------------------------------------------------------ por dónde se empieza
-- La 0009 dejó `players` deliberadamente mínima y dijo que el nivel serían
-- "columnas que se añaden en una línea cuando existan". Ésta es esa línea.
--
-- Es la única **entrada** del motor que no sale de los partidos: el rating de
-- partida de quien se registra diciendo "juego en cuarta". Sin ella todo el
-- mundo arranca en 1375 y tarda decenas de partidos en llegar a su sitio, y la
-- revisión de divisiones mal declaradas (`revisarDivisionDeclarada`) no tiene
-- nada que revisar.
--
-- Texto y no enum: los nombres de división son un dato del código, que cambia
-- al recalibrar la escala o al añadir un país. NULL es "no sé", que es una
-- respuesta legítima y la más común.
alter table public.players
  add column if not exists division_declarada text;

comment on column public.players.division_declarada is
  'La división que dijo al registrarse ("4ª"), para el rating de partida. NULL '
  'es "no sé" y arranca en el centro de la escala. No es su división actual: '
  'ésa está en player_ratings y la calcula el motor.';

-- =============================================================================
-- Cómo se escribe todo esto: una función, una transacción
-- =============================================================================
-- El motor devuelve cuatro cosas a la vez —ratings, transacciones, cambios de
-- división y qué partidos se procesaron— y las cuatro tienen que entrar o no
-- entrar juntas. Guardar el rating nuevo sin su transacción deja un número que
-- nadie puede explicar; marcar el partido como procesado sin guardar el rating
-- lo pierde para siempre, porque ya no se volverá a mirar.
--
-- El cliente de Supabase no tiene transacciones: cada `insert` es su propia
-- transacción. Por eso las cuatro escrituras viven aquí dentro, donde el cuerpo
-- de la función **es** una transacción.
--
-- Y por eso no hay `on conflict do nothing` en las transacciones de rating: si
-- otro proceso se adelantó, el índice único levanta el error, esta función se
-- cae entera y no queda nada a medias. Reintentar después es inofensivo porque
-- el rating se reconstruye.
create or replace function public.aplicar_rating(
  p_ratings       jsonb,
  p_transacciones jsonb,
  p_divisiones    jsonb,
  p_partidos      uuid[],
  -- Una reconstrucción no añade: reemplaza. Cuando cambia la fórmula se vuelve
  -- a pasar el historial entero y lo anterior deja de ser cierto.
  p_desde_cero    boolean default false
)
returns void
language plpgsql
set search_path = public
as $fn$
begin
  if p_desde_cero then
    delete from public.rating_transactions;
    delete from public.player_division_history;
    delete from public.player_ratings;
    update public.matches set rating_processed_at = null
      where rating_processed_at is not null;
  end if;

  insert into public.rating_transactions (
    match_id, player_id, fecha, rating_antes, rating_despues, delta,
    probabilidad_esperada, rating_rivales, resultado, version
  )
  select
    (t->>'match_id')::uuid,
    (t->>'player_id')::uuid,
    (t->>'fecha')::date,
    (t->>'rating_antes')::double precision,
    (t->>'rating_despues')::double precision,
    (t->>'delta')::double precision,
    (t->>'probabilidad_esperada')::double precision,
    (t->>'rating_rivales')::double precision,
    (t->>'resultado')::double precision,
    t->>'version'
  from jsonb_array_elements(coalesce(p_transacciones, '[]'::jsonb)) as t;

  -- Aquí sí se ignoran los repetidos: un ascenso ya registrado es el mismo
  -- ascenso, y la reconstrucción vuelve a emitirlo tal cual.
  insert into public.player_division_history (
    player_id, match_id, fecha, escala, anterior, nueva, tipo, rating_al_cambiar
  )
  select
    (d->>'player_id')::uuid,
    (d->>'match_id')::uuid,
    (d->>'fecha')::date,
    d->>'escala',
    d->>'anterior',
    d->>'nueva',
    d->>'tipo',
    (d->>'rating_al_cambiar')::double precision
  from jsonb_array_elements(coalesce(p_divisiones, '[]'::jsonb)) as d
  on conflict (player_id, match_id) where match_id is not null do nothing;

  -- El rating sí se sobreescribe: es el estado, no el historial.
  insert into public.player_ratings (
    player_id, rating, desviacion, confianza, partidos_puntuados,
    ultimo_partido, escala, division,
    partidos_en_zona_de_ascenso, partidos_en_zona_de_descenso,
    version, calculado_at
  )
  select
    (r->>'player_id')::uuid,
    (r->>'rating')::double precision,
    (r->>'desviacion')::double precision,
    (r->>'confianza')::double precision,
    (r->>'partidos_puntuados')::int,
    nullif(r->>'ultimo_partido', '')::date,
    r->>'escala',
    r->>'division',
    (r->>'partidos_en_zona_de_ascenso')::int,
    (r->>'partidos_en_zona_de_descenso')::int,
    r->>'version',
    now()
  from jsonb_array_elements(coalesce(p_ratings, '[]'::jsonb)) as r
  on conflict (player_id) do update set
    rating             = excluded.rating,
    desviacion         = excluded.desviacion,
    confianza          = excluded.confianza,
    partidos_puntuados = excluded.partidos_puntuados,
    ultimo_partido     = excluded.ultimo_partido,
    escala             = excluded.escala,
    division           = excluded.division,
    partidos_en_zona_de_ascenso  = excluded.partidos_en_zona_de_ascenso,
    partidos_en_zona_de_descenso = excluded.partidos_en_zona_de_descenso,
    version            = excluded.version,
    calculado_at       = excluded.calculado_at;

  -- Lo último, y dentro de la misma transacción: hasta aquí el partido sigue
  -- pendiente, así que un fallo en cualquier paso anterior lo deja pendiente.
  update public.matches
     set rating_processed_at = now()
   where id = any(coalesce(p_partidos, '{}'::uuid[]));
end;
$fn$;

comment on function public.aplicar_rating(jsonb, jsonb, jsonb, uuid[], boolean) is
  'La única puerta de escritura del rating. Las cuatro escrituras en una '
  'transacción: o entran todas o no entra ninguna. Sólo la puede llamar '
  'service_role.';

-- No es `security definer`: no hace falta, porque quien la llama es el servicio
-- con la clave de servicio, que ya se salta RLS. Hacerla definer sería abrirle
-- la escritura del rating a cualquier sesión autenticada, que es justo lo que
-- las políticas de abajo cierran.
revoke execute on function
  public.aplicar_rating(jsonb, jsonb, jsonb, uuid[], boolean) from public;
grant execute on function
  public.aplicar_rating(jsonb, jsonb, jsonb, uuid[], boolean) to service_role;

-- =============================================================================
-- RLS
-- =============================================================================
-- Lectura: la misma puerta que la persona. Si puedes ver a alguien —porque
-- compartís club o porque jugó un torneo público— puedes ver su rating y cómo
-- llegó a él. Un rating que no se puede enseñar no sirve para nada.
--
-- Escritura: **ninguna política, a propósito.** Estas tablas no las escribe un
-- usuario, las escribe el servicio de rating con la clave de servicio, que se
-- salta RLS. Cualquier intento desde el panel o desde la app con la clave
-- anónima no encuentra política y se rechaza — que es la respuesta correcta:
-- un rating escrito a mano es un rating que ya no se puede reconstruir.
--
-- `club_memberships` es la excepción: sí es una decisión del club, y la toma
-- desde el panel.
-- =============================================================================

alter table public.player_ratings          enable row level security;
alter table public.rating_transactions     enable row level security;
alter table public.player_division_history enable row level security;
alter table public.club_memberships        enable row level security;

-- La misma condición que la política de `players` en la 0009, sin repetirla en
-- cuatro sitios: si la fila de la persona se ve, lo suyo también.
create or replace function public.puedo_ver_al_jugador(p_player uuid)
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select public.is_platform_admin()
    or exists (
      select 1
      from public.tournament_players tp
      where tp.player_id = p_player
        and (
          public.can_read_club(public.club_de_torneo(tp.tournament_id))
          or public.torneo_es_publico(tp.tournament_id)
        )
    )
    or exists (
      select 1
      from public.club_memberships m
      where m.player_id = p_player
        and public.can_read_club(m.club_id)
    );
$fn$;

comment on function public.puedo_ver_al_jugador(uuid) is
  'Misma puerta que la política de lectura de players: comparte club contigo o '
  'jugó un torneo público. Centralizada para que rating, transacciones e '
  'historial de división no puedan divergir de ella.';

create policy "ver el rating de quien puedes ver"
  on public.player_ratings for select
  using (public.puedo_ver_al_jugador(player_id));

create policy "ver las transacciones de quien puedes ver"
  on public.rating_transactions for select
  using (public.puedo_ver_al_jugador(player_id));

create policy "ver los cambios de division de quien puedes ver"
  on public.player_division_history for select
  using (public.puedo_ver_al_jugador(player_id));

-- ---- club_memberships ----
create policy "ver los jugadores del club propio"
  on public.club_memberships for select
  using (public.can_read_club(club_id));

create policy "el club gestiona sus jugadores"
  on public.club_memberships for all
  using (public.can_write_club(club_id))
  with check (public.can_write_club(club_id));
