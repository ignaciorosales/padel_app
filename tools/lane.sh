#!/bin/sh
# Estado de las lanes: qué ha tocado cada una y dónde se solapan.
#
#   sh tools/lane.sh          desde cualquier worktree
#
# No modifica nada. Lee las ramas del .git compartido, así que funciona sin red
# y sin que la otra lane haya hecho push.

BASE="${BASE:-develop}"
LANES="${LANES:-lane/a lane/b}"
AQUI=$(git branch --show-current)

# Ficheros calientes: tocarlos afecta a la otra lane aunque no lo parezca.
CALIENTES="docs/protocol/README.md backend/migrations/ app/pubspec.yaml web/package.json web/package-lock.json"

tocados() {
  git rev-parse --verify -q "$1" >/dev/null || return
  git diff --name-only "$BASE...$1" 2>/dev/null
}

printf '\033[1mEstás en:\033[0m %s\n\n' "${AQUI:-(detached HEAD)}"

for L in $LANES; do
  git rev-parse --verify -q "$L" >/dev/null || continue
  N=$(tocados "$L" | wc -l | tr -d ' ')
  ADELANTO=$(git rev-list --count "$BASE".."$L" 2>/dev/null)
  MARCA=""
  [ "$L" = "$AQUI" ] && MARCA=' \033[2m<- tú\033[0m'
  printf "\033[1m%s\033[0m  %s commits sobre %s, %s ficheros$MARCA\n" "$L" "$ADELANTO" "$BASE" "$N"
  tocados "$L" | sed 's/^/    /'
  echo
done

# Solapamiento real entre las dos lanes.
TMP_A=$(mktemp); TMP_B=$(mktemp)
L1=$(echo $LANES | cut -d' ' -f1)
L2=$(echo $LANES | cut -d' ' -f2)
tocados "$L1" | sort > "$TMP_A"
tocados "$L2" | sort > "$TMP_B"
CHOQUE=$(comm -12 "$TMP_A" "$TMP_B")
rm -f "$TMP_A" "$TMP_B"

if [ -n "$CHOQUE" ]; then
  printf '\033[31m\033[1mCHOQUE - las dos lanes han tocado esto:\033[0m\n'
  printf '%s\n' "$CHOQUE" | sed 's/^/    /'
  printf '\n    Integra una en %s y rebasa la otra ANTES de seguir.\n' "$BASE"
  printf '    Ver docs/lanes.md, seccion "Cuando algo se rompe".\n\n'
else
  printf '\033[32mSin solapamiento entre lanes.\033[0m\n\n'
fi

# Aviso de ficheros calientes aunque los toque una sola lane.
for L in $LANES; do
  for C in $CALIENTES; do
    if tocados "$L" | grep -q "^$C"; then
      printf '\033[33mAVISO\033[0m  %s toca \033[1m%s\033[0m - fichero compartido, avisa a la otra lane.\n' "$L" "$C"
    fi
  done
done
