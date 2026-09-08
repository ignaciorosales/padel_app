-- =============================================================================
-- Puntazo · 0015 · Confirmación de resultados
-- =============================================================================
-- Hasta aquí sólo puntúan los partidos de un torneo, porque son los únicos que
-- existen. Un amistoso del martes por la noche —cuatro personas, un marcador y
-- nadie organizando nada— no tiene dónde guardarse, y es la mitad de los
-- partidos que se juegan en un club.
--
-- El problema no es guardarlo: es creérselo. Un resultado que escribe uno de los
-- cuatro no vale lo mismo que uno que sale del marcador de la pista, y si valiera
-- igual el rating se rompe en una semana — basta con que alguien se invente
-- victorias. De ahí la regla: **un amistoso nace sin puntuar y sólo puntúa
-- cuando los cuatro lo aceptan.**
--
-- ## Por qué una tabla nueva y no una fila más en `matches`
--
-- Porque los cuatro jugadores de `matches` son `tournament_players`: inscritos de
-- un torneo concreto, con su nombre escrito a mano esa mañana. Los de un amistoso
-- son `players`: personas. No es una diferencia de matiz, es que las claves
-- ajenas apuntan a otra tabla, y forzarlo obligaría a inventar un torneo fantasma
-- por cada partido suelto.
--
-- Lo que sí se comparte es todo lo que viene después: las dos clases de partido
-- entran al mismo motor, dejan transacciones en la misma tabla y salen en el
-- mismo historial. La diferencia se queda aquí abajo.
--
-- ## Dos columnas que parecen la misma y no lo son
--
-- `estado` es el ciclo de vida: pendiente, confirmado o rechazado.
-- `origen_confirmado` es de dónde salió el resultado, y decide cuánto se fía el
-- sistema **una vez** confirmado: 0,8 si lo confirmaron los jugadores, 0,9 si lo
-- cargó el club, 1 si vino del marcador de la pista.
--
-- No se contradicen porque no hablan de lo mismo, y el origen que ve el motor se
-- deriva de las dos en un solo sitio (`lib/rating/amistosos.ts`). Guardar el
-- origen ya derivado sería la tercera columna que tarde o temprano no cuadra con
-- las otras dos.
-- =============================================================================

-- --------------------------------------------------------- quién eres tú aquí
-- La 0009 dejó `players` sin cuenta de acceso y dijo que eso serían "columnas
-- que se añaden en una línea cuando existan". Ésta es esa línea, y llega ahora
-- porque la confirmación es la primera cosa del sistema que necesita saber
-- **quién** está mirando: sin esto, "los cuatro lo aceptan" no se puede escribir
-- en una política.
--
-- Sigue siendo opcional, y va a serlo mucho tiempo: la inmensa mayoría de los
-- jugadores de un club no tienen la app, y sus partidos de torneo puntúan igual.
alter table public.players
  add column if not exists user_id uuid references auth.users (id) on delete set null;

-- Una cuenta es una persona. Dos filas de `players` con la misma cuenta serían
-- dos historiales que se pisan.
create unique index if not exists players_user_idx
  on public.players (user_id)
  where user_id is not null;

comment on column public.players.user_id is
  'La cuenta con la que este jugador entra en la app, si tiene. NULL es lo '
  'normal: la mayoría de los jugadores de un club no tienen cuenta y sus '
  'partidos de torneo puntúan igual.';

create or replace function public.jugador_de_la_sesion()
returns uuid
language sql stable security definer set search_path = public
as $fn$
  select p.id from public.players p where p.user_id = auth.uid();
$fn$;

comment on function public.jugador_de_la_sesion() is
  'Qué persona es quien está mirando, o NULL si su cuenta no está enlazada a '
  'ningún jugador. Es la pieza que permite escribir "los cuatro lo aceptan" en '
  'una política.';

