# Puntazo

Marcador de pádel para pistas: un Android TV muestra el marcador y cuatro cajas
de botones en la pista lo controlan.

Este repositorio contiene **las tres partes del sistema**.

```
padel_app/
├── app/                    Aplicación Flutter (Android TV)
├── firmware/
│   ├── maestro/            1 unidad — RS-485 ▸ USB, junto al TV
│   ├── esclavo/            4 unidades — cajas de botones en pista
│   └── legacy/             generaciones anteriores, no se compila
├── docs/
│   ├── protocol/           ⭐ contrato entre las 3 capas
│   ├── hardware/           montaje RS-485, diagnóstico USB, pruebas
│   ├── app/                temas, colores, selección de equipos
│   ├── deployment/         Android TV, publicación en Google Play
│   └── archive/            documentación de la era BLE (obsoleta)
└── tools/                  utilidades de desarrollo
```

## Cómo funciona

```
4 cajas ESP32-C3  ──RS-485 9600──►  maestro ESP32-C3  ──USB 115200──►  app Flutter
   botones + ToF                      polling + CRC16                  Android TV
```

Cada caja tiene 3 botones (punto / deshacer / reiniciar) y un sensor de
proximidad opcional. El maestro las consulta por turnos y reenvía lo que pasa al
tablet como texto plano. **El maestro no decide de qué equipo es cada caja** —
eso se configura en la app (Ajustes ▸ Mandos).

El formato exacto de las tramas está en
**[docs/protocol/README.md](docs/protocol/README.md)**. Es el documento a leer
antes de tocar cualquier capa: un cambio de protocolo siempre afecta a las tres.

## Empezar

| Quiero… | Ir a |
|---|---|
| Compilar la app | [app/README.md](app/README.md) |
| Flashear el maestro | [firmware/maestro/README.md](firmware/maestro/README.md) |
| Flashear una caja | [firmware/esclavo/README.md](firmware/esclavo/README.md) |
| Entender el protocolo | [docs/protocol/README.md](docs/protocol/README.md) |
| Montar el bus RS-485 | [docs/hardware/HARDWARE_SETUP_RS485.md](docs/hardware/HARDWARE_SETUP_RS485.md) |
| Depurar "no llega nada" | [docs/hardware/USB_TROUBLESHOOTING.md](docs/hardware/USB_TROUBLESHOOTING.md) |
| Configurar el Android TV | [docs/deployment/ANDROID_TV_SETUP.md](docs/deployment/ANDROID_TV_SETUP.md) |

## Por qué un solo repositorio

Las tres partes comparten un protocolo. Cuando estaban en repos separados (y el
esclavo en ninguno), un cambio de formato de trama se aplicaba a una capa y se
olvidaba en otra, y el fallo resultante era indistinguible de un problema de
cableado. Aquí un mismo commit puede tocar las tres capas y el checklist del
documento de protocolo obliga a repasarlas.
