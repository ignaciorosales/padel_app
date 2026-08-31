# Trabajar en dos lanes

Dos carpetas, un solo repositorio. Cada lane es un
[worktree de git](https://git-scm.com/docs/git-worktree): su propia copia de los
ficheros, su propia rama, el mismo `.git` compartido.

```
C:/Users/Sergio/
├── padel_app/      develop   ← integración; aquí no se desarrolla
├── padel_app-a/    lane/a
└── padel_app-b/    lane/b
```

**Las lanes no tienen dueño temático.** Cualquiera de las dos puede coger
cualquier tarea — pista, club, docs, lo que sea. Lo que separa el trabajo no es
el tema, es que dos sesiones no editen el mismo fichero a la vez.

---

## Antes de tocar nada

```sh
sh tools/lane.sh
```

Dice qué ficheros ha tocado ya la otra lane y avisa si vais a chocar. Lee las
ramas del `.git` compartido: no hace falta ni red ni que la otra lane haya
hecho push. **Ejecútalo al empezar una tarea y antes de integrar.** Es la única
disciplina que no se puede saltar; el resto de este documento explica por qué.

---

## Los ficheros que hacen daño

Un conflicto de git en un fichero normal se ve y se arregla. Estos cinco no
avisan igual de bien:

| Fichero | Por qué duele | Regla |
|---|---|---|
| `docs/protocol/README.md` | Es el contrato de las tres capas de la pista. Cambiarlo obliga a tocar app, maestro y esclavo a la vez. Si cada lane lo cambia a su manera, el fallo resultante parece un problema de cableado. | **Nunca en una lane.** Un cambio de protocolo se hace en `develop`, con las dos lanes integradas y paradas. |
| `backend/migrations/NNNN_*.sql` | Numeración secuencial: las dos lanes escriben `0004_…` y git no ve conflicto porque son ficheros distintos. Además **la base de datos de Supabase es la misma para las dos** — una migración aplicada desde una lane cambia el mundo bajo los pies de la otra. | Reserva el número en `develop` **antes** de escribir el fichero (ver abajo). Avisa antes de aplicar nada a la BD. |
| `app/pubspec.yaml` (línea `version:`) | Dos lanes suben `1.0.4+8` a `+9` y sale un conflicto tonto; peor, si las dos publican sale un build number duplicado que Play rechaza. | La versión **sólo se sube en `develop`**, en el commit de release. |
| `web/package.json` + `package-lock.json` | Dos `npm install` de dependencias distintas producen un lock que no se puede fusionar a mano. | Añade la dependencia, comprueba que arranca, e **integra en `develop` ese mismo día**. No acumules cambios de dependencias. |
| `README.md` (raíz) | Ambas lanes tienden a actualizar el mismo árbol de directorios. | Edita sólo la parte de lo tuyo. Si tocas la estructura, integra ya. |

### Reservar un número de migración

```sh
# desde padel_app/ (develop)
git commit --allow-empty -m "reserva 0004 para <lo que sea>"   # o crea el .sql vacío
```

Luego en tu lane: `git merge develop` y ya tienes el número. Cuesta treinta
segundos y evita el peor conflicto posible en este repo, que es el que no da
conflicto.

Si esto se vuelve pesado, la alternativa es pasar a nombres con marca de tiempo
(`20260901143000_torneos.sql`, que es lo que usa el CLI de Supabase). No lo
hagas con migraciones ya aplicadas.

---

## Los recursos que sólo hay uno

No son ficheros, y por eso no los ve git. Las dos lanes comparten:

| Recurso | Qué pasa si las dos lo usan | Cómo convivir |
|---|---|---|
| **El proyecto de Supabase** (`web/.env.local` apunta al mismo) | Una lane aplica una migración o borra datos y la otra ve la BD cambiada de golpe. | Avisar antes de aplicar migraciones. Si hace falta aislamiento de verdad, un segundo proyecto de Supabase para la lane B y su propio `.env.local`. |
| **Puerto 3000** (`npm run dev`) | La segunda lane peta con `EADDRINUSE`. | Lane A: `npm run dev`. Lane B: `npm run dev -- -p 3001`. No lo metas en `package.json`, es un diff permanente. |
| **El puerto COM del ESP32** | Flashear desde dos sitios a la vez corrompe el flasheo. | Una lane a la vez, y cerrar el monitor serie antes. |
| **El Android TV por `adb`** | `adb install` desde dos lanes deja la app en un estado indeterminado. | Una lane a la vez. `adb devices` antes de nada. |

---

## Ciclo de trabajo

```sh
cd /c/Users/Sergio/padel_app-a
sh tools/lane.sh                 # ¿choco con la otra lane?
git merge develop                # parte de lo último integrado
# …trabajar, commitear…
```

Integrar cuando la tarea funcione:

```sh
sh tools/lane.sh                 # último control
git merge develop                # y resolver conflictos AQUÍ, no en develop
# pasar lo que aplique:
cd app && flutter test
cd web && npm test && npm run lint

cd /c/Users/Sergio/padel_app     # develop
git merge lane/a
```

Dos costumbres que ahorran casi todos los problemas:

1. **Integra pronto y a menudo.** Una lane con quince commits sin integrar es
   una fusión dolorosa garantizada. Dos días es mucho.
2. **Resuelve los conflictos en tu lane**, fusionando `develop` hacia ti. Así
   `develop` nunca se queda a medias, y si la lías sólo la lías en tu carril.

Nunca desarrolles en `padel_app/` (develop). Es la carpeta de integración: si
tiene cambios sin commitear, `git merge` falla y te quedas atascado con las dos
lanes esperando.

---

## Cuando algo se rompe

### `tools/lane.sh` dice CHOQUE

Las dos lanes han tocado el mismo fichero. No sigas escribiendo.

```sh
# 1. La lane que esté más cerca de terminar integra primero:
git merge lane/a

# 2. La otra se pone al día ANTES de tocar más ese fichero:
cd /c/Users/Sergio/padel_app-b && git merge develop
# resolver el conflicto aquí, con las dos versiones delante
```

### Conflicto que no entiendes al fusionar

```sh
git merge --abort          # deshace la fusión, no pierdes nada
git diff develop...HEAD    # qué has cambiado tú
git diff develop...lane/b  # qué ha cambiado la otra
```

Con eso decides quién manda antes de volver a intentarlo.

### Las dos lanes crearon la migración 0004

La que aún no se haya aplicado a la BD se renumera a `0005` y se ajusta lo que
dependa del orden. **Si las dos se aplicaron ya a Supabase**, no renumeres nada:
la BD ya tiene un estado que los ficheros no describen. Escribe una `0006` que
lo deje consistente y anota en el fichero por qué existe.

### La base de datos compartida está rara

```sh
cd web && npm run comprobar
```

Comprueba tablas, funciones de permisos y que RLS bloquea de verdad. No imprime
ninguna clave. Si falla, casi siempre es una migración aplicada desde la otra
lane: mira `backend/migrations/` en las dos ramas antes de tocar la BD.

### La app o la web se comportan raro tras cambiar de lane

Cada worktree tiene sus propios artefactos, pero se quedan viejos:

```sh
cd app && flutter clean && flutter pub get
cd web && rm -rf .next && npm install
```

### `fatal: 'lane/a' is already checked out`

Git no deja la misma rama en dos worktrees, y hace bien. Trabaja en la carpeta
que ya la tiene, no la saques de ahí.

### Quiero empezar una lane de cero

```sh
cd /c/Users/Sergio/padel_app
git worktree remove --force ../padel_app-a
git branch -D lane/a                       # ¡pierde commits no integrados!
git worktree add ../padel_app-a -b lane/a develop
cp web/.env.local ../padel_app-a/web/.env.local
cp .claude/settings.local.json ../padel_app-a/.claude/settings.local.json
cd ../padel_app-a/web && npm install
```

`web/.env.local` y `.claude/settings.local.json` no están versionados: un
worktree nuevo **no los tiene** y la web no arranca hasta que los copies.

### El worktree ya no existe pero git cree que sí

```sh
git worktree prune
```
