# Firmware

Dos sketches Arduino, uno por tipo de placa. Ambas carpetas cumplen la regla de
Arduino IDE (**la carpeta se llama igual que el `.ino`**), así que se abren con
doble clic sin que el IDE pida moverlas.

| Carpeta | Placa | Unidades | Qué hace |
|---|---|---|---|
| [maestro/](maestro/) | ESP32-C3 (o WROOM) | 1 | Polea las 4 cajas por RS-485 y reenvía por USB al Android TV |
| [esclavo/](esclavo/) | ESP32-C3 | 4 | Lee 3 botones + sensor ToF y responde al poll del maestro |
| [legacy/](legacy/) | — | — | Restos de generaciones anteriores. **No se compila.** |

El protocolo que hablan entre sí está en
[docs/protocol/README.md](../docs/protocol/README.md). Es el documento a leer
antes de tocar cualquiera de los dos sketches.

## Entorno

- Arduino IDE con **esp32 by Espressif Systems** (Boards Manager)
- Placa: **ESP32C3 Dev Module** para ambos sketches
- Librerías: `Adafruit_VL6180X` (solo el esclavo)

## Aviso importante

Los dos sketches forman **un único sistema con un único protocolo**. Actualizar
solo el maestro, o solo 3 de las 4 cajas, deja el sistema en un estado que falla
de forma intermitente y difícil de diagnosticar. Cuando cambies el protocolo,
reflashea las 5 placas.
