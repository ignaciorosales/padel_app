# Maestro — RS-485 ▸ USB

Una sola unidad, junto al Android TV. Polea las 4 cajas por RS-485 en
round-robin y reenvía cada pulsación al tablet por USB serial en texto plano.

**El maestro no decide el equipo.** Solo reenvía el ID de la caja y la letra del
comando; el reparto A/B lo hace la app en Ajustes ▸ Mandos. Fue un cambio
deliberado de protocolo — antes sí lo decidía el firmware.

## Pines

El sketch detecta el tipo de ESP32 en tiempo de compilación:

| Señal | ESP32-C3 / S2 / S3 (UART1) | ESP32-WROOM (UART2) |
|---|---|---|
| TX → DI | GPIO4 | GPIO17 |
| RX ← RO | GPIO10 | GPIO16 |
| EN → DE + ~RE | GPIO1 | *(no definido)* |

> En WROOM no se define `RS485_EN_PIN`, así que el control de dirección del
> transceptor queda desactivado por `#ifdef`. Si usas WROOM con un MAX3485 que
> necesite DE/~RE, hay que añadir el pin.

## Velocidades

- RS-485: **9600** 8N1
- USB al tablet: **115200** 8N1

## Salida

```
BTN:0201:P      comando (P=punto, U=deshacer, G=reiniciar)
[PS] dev=...    estado de UNA caja, cada 2 s
[MS] fw=2 ...   estado del maestro, cada 2 s (sirve de latido)
[EVT] dev=...   una caja acaba de conectarse o caerse
[INFO] ...      arranque, configuración de pines
[RS485 DBG] ... contadores globales de trama
```

Las líneas `[PS]`/`[MS]` son las que consume la pantalla de **Diagnóstico** de
la app: dicen qué caja concreta falla, con qué tasa de error y desde cuándo. El
formato exacto de cada campo está en
[docs/protocol/README.md](../../docs/protocol/README.md#telemetría-del-maestro-firmware-v2).

Si la app envía `STATUS` por el puerto, el maestro contesta con un informe
completo al momento en vez de esperar al envío periódico.

## Compilar

Abre `maestro.ino` con Arduino IDE, placa **ESP32C3 Dev Module**, y sube. No
necesita librerías externas. Compila también para ESP32-WROOM
(`esp32:esp32:esp32`), que usa la otra rama de pines.

## Cuando falta una caja

El maestro deja de polear en cada vuelta a las cajas que da por desconectadas y
las reintenta 1 de cada 8 ciclos. Sin esto, cada caja ausente costaba su timeout
completo (70 ms) en todas las vueltas y los botones de las cajas **buenas**
respondían con retraso. La recuperación sigue siendo rápida (~0,3 s).