-- ----------------------------------------------------------- los amistosos
create table if not exists public.friendly_matches (
  id      uuid primary key default gen_random_uuid(),
  -- Dónde se jugó. Opcional y sin `not null`: un amistoso puede ser en una pista
  -- municipal, y el rating no depende de esto. Sirve para los rankings de club y
  -- para que el club vea lo que pasa en sus pistas.
  club_id uuid references public.clubs (id) on delete set null,
  fecha   date not null,

  a1 uuid not null references public.players (id) on delete cascade,
  a2 uuid not null references public.players (id) on delete cascade,
  b1 uuid not null references public.players (id) on delete cascade,
  b2 uuid not null references public.players (id) on delete cascade,

  marcador_a int not null check (marcador_a >= 0),
  marcador_b int not null check (marcador_b >= 0),
  -- La misma lista que `tournaments.unidad_marcador`: el marcador de un amistoso
  -- se lee igual que el de un torneo.
  unidad text not null default 'juegos'
    check (unidad in ('juegos', 'sets', 'puntos')),

  -- El ciclo de vida. Nace pendiente siempre que lo cargue un jugador; el club
  -- puede crearlo ya confirmado, porque el club es la autoridad de sus pistas.
  estado text not null default 'pendiente'
    check (estado in ('pendiente', 'confirmado', 'rechazado')),
  -- Qué confianza le toca cuando esté confirmado. No incluye 'sin_puntuar' a
  -- propósito: eso no es un origen, es el estado de no estar confirmado todavía.
  origen_confirmado text not null default 'confirmado'
    check (origen_confirmado in ('confirmado', 'club', 'liga', 'marcador')),

  -- Quién lo cargó, para poder decir "lo apuntó Nacho" en la petición de
  -- confirmación. Es una cuenta, no un jugador: puede haberlo cargado el club.
  creado_por uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),

  -- Misma marca y mismo significado que en `matches`.
  rating_processed_at timestamptz,

  -- Un 0-0 no distingue "empataron a cero" de "se anotó y no se jugó". En un
  -- torneo eso se descarta al puntuar; aquí no hay razón para aceptarlo.
  constraint amistoso_jugado check (marcador_a + marcador_b > 0),
  constraint amistoso_cuatro_distintos check (
    a1 <> a2 and a1 <> b1 and a1 <> b2 and a2 <> b1 and a2 <> b2 and b1 <> b2
  )
);

create index if not exists friendly_matches_fecha_idx
  on public.friendly_matches (fecha desc);
create index if not exists friendly_matches_club_idx
  on public.friendly_matches (club_id, fecha desc)
  where club_id is not null;
create index if not exists friendly_matches_pendientes_idx
  on public.friendly_matches (id)
  where rating_processed_at is null;

comment on table public.friendly_matches is
  'Partidos sueltos, fuera de torneo. Sus cuatro jugadores son personas '
  '(players), no inscritos de un torneo, y por eso no caben en matches.';

-- ------------------------------------------------------- quién dice que sí
-- Una fila por respuesta. La ausencia de fila es "todavía no ha contestado", que
-- es distinto de "ha dicho que no" — y la diferencia importa: al que no contesta
-- se le puede recordar, al que dice que no hay que preguntarle qué pasó.
create table if not exists public.friendly_match_confirmations (
  match_id   uuid not null references public.friendly_matches (id) on delete cascade,
  player_id  uuid not null references public.players (id) on delete cascade,
  respuesta  text not null check (respuesta in ('acepta', 'rechaza')),
  respondido_at timestamptz not null default now(),

  primary key (match_id, player_id)
);

comment on table public.friendly_match_confirmations is
  'Qué ha contestado cada uno de los cuatro. Sin fila es "no ha contestado", '
  'que no es lo mismo que haber dicho que no.';

-- ------------------------------------------- el estado lo calcula la base
-- Se decide con un disparador y no en el código de la app por una razón: hay
-- cuatro personas escribiendo desde cuatro móviles, y el último en aceptar es el
-- que confirma el partido. Si esa cuenta la hiciera la app, dos respuestas
-- simultáneas podrían dejar el partido pendiente para siempre — las dos verían
-- tres aceptaciones.
--
-- Aquí no: cada respuesta recuenta, dentro de la misma transacción que la
-- escribe.
create or replace function public.recalcular_estado_del_amistoso()
returns trigger
language plpgsql
security definer set search_path = public
as $fn$
declare
  v_match   uuid;
  v_acepta  int;
  v_rechaza int;
