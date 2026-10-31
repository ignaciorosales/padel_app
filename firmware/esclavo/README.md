# Esclavo — caja de botones

**El mismo `.ino` para todas las cajas, sin editar nada.** Cada caja toma su ID
de los 2 últimos bytes de su MAC de fábrica, que es única por chip, y el
maestro la aprende la primera vez que alguien la pulsa (ver "Descubrimiento"
en [docs/protocol/README.md](../../docs/protocol/README.md)).

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

## Procedimiento de flasheo

1. Instala la librería **Adafruit_VL6180X** en el Arduino IDE (Gestor de
   librerías). Sin ella no compila.
2. Placa ESP32-C3, sube `esclavo.ino` a cada caja tal cual.
3. Opcional: en el Monitor Serie (115200) la caja dice su ID al arrancar,
   `SLAVE RS-485 start, DEV_ID=0x1A2B (de la MAC)`. Apuntarlo en una pegatina
   ayuda a reconocerla en la pantalla de Diagnóstico.

Después, en la pista, el asistente de la TV ("pulsa una caja del lado
izquierdo…") hace que el maestro la aprenda y que la app sepa de qué lado
está. No hay que tocar el maestro.

## Reinicio automático

- **Watchdog** (5 s): si el loop se cuelga (bus I²C del ToF bloqueado, UART),
  la caja se reinicia sola.
- **Sin noticias del maestro en 10 s**, la caja se reinicia. Con el maestro
  funcionando no pasa nunca: pregunta varias veces por segundo.
