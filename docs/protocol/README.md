# Protocolo Puntazo — contrato entre las 3 capas

Este documento es la **única fuente de verdad** del protocolo. Si cambias algo
aquí, tienes que tocar las tres capas a la vez (ver [Checklist](#checklist-para-cambiar-el-protocolo)).

## Cadena completa

```
┌─────────────┐   RS-485      ┌─────────────┐   USB serial   ┌──────────────┐
│  4 esclavos │  9600 8N1     │   maestro   │  115200 8N1    │  app Flutter │
│  ESP32-C3   │ ────────────► │  ESP32-C3   │ ─────────────► │  Android TV  │
│ 0x0201..04  │   (polling)   │             │  texto plano   │              │
└─────────────┘               └─────────────┘                └──────────────┘
  botones P/U/G                 poll round-robin               BoxPairingService
  + ToF VL6180X                 CRC16-CCITT                    decide el equipo
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
  │      │      │      └───────────────────── 0x01 = poll
  │      └──────┴──────────────────────────── ID del esclavo, little-endian
  └─────────────────────────────────────────── inicio de trama
```

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

### IDs de los esclavos

| ID | Caja | Posición física |
|---|---|---|
| `0x0201` | A1 | Equipo A, jugador 1 |
| `0x0202` | A2 | Equipo A, jugador 2 |
| `0x0203` | B1 | Equipo B, jugador 1 |
| `0x0204` | B2 | Equipo B, jugador 2 |

> El maestro **no** interpreta estos IDs como equipos: solo los reenvía.
> El reparto A/B lo decide la app (Ajustes ▸ Mandos). Los nombres de la tabla
> son la convención de montaje, no una regla del firmware.

### Temporización

| Parámetro | Valor | Dónde |
|---|---|---|
| `RS485_POST_TX_US` | 200 µs | ambos |
| `RS485_SLAVE_REPLY_DELAY_US` | 1500 µs | esclavo |
| `COMMAND_DEBOUNCE_MS` | 200 ms | maestro (anti-duplicado por esclavo) |
| `DEBOUNCE_MS` | 80 ms | esclavo (rebote de botón) |

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
| `rtt` | Ida y vuelta de la última respuesta, en ms (~18 ms es lo normal a 9600 baudios) |
| `age` | ms desde la última respuesta válida; **`-1` = nunca ha respondido** |

`age=-1` distingue "esta caja nunca arrancó" de "funcionaba y se ha caído",
que llevan a revisar cosas distintas.

### `[MS]` — una línea del maestro

```
[MS] fw=2 up=125340 cyc=34 on=4/4 polls=2010 rxb=9001 frm=1200 crc=0 wid=0 rs485=9600 usb=115200
```

| Campo | Significado |
|---|---|
| `fw` | Versión del firmware. La app exige ≥ 2 para el diagnóstico por caja |
| `up` | ms desde que arrancó el maestro (si se resetea solo, aquí se ve) |
| `cyc` | Duración de la última vuelta de poleo. ~30 ms con las 4 cajas vivas |
| `on` | Cajas conectadas / configuradas |
| `wid` | Tramas con ID inesperado → casi siempre **dos cajas con el mismo `DEV_ID`** |

Como `[MS]` llega cada 2 s, sirve además de latido: si la app deja de recibirlo
durante más de 6 s, da el maestro por colgado.

### `[EVT]` — cambios de estado

```
[EVT] dev=0203 offline
[EVT] dev=0203 online
```

Se emiten en el instante del cambio, sin esperar al envío periódico.

### Comandos que acepta el maestro

| Enviado por la app | Respuesta |
|---|---|
| `STATUS` | Un bloque `[PS]`×N + `[MS]` inmediato |
| `PING` | `PONG` |

---

## Capa 3 — App (comando → evento de marcador)

1. `SimpleUsbSerialListener` lee líneas del USB y valida el formato.
2. `HardwareCommandHandler` recibe el comando.
3. Para `BTN:`, `BoxPairingService` traduce el ID de caja a equipo.
   Por defecto: `0201`/`0202` → Equipo 1 (azul), `0203`/`0204` → Equipo 2 (rojo).
   El emparejado se guarda en `SharedPreferences` y se edita en **Ajustes ▸ Mandos**.
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
- [ ] `app/lib/config/box_pairing_service.dart` — si cambian los IDs de caja
- [ ] `app/test/hardware_pairing_test.dart` — tests
- [ ] **Este documento**
- [ ] Reflashear **las 4 cajas** y el maestro (ver [firmware/esclavo/README.md](../../firmware/esclavo/README.md))

## Cómo saber en qué salto falla

Los tres fallos se parecen desde fuera ("no llega nada a la app"). Para
distinguirlos, ver [docs/hardware/USB_TROUBLESHOOTING.md](../hardware/USB_TROUBLESHOOTING.md)
y el panel de diagnóstico USB en pantalla (Ajustes ▸ mostrar botón debug), que
indica la etapa: sin dispositivo / detectado / conectado sin datos / recibiendo
pero mal formateado / operativo.
