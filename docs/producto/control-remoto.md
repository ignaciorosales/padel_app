# Control desde el celular — y lo que se construirá encima

Estado: **parte 1 construida** (árbitro desde el celular). **Parte 2 planeada,
sin empezar** (llevarse el partido al perfil). Última revisión: 2026-11-01.

## Parte 1 — El árbitro desde el celular (construido)

En torneos, una persona fuera de la pista anota los puntos desde su celular:
suma, quita, cambia de lado cuando hace falta (los cambios raros: impares, a
mitad de set...) y pone los nombres de los jugadores en vez de "verde" y
"negro".

```
celular (navegador) ──WiFi local──► tele: servidor HTTP :8080 ──► HardwareCommandHandler
                                     sirve la página y la API       (lo mismo que las cajas)
```

- **No hace falta internet.** Hace falta que el celular y la tele estén en la
  misma red: WiFi del club (aunque no tenga salida a internet), un router de
  viaje junto a la tele, o el hotspot del propio celular. Lo único que no vale
  es una WiFi de invitados con *aislamiento de clientes*.
- **PIN del club**, de 4 a 8 cifras, en Ajustes ▸ Celular. La tele no lo
  muestra nunca, porque la ve el público. El QR de Ajustes solo lleva la
  dirección. Cambiar el PIN echa a todos los celulares conectados. Cinco
  intentos fallidos bloquean esa IP durante un minuto.
- **Los comandos son por pareja, no por lado**: "punto para la pareja 1", no
  "punto a la izquierda". Así un cambio de lado no le cambia al árbitro qué
  botón es de quién. La página dibuja las parejas en el mismo lado en el que
  las muestra la tele.
- **Ni un punto doble por un corte de red.** Cada pulsación lleva un `id`, y
  la tele ignora los que ya ha visto.
- **Las cajas siguen funcionando a la vez.** El protocolo de las cajas
  ([protocol/README.md](../protocol/README.md)) no cambia.

Código:

| Pieza | Fichero |
|---|---|
| Servidor + API | [app/lib/features/remote/remote_control_service.dart](../../app/lib/features/remote/remote_control_service.dart) |
| Página del celular | [app/assets/remote/arbitro.html](../../app/assets/remote/arbitro.html) |
| Ajustes ▸ Celular | [app/lib/features/remote/remote_settings_tab.dart](../../app/lib/features/remote/remote_settings_tab.dart) |
| Nombres de jugadores | [app/lib/config/team_selection_service.dart](../../app/lib/config/team_selection_service.dart) (`players1`/`players2`, `nameFor`) |
| Tests | [app/test/remote_control_test.dart](../../app/test/remote_control_test.dart) |

### La API es un contrato: `/api/v1/`

La página del árbitro es el **primer** cliente, no el único. El panel, una app
del jugador o una app propia del club hablarán con la tele por el mismo
camino. Por eso:

- todo cuelga de `/api/v1/`, y `GET /api/v1/info` devuelve `{app, api}` sin
  PIN, para que un cliente sepa que habla con una tele Puntazo y qué versión
  entiende;
- **añadir** campos o acciones nuevas está bien: los clientes ignoran lo que
  no conocen;
- **cambiar o quitar** un campo existente obliga a abrir `/api/v2/` y mantener
  `v1` mientras haya clientes que lo usen.

La tabla de rutas está en el comentario de cabecera de
`remote_control_service.dart`, al lado del código que la implementa.

## Parte 2 — Llevarse el partido al perfil (planeado, sin empezar)

El objetivo: al terminar, cada jugador escanea un QR en la tele y el partido
entra en su historial, con estadísticas punto a punto. Es la "fase 4c" de
[app-jugador.md](app-jugador.md), y encaja en lo que ya existe:

- **Perfiles e historial**: `players` (con `user_id`), `/j/<jugador>`,
  `web/src/lib/historial/`.
- **El partido de marcador ya tiene su sitio**: `friendly_matches.origen_confirmado`
  admite `'marcador'` ([0015](../../backend/migrations/0015_confirmacion_de_resultados.sql)).
- **El QR firmado** está diseñado en [README.md ▸ "la pista no tiene red"](README.md).

### La pieza central: el acta del partido

Al terminar, la tele arma un **acta**: id, pista, inicio y fin, unidad, sets,
traza de puntos con tiempos, los cuatro nombres y, si era de torneo, el
`match_id`. Va firmada con HMAC-SHA256 y la clave de la pista. Son unos 400
bytes, y un QR admite unos 2900.

El acta llega a la web por **dos caminos**, y la web la trata igual venga por
donde venga:

1. **QR en la pantalla del ganador**, uno por pareja, para saber el lado sin
   preguntar. Lleva la URL `https://<dominio>/m#<acta>`; va después del `#`
   para que no quede en los registros del servidor. El jugador la abre con sus
   datos móviles, inicia sesión y elige cuál de los dos nombres es él.
2. **Por la red local de la parte 1**: una ruta nueva, `GET /api/v1/actas`.
   Si el celular del árbitro tiene datos, sube el acta al panel y en un torneo
   el resultado entra solo, sin escanear nada.

La tele guarda las últimas ~50 actas, para que se puedan escanear más tarde.

### Las dos llaves

| Llave | Para qué | Quién la sabe |
|---|---|---|
| PIN del club (ya existe) | entrar como árbitro | el personal del club |
| Clave de la pista (nueva) | firmar actas: nadie se fabrica partidos ganados | la tele y el servidor |

La clave la genera la tele. En Ajustes ▸ Celular, el botón "Vincular pista"
la muestra en un QR que el encargado escanea con el panel abierto. Para ver
ese botón hay que escribir el PIN.

### Pasos, cuando toque

1. **Tele**: armar y firmar el acta a partir de la pila de `MatchScore`; QR en
   [winner_overlay.dart](../../app/lib/features/widgets/winner_overlay.dart);
   guardar las últimas actas; añadir `GET /api/v1/actas`.
2. **Contrato**: `docs/protocol/acta.md` más **un acta de ejemplo con su
   firma**, comprobada en `flutter test` y en `npm test`. Si un lado cambia el
   formato sin el otro, falla un test.
3. **Web** (migración nueva, con el número reservado en `develop`):
   - pistas vinculadas: id, club y clave;
   - actas recibidas: id, contenido y quién reclamó cada lado;
   - página `/m`, que verifica la firma y pregunta "¿cuál de los dos eres?".
4. **Cuando los cuatro han reclamado**: `friendly_match` con
   `origen_confirmado = 'marcador'`, que mueve el nivel. Con menos de cuatro,
   el partido queda en el historial de quienes lo reclamaron, sin puntuar, y
   el club puede completar el resto desde el panel.
5. **Torneos**: la página del árbitro, si tiene datos, pide al panel "qué
   partido toca" en esa pista y le pasa a la tele los nombres y el `match_id`.

### Decisión pendiente

Un partido de marcador con solo 2 de los 4 identificados, ¿mueve el nivel de
esos 2? La recomendación es que **no**: sin los cuatro no se conoce el nivel
del rival. Se queda como actividad, igual que un amistoso cargado a mano.
