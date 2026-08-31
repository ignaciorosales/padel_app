# Puntazo

Puntazo tiene dos mitades que hoy no se hablan entre sí, y es a propósito:

- **La pista** — un Android TV muestra el marcador y cuatro cajas de botones lo
  controlan. Funciona sin red y así se queda.
- **El club** — un panel web para montar torneos y llevar la gestión del local.
  Necesita conexión, pero la de recepción; nunca la de la pista.

```
padel_app/
├── app/                    Aplicación Flutter (Android TV) — el marcador
├── firmware/
│   ├── maestro/            1 unidad — RS-485 ▸ USB, junto al TV
│   ├── esclavo/            4 unidades — cajas de botones en pista
│   └── legacy/             generaciones anteriores, no se compila
├── web/                    Panel del club (Next.js) — torneos y administración
│   └── src/
│       ├── app/            rutas: /login, /admin (Puntazo), /panel (el club)
│       ├── components/     piezas de interfaz
│       └── lib/            autorización, cliente de Supabase, generador de rondas
├── backend/
│   └── migrations/         esquema y políticas RLS de Supabase
├── docs/
│   ├── protocol/           ⭐ contrato entre las 3 capas de la pista
│   ├── producto/           ⭐ plan de producto: qué se construye y por qué
│   ├── hardware/           montaje RS-485, diagnóstico USB, pruebas
│   ├── app/                temas, colores, selección de equipos
│   ├── deployment/         Android TV, publicación en Google Play
│   ├── archive/            documentación de la era BLE (obsoleta)
│   └── lanes.md            ⭐ trabajar en dos lanes en paralelo
└── tools/                  utilidades de desarrollo (lane.sh: estado de las lanes)
```

Las dos mitades se cruzarán más adelante (fase 3-4 del plan de producto), y
cuando lo hagan será sin conectar la tele a internet. Hasta entonces se pueden
desarrollar por separado: **el panel no depende del firmware ni de la app**.

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
| Levantar el panel web | [web/README.md](web/README.md) |
| Saber a dónde va el producto | [docs/producto/README.md](docs/producto/README.md) |
| Trabajar en dos lanes a la vez | [docs/lanes.md](docs/lanes.md) |

## Por qué un solo repositorio

Las tres capas de la pista comparten un protocolo. Cuando estaban en repos
separados (y el esclavo en ninguno), un cambio de formato de trama se aplicaba a
una capa y se olvidaba en otra, y el fallo resultante era indistinguible de un
problema de cableado. Aquí un mismo commit puede tocar las tres y el checklist
del documento de protocolo obliga a repasarlas.

`web/` entra por el mismo motivo, aunque hoy no comparta código con nadie:
cuando la pista y el club se junten (fase 3-4 del plan de producto) lo harán a
través de un formato de datos —el QR con el partido dentro— que tendrán que
entender a la vez el marcador en Dart y la web en TypeScript. Ese es exactamente
el tipo de contrato que se desincroniza cuando vive en dos repositorios.
