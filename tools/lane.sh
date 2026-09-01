#!/bin/sh
# Estado de las lanes: qué ha tocado cada una y dónde se solapan.
#
#   sh tools/lane.sh          desde cualquier worktree
#
# No modifica nada. Lee el .git compartido y los directorios de trabajo de las
# otras lanes, así que funciona sin red y sin que nadie haya hecho push.
#
# CUENTA LO NO COMMITEADO A PROPÓSITO. La primera versión sólo comparaba ramas
# y por eso no vio venir el choque para el que existe: las dos lanes crearon una
# migración 0009 distinta y las dos la tenían sin commitear. Mirar sólo lo
# commiteado es mirar donde ya no hay peligro — el trabajo en curso es
# justamente el que todavía se puede reconducir sin dolor.

BASE="${BASE:-develop}"
LANES="${LANES:-lane/a lane/b}"
AQUI=$(git branch --show-current)
RAIZ=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/\.git$||')

# Ficheros calientes: tocarlos afecta a la otra lane aunque no lo parezca.
CALIENTES="docs/protocol/README.md backend/migrations/ app/pubspec.yaml web/package.json web/package-lock.json"

# Dónde está montada una rama, si lo está.
carpeta_de() {
  git worktree list --porcelain 2>/dev/null |
    awk -v rama="refs/heads/$1" '
      /^worktree /  { dir = substr($0, 10) }
      /^branch /    { if (substr($0, 8) == rama) { print dir; exit } }
    '
}

# Todo lo que una lane ha tocado: lo commiteado sobre develop MÁS lo que tenga
# sin commitear en su directorio de trabajo.
tocados() {
  git rev-parse --verify -q "$1" >/dev/null || return
  git diff --name-only "$BASE...$1" 2>/dev/null

  CARPETA=$(carpeta_de "$1")
  if [ -n "$CARPETA" ] && [ -d "$CARPETA" ]; then
    # --porcelain incluye los no seguidos (??) con -uall.
    git -C "$CARPETA" status --porcelain -uall 2>/dev/null |
      sed 's/^...//' |
      sed 's/.* -> //'
  fi
}

# Sin repetidos: un fichero puede estar commiteado y además modificado.
tocados_unicos() {
  tocados "$1" | sed '/^$/d' | sort -u
}

printf '\033[1mEstás en:\033[0m %s\n\n' "${AQUI:-(detached HEAD)}"

for L in $LANES; do
  git rev-parse --verify -q "$L" >/dev/null || continue
  N=$(tocados_unicos "$L" | wc -l | tr -d ' ')
  ADELANTO=$(git rev-list --count "$BASE".."$L" 2>/dev/null)
  SIN=$(
    CARPETA=$(carpeta_de "$L")
    [ -n "$CARPETA" ] && git -C "$CARPETA" status --porcelain -uall 2>/dev/null | wc -l | tr -d ' '
  )
  MARCA=""
  [ "$L" = "$AQUI" ] && MARCA=' \033[2m<- tú\033[0m'
  printf "\033[1m%s\033[0m  %s commits sobre %s, %s sin commitear, %s ficheros$MARCA\n" \
    "$L" "$ADELANTO" "$BASE" "${SIN:-?}" "$N"
  tocados_unicos "$L" | sed 's/^/    /'
  echo
done

# Solapamiento real entre las dos lanes.
TMP_A=$(mktemp); TMP_B=$(mktemp)
L1=$(echo $LANES | cut -d' ' -f1)
L2=$(echo $LANES | cut -d' ' -f2)
tocados_unicos "$L1" > "$TMP_A"
tocados_unicos "$L2" > "$TMP_B"
CHOQUE=$(comm -12 "$TMP_A" "$TMP_B")

# Choque de numeración: dos migraciones con el mismo número y distinto nombre no
# dan conflicto en git —son ficheros distintos— y se aplican las dos sobre la
# MISMA base de datos. Es el fallo que no avisa, así que se busca aparte.
NUM_A=$(grep '^backend/migrations/' "$TMP_A" | sed 's|.*/||; s/_.*//' | sort -u)
NUM_B=$(grep '^backend/migrations/' "$TMP_B" | sed 's|.*/||; s/_.*//' | sort -u)
REPETIDOS=$(printf '%s\n' "$NUM_A" | sed '/^$/d' | while read -r n; do
  printf '%s\n' "$NUM_B" | grep -qx "$n" && echo "$n"
done)

rm -f "$TMP_A" "$TMP_B"

if [ -n "$REPETIDOS" ]; then
  printf '\033[31m\033[1mCHOQUE DE MIGRACIONES - mismo número en las dos lanes:\033[0m\n'
  printf '%s\n' "$REPETIDOS" | sed 's/^/    /'
  printf '\n    Git no da conflicto porque son ficheros distintos, pero la base\n'
  printf '    de datos es la misma. Renumera una antes de aplicar nada.\n\n'
fi

if [ -n "$CHOQUE" ]; then
  printf '\033[31m\033[1mCHOQUE - las dos lanes han tocado esto:\033[0m\n'
  printf '%s\n' "$CHOQUE" | sed 's/^/    /'
  printf '\n    Integra una en %s y rebasa la otra ANTES de seguir.\n' "$BASE"
  printf '    Ver docs/lanes.md, seccion "Cuando algo se rompe".\n\n'
elif [ -z "$REPETIDOS" ]; then
  printf '\033[32mSin solapamiento entre lanes.\033[0m\n\n'
fi

# Aviso de ficheros calientes aunque los toque una sola lane.
for L in $LANES; do
  for C in $CALIENTES; do
    if tocados_unicos "$L" | grep -q "^$C"; then
      printf '\033[33mAVISO\033[0m  %s toca \033[1m%s\033[0m - fichero compartido, avisa a la otra lane.\n' "$L" "$C"
    fi
  done
done
