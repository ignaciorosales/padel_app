# Puntazo

Este repositorio se trabaja en **dos lanes en paralelo** (`padel_app-a` /
`lane/a` y `padel_app-b` / `lane/b`), más `padel_app` / `develop` como carpeta
de integración. Cualquier lane puede coger cualquier tarea; no tienen tema
asignado.

Puede haber otra sesión editando este mismo repositorio ahora mismo.

## Al empezar cualquier tarea

```sh
sh tools/lane.sh
```

Dice qué ficheros ha tocado ya la otra lane y avisa si vais a chocar. **Si sale
CHOQUE, no sigas escribiendo** — resuélvelo primero (docs/lanes.md ▸ "Cuando
algo se rompe").

## Reglas que rompen cosas si se saltan

1. **`docs/protocol/README.md` no se toca desde una lane.** Es el contrato de
   las tres capas de la pista; cambiarlo obliga a tocar app, maestro y esclavo
   a la vez. Se hace en `develop`, con las dos lanes integradas. Léelo antes de
   tocar `app/lib/` o `firmware/`.
2. **Los números de migración se reservan en `develop` antes de escribir el
   `.sql`.** Dos lanes creando `0004_…` no dan conflicto en git, y la base de
   datos de Supabase es **la misma para las dos**.
3. **`app/pubspec.yaml` línea `version:` sólo se sube en `develop`.**
4. **No se desarrolla en `padel_app/` (develop).** Es sólo integración.
5. **Recursos únicos** (puerto COM del ESP32, Android TV por `adb`, puerto 3000
   de `next dev`): una lane a la vez. La lane B usa `npm run dev -- -p 3001`.

## Al terminar

Fusiona `develop` hacia tu lane y resuelve los conflictos **ahí**, pasa los
tests (`flutter test` en `app/`, `npm test && npm run lint` en `web/`), y sólo
entonces fusiona tu lane en `develop`. Integra pronto: una lane con muchos
commits sin integrar es una fusión dolorosa garantizada.

Procedimientos completos y recuperación: **[docs/lanes.md](docs/lanes.md)**.
