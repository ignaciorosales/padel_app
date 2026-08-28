# Esclavo — caja de botones

**Un único `.ino` para las 4 cajas.** Lo que distingue a cada unidad es una sola
línea, `#define DEV_ID`, que hay que editar a mano antes de flashear cada caja.
Este es el paso más frágil de todo el sistema — lee
[Procedimiento de flasheo](#procedimiento-de-flasheo) antes de tocarlo.

## Pines (ESP32-C3)

| Señal | GPIO |
|---|---|
| Botón P (punto) | 5 |
| Botón U (deshacer) | 6 |
| Botón G (reiniciar) | 7 |
| RS-485 TX → DI | 4 |
| RS-485 RX ← RO | 10 |
| RS-485 EN → DE + ~RE | 1 |
| I²C SDA (VL6180X) | 2 |
| I²C SCL (VL6180X) | 3 |

Botones a GND con `INPUT_PULLUP` (`BTN_ACTIVE_LOW 1`). Rebote: 80 ms.

## Sensor ToF (VL6180X)

Opcional: si no se detecta en el arranque, la caja funciona solo con botones
(`VL6180X no encontrado (solo botones).`).

El sensor no puede distinguir por distancia si lo que tiene encima es una paleta
o la tapa, así que clasifica por **patrón temporal**:

- toque corto y retirada → paleta, suma el punto **al soltar**
- objeto que se queda puesto → tapa, bloquea puntos hasta retirarla

Umbrales en la sección `=== Tuning ToF ===` del sketch. Tras pulsar un botón
físico, el ToF queda inhibido 1200 ms para no contar doble.

## Registro de cajas

| `DEV_ID` | Caja | Posición de montaje | Última vez flasheada |
|---|---|---|---|
| `0x0201` | A1 | Equipo A, jugador 1 | — |
| `0x0202` | A2 | Equipo A, jugador 2 | — |
| `0x0203` | B1 | Equipo B, jugador 1 | — |
| `0x0204` | B2 | Equipo B, jugador 2 | — |

> Rellena la última columna al flashear. Sin esto no hay forma de saber qué
> firmware lleva cada caja física una vez cerradas.

## Procedimiento de flasheo

Para **cada** una de las 4 cajas:

1. Edita `#define DEV_ID 0x02XX` con el ID de esa caja (tabla de arriba).
2. Actualiza **también el comentario de la cabecera** del fichero para que
   coincida.
3. Compila y sube.
4. Etiqueta físicamente la caja con su ID.
5. Anota la fecha en la tabla de registro.
6. Revierte `DEV_ID` a su valor por defecto antes de commitear, o commitea a
   propósito el que dejes — pero no dejes el repo en un estado ambiguo.

Verificación: con las 4 cajas encendidas, el maestro debe reportar las 4 online
en su log `[RS485 DBG]`. **Dos cajas con el mismo `DEV_ID` colisionan en el bus
y el fallo es intermitente** — parece un problema de cableado, no de firmware.

## ⚠ Incoherencia conocida en el fichero actual

La cabecera dice `SLAVE 0x0201` pero el código tiene `#define DEV_ID 0x0204`:

```c
// PadelSlave_RS485_9600_min_debug - SLAVE 0x0201   ← comentario
#define DEV_ID  0x0204                              ← valor real
```

Manda el `#define`. El comentario quedó desactualizado en algún flasheo
anterior. No se ha corregido al importar el fichero para conservarlo idéntico a
la copia que está en las cajas; corrígelo en el próximo cambio real.

## Idea para eliminar este riesgo

Extraer `DEV_ID` a un `BoxConfig.h` por caja, o pasarlo como flag de compilación,
para que el `.ino` no se edite nunca. No está hecho: requiere cambiar el sketch,
no solo moverlo.