begin
  -- En un disparador de DELETE, `new` no está asignado y leerle un campo es un
  -- error de ejecución, no un null. Por eso se pregunta por la operación.
  if tg_op = 'DELETE' then
    v_match := old.match_id;
  else
    v_match := new.match_id;
  end if;

  select
    count(*) filter (where c.respuesta = 'acepta'),
    count(*) filter (where c.respuesta = 'rechaza')
  into v_acepta, v_rechaza
  from public.friendly_match_confirmations c
  join public.friendly_matches m on m.id = v_match
  where c.match_id = v_match
    -- Sólo cuentan los cuatro que jugaron. Una confirmación de alguien que no
    -- está en el partido no debería existir, y si existe no decide nada.
    and c.player_id in (m.a1, m.a2, m.b1, m.b2);

  update public.friendly_matches m
     set estado = case
           -- Uno que dice que no lo tumba. Es asimétrico a propósito: el coste
           -- de no puntuar un partido real es que no cuenta; el de puntuar uno
           -- inventado es que el rating deja de significar nada.
           when v_rechaza > 0 then 'rechazado'
           when v_acepta >= 4 then 'confirmado'
           else 'pendiente'
         end
   where m.id = v_match
     -- Un amistoso que el club cargó ya confirmado no lo cambia nadie
     -- contestando: la autoridad de sus pistas es el club.
     and m.origen_confirmado <> 'club';

  return null;
end;
$fn$;

drop trigger if exists recalcular_estado_del_amistoso
  on public.friendly_match_confirmations;

create trigger recalcular_estado_del_amistoso
  after insert or update or delete on public.friendly_match_confirmations
  for each row execute function public.recalcular_estado_del_amistoso();

-- ================================================================= el rating
-- Las transacciones y los cambios de división tienen que poder colgar de las dos
-- clases de partido. Dos columnas anulables con la garantía de que exactamente
-- una está puesta, y no una columna suelta sin clave ajena: la 0014 se apoya en
-- que borrar un partido se lleve su auditoría por delante, y eso sólo lo hace
-- una clave ajena de verdad.
alter table public.rating_transactions
  alter column match_id drop not null;

alter table public.rating_transactions
  add column if not exists friendly_match_id uuid
    references public.friendly_matches (id) on delete cascade;

alter table public.rating_transactions
  drop constraint if exists transaccion_de_un_solo_partido;
alter table public.rating_transactions
  add constraint transaccion_de_un_solo_partido check (
    (match_id is not null and friendly_match_id is null)
    or (match_id is null and friendly_match_id is not null)
  );

-- El índice único de la 0014 sólo cubría `matches`; los amistosos necesitan el
-- suyo, y por el mismo motivo: es lo que hace idempotente el proceso cuando dos
-- pasadas coinciden.
create unique index if not exists rating_transactions_un_amistoso_idx
  on public.rating_transactions (friendly_match_id, player_id)
  where friendly_match_id is not null;

alter table public.player_division_history
  add column if not exists friendly_match_id uuid
    references public.friendly_matches (id) on delete set null;

create unique index if not exists player_division_history_un_amistoso_idx
  on public.player_division_history (player_id, friendly_match_id)
  where friendly_match_id is not null;

