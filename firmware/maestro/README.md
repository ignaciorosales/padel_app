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
necesita librerías externas ni ningún ajuste especial del menú Herramientas.
Compila también para ESP32-WROOM (`esp32:esp32:esp32`), que usa la otra rama
de pines.

## Por qué la salida va por dos caminos a la vez

En ESP32-C3, **`Serial` no es siempre el USB**. Lo decide una opción del IDE:

```c
// core de ESP32, HardwareSerial.h
#if ARDUINO_USB_CDC_ON_BOOT
  #define Serial HWCDCSerial   // el USB nativo
#else
  #define Serial Serial0       // UART0, GPIO 20/21
#endif
```

Y el valor **por defecto** de la placa es `Disabled` (`build.cdc_on_boot=0`).
Un maestro flasheado sin tocar ese menú y conectado al televisor por su USB
nativo escribe a unos pines que no van a ninguna parte: la app ve el puerto
abierto y no recibe un solo byte. Desde fuera es idéntico a un cable roto, y
cuesta horas de diagnóstico.

Para que deje de importar, `TabletLink` escribe **siempre en los dos**:

| Camino | Llega al televisor cuando… |
|---|---|
| UART0 (GPIO 20/21) | la placa tiene puente CH340/CP210x cableado a UART0 |
| USB nativo (USB Serial/JTAG) | se usa el conector USB del propio chip |

Escribir en un puerto sin nadie escuchando **no bloquea**: `HWCDC::write()`
comprueba `isCDC_Connected()` y, si no hay host, descarta los bytes y vuelve
(ver `HWCDC.cpp` en el core). La entrada se atiende del camino que tenga datos.

El core solo declara la instancia global `HWCDCSerial` cuando se compila con
`CDC On Boot = Enabled`; con la opción desactivada el sketch crea la suya, que
es válido porque los buffers de `HWCDC` son estáticos de fichero y en esa rama
la del core no existe.

Verificado compilando las tres combinaciones: C3 por defecto, C3 con CDC On
Boot activado, y WROOM.

## Cuando falta una caja

El maestro deja de polear en cada vuelta a las cajas que da por desconectadas y
las reintenta 1 de cada 8 ciclos. Sin esto, cada caja ausente costaba su timeout
completo (70 ms) en todas las vueltas y los botones de las cajas **buenas**
respondían con retraso. La recuperación sigue siendo rápida (~0,3 s).

### Tiempos de referencia

A 9600 baudios una trama de 7 bytes tarda 7,3 ms en transmitirse, así que el
mínimo físico por caja es ida (7,3) + espera del esclavo (1,5) + vuelta (7,3)
**≈ 16 ms**. De ahí salen las cifras que verás en el diagnóstico:

| Situación | `rtt` por caja | `cyc` (vuelta completa) |
|---|---|---|
| Las 4 cajas responden | 16-25 ms | ~80 ms |
| Una caja ausente | — | ~140 ms en el ciclo de reintento |

`cyc` informa del **máximo** desde el informe anterior, no de la última vuelta:
con el backoff los ciclos alternan entre cortos y largos, y publicar el último
haría parpadear el aviso de ciclo lento.
