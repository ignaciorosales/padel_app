-- =============================================================================
-- Puntazo · 0013 · Importe de la inscripción
-- =============================================================================
-- La decisión de docs/producto/README.md sobre cobros: «Fuera, pero con sitio.
-- No construir nada. Sí dejar ficha de cliente mínima y un importe con estado
-- pendiente/pagado en cada inscripción: dos campos que evitan una migración
-- dentro de un año.»
--
-- Esto es exactamente eso y ni un campo más. No hay caja, ni bonos, ni recibos,
-- ni pasarela de pago, ni historial de movimientos. El club sigue cobrando como
-- cobra hoy —efectivo, Bizum, lo que sea— y aquí sólo apunta si ya cobró.
--
-- La ficha de cliente mínima ya estaba: `tournament_players` guarda nombre y
-- teléfono desde la 0003. Faltaba el dinero.
--
-- POR QUÉ EN EL JUGADOR Y NO EN LA PAREJA
-- ---------------------------------------
-- En un americano cada uno se apunta solo y paga lo suyo, así que el importe es
-- del jugador. En un torneo de parejas paga la pareja, pero la pareja son dos
-- filas de `tournament_players` (la 0006 la construyó así): la mitad a cada
-- uno, o todo a uno y cero al otro, según cómo lo hayan repartido ellos. Un
-- importe en `tournament_pairs` obligaría a mirar en dos sitios distintos según
-- el formato del torneo para responder a «¿quién me debe dinero?».
--
-- POR QUÉ `numeric` Y NO CÉNTIMOS EN UN `int`
-- -------------------------------------------
-- Los céntimos en un entero son la respuesta correcta cuando se hacen cuentas
-- —IVA, prorrateos, divisas—. Aquí no se hace ninguna: se guarda lo que el club
-- escribe y se suma para enseñar un total. `numeric(8,2)` guarda «12.50» tal
-- cual, se lee en el editor SQL sin dividir por cien, y aguanta importes de
-- hasta 999.999,99 €, que no van a pasar.
-- =============================================================================

alter table public.tournament_players
  -- Nulo = este torneo no cobra, o todavía no se ha puesto precio. Distinto de
  -- 0, que es «éste no paga» (el organizador, un invitado, un socio con bono).
  add column importe numeric(8,2) check (importe >= 0),
  add column pagado  boolean not null default false;

-- «¿Quién me debe dinero?» es la única consulta que va a existir sobre esto.
create index tournament_players_pendientes_idx
  on public.tournament_players (tournament_id)
  where pagado = false and importe is not null and importe > 0;

comment on column public.tournament_players.importe is
  'Lo que paga esta persona por la inscripción. Nulo si el torneo no cobra. Ver docs/producto/README.md, decisión sobre cobros.';

comment on column public.tournament_players.pagado is
  'Si el club ya cobró. No hay pasarela de pago: lo marca el encargado a mano.';

-- =============================================================================
-- Cerrar la puerta que estas dos columnas acaban de abrir
-- =============================================================================
-- `tournament_players` es legible sin sesión cuando el torneo es público: es lo
-- que hace funcionar la página que se pega en WhatsApp, sin cuentas ni servidor
-- intermedio. Hasta hoy esa tabla sólo tenía nombre, teléfono y orden.
--
-- Con `importe` y `pagado` dentro, esa misma puerta deja de ser inofensiva:
-- cualquiera con el enlace de un torneo —y la clave anónima, que es pública por
-- diseño— podría preguntarle a la API cuánto ha pagado cada socio y quién le
-- debe dinero al club. Los datos de dinero de un club no se enseñan porque
-- alguien comparta un cuadro en un grupo de WhatsApp.
--
-- Dos cierres, porque hacen falta los dos:

-- 1) Por columna, para el anónimo. RLS decide QUÉ FILAS se ven; los permisos de
--    columna deciden QUÉ CAMPOS. Sólo lo segundo sirve aquí, porque las filas
--    sí tienen que verse: la página pública lista a los jugadores.
--
--    Va también `telefono`, que no es nuevo pero llevaba abierto desde la 0003
--    por el mismo camino: la página pública hacía `select *` y el número de
--    móvil de los 24 socios salía en la respuesta. Nadie lo pintaba, y daba
--    igual — con la clave anónima, que va en el navegador, bastaba preguntar
--    por la API. Un teléfono es un dato personal y el club responde de él.
--
--    OJO CON LA FORMA DE ESCRIBIRLO. Lo natural sería
--
--        revoke select (importe, pagado, telefono) ... from anon;
--
--    y no serviría de nada: en Postgres, un permiso de columna no resta de uno
--    de tabla, y Supabase le concede `select` sobre la tabla entera a `anon`.
--    Quedaría una migración que parece que cierra la puerta y la deja abierta.
--    Hay que quitar el permiso de tabla y conceder las columnas que sí.
--
--    Efecto de rebote buscado: `select *` con la clave anónima pasa a fallar en
--    vez de devolver de más. La página pública pide columnas por su nombre
--    (`lib/torneo/publico.ts`), así que un `select *` que se cuele en el futuro
--    se cae en desarrollo en lugar de filtrar en producción.
revoke select on public.tournament_players from anon;
grant  select (id, tournament_id, nombre, orden) on public.tournament_players to anon;

-- 2) Por rol, para el resto. La política de la 0003 dejaba ver los inscritos de
--    cualquier torneo público a cualquiera con sesión iniciada, y eso incluye
--    al personal de OTRO club: son pocas cuentas y todas creadas a mano, pero
--    «pocos y de fiar» no es un control de acceso.
--
--    La lectura pública se acota al rol `anon`, que es exactamente quien la
--    necesita: el cliente de la página pública va sin cookies (ver
--    `lib/supabase/publico.ts`), así que la ve como anónimo aunque quien mire
--    tenga sesión abierta en su club.
--
--    Los administradores de plataforma no pierden nada: entran por
--    can_read_club(), que ya los contempla.
drop policy if exists "ver inscritos del club o de torneos públicos"
  on public.tournament_players;

create policy "ver inscritos del club"
  on public.tournament_players for select
  to authenticated
  using (public.can_read_club(public.club_de_torneo(tournament_id)));

create policy "ver inscritos de un torneo público"
  on public.tournament_players for select
  to anon
  using (public.torneo_es_publico(tournament_id));