-- ------------------------------------------------------ la puerta de escritura
-- Misma función que en la 0014, con los amistosos dentro. Sigue siendo la única
-- forma de escribir el rating, y sigue siendo una sola transacción.
create or replace function public.aplicar_rating(
  p_ratings       jsonb,
  p_transacciones jsonb,
  p_divisiones    jsonb,
  p_partidos      uuid[],
  p_desde_cero    boolean default false,
  p_amistosos     uuid[] default '{}'::uuid[]
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
    update public.friendly_matches set rating_processed_at = null
      where rating_processed_at is not null;
  end if;

  insert into public.rating_transactions (
    match_id, friendly_match_id, player_id, fecha,
    rating_antes, rating_despues, delta,
    probabilidad_esperada, rating_rivales, resultado, version
  )
  select
    nullif(t->>'match_id', '')::uuid,
    nullif(t->>'friendly_match_id', '')::uuid,
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

  insert into public.player_division_history (
    player_id, match_id, friendly_match_id, fecha, escala,
    anterior, nueva, tipo, rating_al_cambiar
  )
  select
    (d->>'player_id')::uuid,
    nullif(d->>'match_id', '')::uuid,
    nullif(d->>'friendly_match_id', '')::uuid,
    (d->>'fecha')::date,
    d->>'escala',
    d->>'anterior',
    d->>'nueva',
    d->>'tipo',
    (d->>'rating_al_cambiar')::double precision
  from jsonb_array_elements(coalesce(p_divisiones, '[]'::jsonb)) as d
  on conflict do nothing;

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

  update public.matches
     set rating_processed_at = now()
   where id = any(coalesce(p_partidos, '{}'::uuid[]));

  update public.friendly_matches
     set rating_processed_at = now()
   where id = any(coalesce(p_amistosos, '{}'::uuid[]));
end;
$fn$;

comment on function
  public.aplicar_rating(jsonb, jsonb, jsonb, uuid[], boolean, uuid[]) is
  'La única puerta de escritura del rating, torneos y amistosos incluidos. Las '
  'escrituras en una transacción: o entran todas o no entra ninguna. Sólo la '
  'puede llamar service_role.';

revoke execute on function
  public.aplicar_rating(jsonb, jsonb, jsonb, uuid[], boolean, uuid[]) from public;
grant execute on function
  public.aplicar_rating(jsonb, jsonb, jsonb, uuid[], boolean, uuid[]) to service_role;

-- La firma de cinco argumentos de la 0014 ya no se usa: dejarla viva sería dejar
-- una puerta que no marca los amistosos como procesados.
drop function if exists
  public.aplicar_rating(jsonb, jsonb, jsonb, uuid[], boolean);

-- =============================================================================
-- RLS
-- =============================================================================
-- Un amistoso lo ven los cuatro que jugaron y el club donde se jugó. Nadie más:
-- a diferencia de un torneo, aquí no hay nada público.
--
-- Escribir tiene tres puertas distintas y conviene verlas juntas:
--   · crear: uno de los cuatro, o el club de la pista;
--   · confirmar: sólo tú, sólo tu propia respuesta;
--   · corregir el marcador: nadie. Se borra y se vuelve a cargar, porque un
--     marcador cambiado después de que tres personas lo aceptaran convierte la
--     confirmación en un trámite.
-- =============================================================================

alter table public.friendly_matches             enable row level security;
alter table public.friendly_match_confirmations enable row level security;

create or replace function public.juego_el_amistoso(p_match uuid)
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select exists (
    select 1
    from public.friendly_matches m
    where m.id = p_match
      and public.jugador_de_la_sesion() in (m.a1, m.a2, m.b1, m.b2)
  );
$fn$;

create policy "ver los amistosos propios o los de tu club"
  on public.friendly_matches for select
  using (
    public.is_platform_admin()
    or (club_id is not null and public.can_read_club(club_id))
    or public.jugador_de_la_sesion() in (a1, a2, b1, b2)
  );

-- Crear: o eres uno de los cuatro, o eres el club de la pista. El `estado` no se
-- puede elegir desde aquí más que a través de `origen_confirmado`, que es lo que
-- distingue "lo cargó el club" de "lo cargó un jugador".
create policy "cargar un amistoso que jugaste"
  on public.friendly_matches for insert
  to authenticated
  with check (
    (
      public.jugador_de_la_sesion() in (a1, a2, b1, b2)
      and estado = 'pendiente'
      and origen_confirmado = 'confirmado'
    )
    or (
      club_id is not null
      and public.can_write_club(club_id)
      and origen_confirmado = 'club'
    )
  );

-- Borrar: quien lo cargó, mientras nadie haya contestado todavía, y el club de
-- sus pistas. Un amistoso ya confirmado no se borra desde la app: ya movió el
-- rating de cuatro personas.
create policy "borrar un amistoso que cargaste y nadie ha tocado"
  on public.friendly_matches for delete
  using (
    public.is_platform_admin()
    or (club_id is not null and public.can_write_club(club_id))
    or (
      creado_por = auth.uid()
      and estado = 'pendiente'
      and not exists (
        select 1
        from public.friendly_match_confirmations c
        where c.match_id = friendly_matches.id
      )
    )
  );

-- ---- confirmaciones ----
create policy "ver las respuestas de un amistoso que puedes ver"
  on public.friendly_match_confirmations for select
  using (
    public.is_platform_admin()
    or public.juego_el_amistoso(match_id)
    or exists (
      select 1
      from public.friendly_matches m
      where m.id = match_id
        and m.club_id is not null
        and public.can_read_club(m.club_id)
    )
  );

-- Contestas tú, por ti, y sólo si jugaste. Las tres condiciones en la misma
-- política porque las tres son la misma frase.
create policy "contestar por ti a un amistoso que jugaste"
  on public.friendly_match_confirmations for insert
  to authenticated
  with check (
    player_id = public.jugador_de_la_sesion()
    and public.juego_el_amistoso(match_id)
  );

-- Cambiar de respuesta se permite: alguien acepta sin mirar y luego ve que el
-- marcador está al revés. El disparador recalcula el estado, así que retirar una
-- aceptación devuelve el partido a pendiente y deja de puntuar en la siguiente
-- pasada — que es exactamente lo que tiene que pasar.
create policy "cambiar tu propia respuesta"
  on public.friendly_match_confirmations for update
  using (player_id = public.jugador_de_la_sesion())
  with check (player_id = public.jugador_de_la_sesion());
