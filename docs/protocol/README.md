# Protocolo Puntazo — contrato entre las 3 capas

Este documento es la **única fuente de verdad** del protocolo. Si cambias algo
aquí, tienes que tocar las tres capas a la vez (ver [Checklist](#checklist-para-cambiar-el-protocolo)).

## Cadena completa

```
┌─────────────┐   RS-485      ┌─────────────┐   USB serial   ┌──────────────┐
│  ≤8 cajas   │  9600 8N1     │   maestro   │  115200 8N1    │  app Flutter │
│  ESP32-C3   │ ────────────► │  ESP32-C3   │ ─────────────► │  Android TV  │
│ ID = su MAC │   (polling)   │ las aprende │  texto plano   │              │
└─────────────┘               └─────────────┘                └──────────────┘
  botones P/U/G                 poll round-robin               BoxPairingService
  + ToF VL6180X                 + descubrimiento               decide el lado
```

Código de cada capa:

| Capa | Fichero |
|---|---|
| Esclavo | [firmware/esclavo/esclavo.ino](../../firmware/esclavo/esclavo.ino) |
| Maestro | [firmware/maestro/maestro.ino](../../firmware/maestro/maestro.ino) |
| App (lectura) | [app/lib/features/usb_serial/simple_usb_serial_listener.dart](../../app/lib/features/usb_serial/simple_usb_serial_listener.dart) |
| App (lógica) | [app/lib/features/match_control/hardware_command_handler.dart](../../app/lib/features/match_control/hardware_command_handler.dart) |
| App (emparejado) | [app/lib/config/box_pairing_service.dart](../../app/lib/config/box_pairing_service.dart) |

---

## Capa 1 — RS-485 (esclavo ↔ maestro)

**9600 baudios, 8N1.** El maestro es el único que inicia; los esclavos solo
responden cuando se les pregunta por su ID.

### Trama maestro → esclavo (petición, 7 bytes)

```
[0xA0, devLo, devHi, 0x01, crcLo, crcHi, 0x55]
  │      │      │      │       │           └─ fin de trama
  │      │      │      │       └───────────── CRC16-CCITT de los 4 primeros bytes
  │      │      │      └───────────────────── 0x01 = poll, 0x02 = descubrimiento
  │      └──────┴──────────────────────────── ID del esclavo, little-endian
  └─────────────────────────────────────────── inicio de trama
```

| `req` | ID | Quién contesta |
|---|---|---|
| `0x01` poll | el de una caja | esa caja, siempre |
| `0x02` descubrimiento | `0xFFFF` | solo una caja que el maestro **no conoce** y que **alguien está pulsando** |

El ID, el `req` y el CRC pueden contener `0xA0` o `0xAA`. Ninguno de los dos
lectores puede reiniciar la trama al ver la cabecera en medio: acumulan 7
bytes y, si no validan, descartan solo el primero y buscan cabecera en lo ya
leído. Con el lector antiguo del esclavo, el 1,5 % de los IDs posibles no
contestaba nunca.

### Trama esclavo → maestro (respuesta, 7 bytes)

```
[0xAA, devLo, devHi, cmd, crcLo, crcHi, 0x55]
```

`cmd` es un único byte ASCII:

| `cmd` | Significado |
|---|---|
| `'p'` | Punto |
| `'u'` | Deshacer (undo) |
| `'g'` | Reiniciar / start |
| `'n'` | Nada que reportar |

### IDs de las cajas

**No hay IDs fijos.** El ID de cada caja son los 2 últimos bytes de su MAC de
fábrica (`ESP.getEfuseMac()`), que es única por chip: todas las cajas llevan
el mismo firmware, sin editar nada. `0x0000` y `0xFFFF` (el ID de
descubrimiento) se evitan con `id ^= 0x5A5A`. Las placas de un lote tienen MAC
consecutivas, así que en la práctica no se repiten; si dos coincidieran, el
asistente de la app solo vería una.

### Descubrimiento

El maestro no tiene lista fija: **aprende las cajas cuando alguien las pulsa**
y las guarda en flash (NVS, `puntazo/boxes`), así que un corte de luz no las
borra.

1. Cada `DISCOVER_EVERY` vueltas manda la pregunta general (`0xFFFF`, `0x02`).
2. Una caja contesta solo si el maestro no le ha preguntado por su ID en
   `UNKNOWN_AFTER_MS` (no la conoce) **y** tiene una pulsación pendiente. Como
   solo se pulsa una caja cada vez, no hablan dos a la vez.
3. La respuesta es la normal, con el ID propio y la pulsación. El maestro la
   apunta, emite `[EVT] dev=XXXX new` y reenvía el `BTN:` como siempre: la
   pulsación no se pierde.
4. La app, al **terminar** su asistente, envía `KEEP <id>…` y el maestro olvida
   las cajas que no se pulsaron. Cancelar el asistente no envía nada.

> El maestro **no** decide equipo ni lado: solo reenvía el ID. El lado de
> cada caja lo decide la app (Capa 3).

### Temporización

| Parámetro | Valor | Dónde |
|---|---|---|
| `RS485_POST_TX_US` | 200 µs | ambos |
| `RS485_SLAVE_REPLY_DELAY_US` | 1500 µs | esclavo |
| `COMMAND_DEBOUNCE_MS` | 200 ms | maestro (anti-duplicado por esclavo) |
| `DEBOUNCE_MS` | 80 ms | esclavo (rebote de botón) |
| `POINT_COOLDOWN_MS` | 500 ms | esclavo (entre dos puntos de la misma caja) |
| `POLL_WAIT_MS` | 70 ms | maestro (espera de respuesta a un poll) |
| `DISCOVER_EVERY` | 4 vueltas | maestro (frecuencia del descubrimiento) |
| `DISCOVER_WAIT_MS` | 30 ms | maestro (la respuesta llega a los ~16 ms) |
| `UNKNOWN_AFTER_MS` | 1500 ms | esclavo (sin poll propio = el maestro no la conoce) |
| `NO_POLL_RESTART_MS` | 10 s | esclavo (sin oír al maestro, se reinicia) |
| `WDT_TIMEOUT_MS` | 5 s | ambos (watchdog: si el loop se cuelga, reinicio) |

---

## Capa 2 — USB serial (maestro → app)

**115200 baudios, 8N1, texto plano terminado en `\n`.**

### Comandos

```
BTN:<idHex4>:<P|U|G>
```

Ejemplos: `BTN:0201:P`, `BTN:0203:U`, `BTN:0204:G`

Emitido en [maestro.ino:287](../../firmware/maestro/maestro.ino) con
`printf("BTN:%04X:%c\n", slaveId, letter)` — el ID va en **hex de 4 dígitos y
mayúsculas**.

La app lo valida con la expresión regular `^BTN:[0-9A-F]{1,4}:[PUG]$`.

### Líneas de depuración

Todo lo que el maestro imprime con prefijo `[` (p. ej. `[INFO] RS-485: 9600 baud`,
`[RS485 DBG] rxBytes=...`) es **diagnóstico**, no un comando. La app las filtra y
las muestra en el panel de diagnóstico USB, pero nunca las interpreta como puntos.

### Comandos heredados

La app todavía acepta la familia antigua `P_A`, `P_B`, `UNDO_A`, `UNDO_B`,
`RESET`, `PONG`. El firmware actual **ya no los emite**: en esa generación el
maestro decidía el equipo, y por eso se cambió. Se mantienen solo para poder
probar con hardware viejo.

---

## Telemetría del maestro (firmware v2+)

Además de los comandos, el maestro publica su estado y el de cada caja. Son
líneas con prefijo `[`, así que la app las trata como diagnóstico y **nunca**
como puntuación: un firmware viejo sin ellas sigue funcionando igual.

Se emiten **cada 2 segundos**, y de forma inmediata si la app envía `STATUS`.

### `[PS]` — una línea por caja

```
[PS] dev=0201 on=1 rep=412 to=3 crc=0 cmd=7 rtt=18 age=31
```

| Campo | Significado |
|---|---|
| `dev` | ID de la caja, hex de 4 dígitos |
| `on` | `1` si responde, `0` si el maestro la da por desconectada |
| `rep` | Respuestas válidas acumuladas |
| `to` | Polls sin respuesta (timeouts) |
| `crc` | Tramas suyas descartadas por CRC incorrecto → bus con ruido |
| `cmd` | Pulsaciones reales reenviadas a la app |
| `rtt` | Ida y vuelta de la última respuesta. A 9600 baudios una trama de 7 bytes tarda 7,3 ms, así que ida + 1,5 ms de espera del esclavo + vuelta dan **~16 ms de mínimo físico**. Normal: 16-25 ms |
| `age` | ms desde la última respuesta válida; **`-1` = nunca ha respondido** |

`age=-1` distingue "esta caja nunca arrancó" de "funcionaba y se ha caído",
que llevan a revisar cosas distintas.

### `[MS]` — una línea del maestro

```
[MS] fw=3 up=125340 cyc=34 on=4/4 polls=2010 rxb=9001 frm=1200 crc=0 wid=0 rs485=9600 usb=115200
```

| Campo | Significado |
|---|---|
| `fw` | Versión del firmware. La app exige ≥ 2 para el diagnóstico por caja; la 3 trae IDs de fábrica, descubrimiento y `KEEP` |
| `up` | ms desde que arrancó el maestro (si se resetea solo, aquí se ve) |
| `cyc` | Vuelta de poleo más lenta desde el informe anterior. **~80 ms con las 4 cajas vivas** (4 × 16 ms + pausas), más el descubrimiento de 30 ms una de cada 4 vueltas. Una caja ausente cuesta su timeout de 70 ms y lo sube a ~140 ms |
| `on` | Cajas conectadas / cajas que conoce el maestro. `0/0` = todavía no ha aprendido ninguna |
| `wid` | Tramas con ID inesperado. En la práctica **siempre 0**: un valor distinto indica corrupción seria del bus |

Como `[MS]` llega cada 2 s, sirve además de latido: si la app deja de recibirlo
durante más de 6 s, da el maestro por colgado.

### `[EVT]` — cambios de estado

```
[EVT] dev=0203 offline
[EVT] dev=0203 online
[EVT] dev=1A2B new
```

Se emiten en el instante del cambio, sin esperar al envío periódico. `new` es
una caja recién aprendida por descubrimiento.

### Comandos que acepta el maestro

| Enviado por la app | Respuesta |
|---|---|
| `STATUS` | Un bloque `[PS]`×N + `[MS]` inmediato |
| `PING` | `PONG` |
| `KEEP <id> <id>…` | Se queda solo con esas cajas (IDs en hex, separados por espacio; `KEEP` solo las olvida todas), lo guarda en flash y responde `[INFO] KEEP: …` y un informe `STATUS`. Un maestro con firmware anterior lo ignora |

---

## Capa 3 — App (comando → evento de marcador)

1. `SimpleUsbSerialListener` lee líneas del USB y valida el formato.
2. `HardwareCommandHandler` recibe el comando.
3. Para `BTN:`, `BoxPairingService` traduce el ID de caja a un **lado** de la
   pista (1 = izquierda de la pantalla, 2 = derecha). Las cajas están fijas y
   los jugadores cambian de lado al cerrar cada set, así que el equipo sale del
   lado y de `isSwapped`. **No hay emparejamiento por defecto**: sin cajas
   emparejadas la app abre el asistente ("pulsa una caja del lado izquierdo…")
   y, al terminarlo, envía `KEEP` al maestro. Se guarda en `SharedPreferences`
   (clave `box_team_pairings`, valores 1/2 heredados del emparejado por equipo)
   y se edita en **Ajustes ▸ Mandos**.
4. Se emite el `ScoringEvent` correspondiente.

`G` (reiniciar) no reinicia directamente: abre un overlay de confirmación a
pantalla completa. El árbitro confirma con un comando `P` o cancela con `U`/`G`.

---

## Checklist para cambiar el protocolo

Un cambio de protocolo **nunca** afecta a una sola capa. Antes de dar por bueno
un cambio, recorre las tres:

- [ ] `firmware/esclavo/esclavo.ino` — construcción/parseo de trama, `cmd`
- [ ] `firmware/maestro/maestro.ino` — parseo RS-485, formato de salida USB
      **y** `emitStatus()` si cambian los campos de telemetría
- [ ] `app/lib/features/usb_serial/hardware_health.dart` — parser de `[PS]`/`[MS]`
- [ ] `app/lib/features/usb_serial/simple_usb_serial_listener.dart` — regex de validación
- [ ] `app/lib/features/match_control/hardware_command_handler.dart` — mapeo a eventos
- [ ] `app/lib/config/box_pairing_service.dart` — emparejado por lado y `KEEP`
- [ ] `app/test/hardware_pairing_test.dart` y `app/test/firmware_contract_test.dart`
      (este lee el `.ino` del maestro: si cambia un `printf`, se rompe aquí)
- [ ] **Este documento**
- [ ] Reflashear **las 4 cajas** y el maestro (ver [firmware/esclavo/README.md](../../firmware/esclavo/README.md))

## Cómo saber en qué salto falla

Los tres fallos se parecen desde fuera ("no llega nada a la app"). Para
distinguirlos, ver [docs/hardware/USB_TROUBLESHOOTING.md](../hardware/USB_TROUBLESHOOTING.md)
y el panel de diagnóstico USB en pantalla (Ajustes ▸ mostrar botón debug), que
indica la etapa: sin dispositivo / detectado / conectado sin datos / recibiendo
pero mal formateado / operativo.
