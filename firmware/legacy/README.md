# Legacy — no compilar

Restos de generaciones anteriores del proyecto. Están aquí para poder
consultarlos, **fuera** de las carpetas de sketch activas, porque Arduino IDE
compila todo `.cpp`/`.h` que encuentre junto a un `.ino`.

## `PadelScoreboard_Serial/`

Ficheros de apoyo de un sketch **autónomo** distinto: un marcador de pádel
completo que corría en el propio ESP32 y se manejaba escribiendo letras en el
Monitor Serie (`a`, `b`, `u`, `g`, `m`, `s`, `h`). Nada que ver con la cadena
esclavo → maestro → app.

- `Config.h` — nombres de equipo y reglas del marcador autónomo
- `PadelRules.h` / `PadelRules.cpp` — lógica de puntuación en C++
- `README.txt` — instrucciones de ese sketch

El `.ino` correspondiente **no está** en el árbol de trabajo: era la versión
*BLE advertising* del maestro y se borró. Sigue en el historial importado:

```bash
git show 2631d6d:PadelScoreboard_Serial/PadelScoreboard_Serial.ino
```

Que ese sketch BLE y el maestro RS-485 convivieran en la misma carpeta fue la
causa de una confusión real durante una prueba de campo. Por eso está separado.
