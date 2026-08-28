# Puntazo — app Flutter

Aplicación de marcador para Android TV. Recibe los comandos de las cajas de
botones por USB serial desde el maestro ESP32.

## Requisitos

- Flutter (canal stable)
- Android SDK — el objetivo es un box Android TV, no un móvil

## Comandos

```bash
cd app
flutter pub get
flutter run
flutter test
flutter build apk --release
```

> Todos los comandos de Flutter se ejecutan **desde `app/`**, no desde la raíz
> del repositorio. Aquí es donde está `pubspec.yaml`.

Si el proyecto tiene código generado (freezed / json_serializable):

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Estructura

```
lib/
├── config/                 configuración, temas, servicios persistentes
│   └── box_pairing_service.dart   empareja caja física ▸ equipo
├── features/
│   ├── usb_serial/         lectura del puerto USB y diagnóstico en pantalla
│   ├── match_control/      comandos de hardware ▸ eventos de marcador
│   ├── scoring/            BLoC de puntuación
│   ├── models/             modelos de dominio
│   └── widgets/            marcador, ajustes, overlays
├── l10n/                   traducciones
└── main.dart
```

## Puntos de entrada del hardware

| Fichero | Papel |
|---|---|
| `lib/features/usb_serial/simple_usb_serial_listener.dart` | lee y valida las líneas USB |
| `lib/features/match_control/hardware_command_handler.dart` | traduce comandos a eventos |
| `lib/config/box_pairing_service.dart` | decide el equipo de cada caja |

El formato de esas líneas lo define
[docs/protocol/README.md](../docs/protocol/README.md).

## Diagnóstico en pista

Ajustes ▸ *mostrar botón debug* activa dos cosas en pantalla: el panel de
diagnóstico USB (arriba izquierda), que dice en qué etapa está la comunicación,
y el overlay de pruebas (abajo izquierda), que simula la botonera física usando
la **misma** capa de lógica que el hardware real.
