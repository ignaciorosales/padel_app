Marcador de Pádel (Serial-only) para ESP32-C3
============================================

No necesitas nada más que el ESP32-C3 por USB.
El marcador se maneja desde el Monitor Serie del Arduino IDE.

Pasos:
1) Boards Manager: instala "esp32 by Espressif Systems".
2) Placa: selecciona "ESP32C3 Dev Module" (o tu variante).
3) Abre PadelScoreboard_Serial.ino
4) Compila y Subí.
5) Abre el Monitor Serie a 115200 baudios. (Fin de línea: "Sin fin de línea" o "Nueva línea" funciona)

Comandos (escribe la letra y Enter):
  a -> Punto para Equipo A
  b -> Punto para Equipo B
  u -> UNDO (deshacer última acción)
  g -> Reset del JUEGO actual
  m -> Reset de TODO el PARTIDO
  s -> Mostrar marcador
  h -> Ayuda

Notas:
- Los nombres de equipos se cambian en Config.h
- Reglas: puntuación estilo tenis (0-15-30-40, Deuce/Ad), set a 6 con diferencia de 2, tie-break a 7 con diferencia de 2, partido al mejor de 3.
