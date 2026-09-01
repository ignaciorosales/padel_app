/**
 * Corregir a mano un cuadro ya generado.
 *
 * El generador reparte bien, pero el sábado pasan cosas que no sabe: uno no
 * aparece, otro llega tarde, dos quieren jugar juntos. Sin poder tocarlo, el
 * club vuelve al papel — que es exactamente la métrica que el plan de producto
 * dice vigilar.
 *
 * La decisión de diseño es que **todo cambio es un intercambio**. Poner a Ana
 * en la pista 1 no puede dejar un hueco ni duplicarla: quien estuviera ahí se
 * va al sitio de Ana. Así ninguna corrección deja el cuadro en un estado
 * inválido, y el que corrige no tiene que pensar en dos pasos.
 */

export type Posicion = "a1" | "a2" | "b1" | "b2";

export const POSICIONES: Posicion[] = ["a1", "a2", "b1", "b2"];

export type PartidoCorregible = {
  id: string;
  pista: number;
  a1: string;
  a2: string;
  b1: string;
  b2: string;
};

/** Lo que hay que escribir en un partido. Vacío = ese partido no cambia. */
export type Cambio = {
  id: string;
  campos: Partial<Record<Posicion, string>> & { pista?: number };
};

/**
 * Pone a `entra` en una posición concreta de un partido.
 *
 * Tres casos, y los tres acaban en un cuadro válido:
 *   · `entra` ya estaba ahí → no se toca nada.
 *   · `entra` jugaba en otro sitio de esta ronda → los dos se intercambian.
 *   · `entra` descansaba → ocupa el hueco, y el que estaba pasa a descansar.
 */
export function moverJugador(
  partidos: PartidoCorregible[],
  partidoId: string,
  posicion: Posicion,
  entra: string,
): Cambio[] {
  const destino = partidos.find((p) => p.id === partidoId);
  if (!destino) return [];

  const sale = destino[posicion];
  if (sale === entra) return [];

  // ¿Dónde juega ahora el que entra?
  for (const p of partidos) {
    for (const pos of POSICIONES) {
      if (p[pos] !== entra) continue;

      if (p.id === destino.id) {
        // Intercambio dentro del mismo partido: cambiar de lado o de pareja.
        return [{ id: p.id, campos: { [pos]: sale, [posicion]: entra } }];
      }

      return [
        { id: destino.id, campos: { [posicion]: entra } },
        { id: p.id, campos: { [pos]: sale } },
      ];
    }
  }

  // Venía de descansar: el que sale se queda sin partido esta ronda.
  return [{ id: destino.id, campos: { [posicion]: entra } }];
}

/**
 * Cambia un partido de pista. Si la pista ya está ocupada, los dos partidos se
 * intercambian — dejar dos partidos en la misma pista no es una opción, y la
 * base de datos tampoco lo permite (`unique (round_id, pista)`).
 */
export function moverPista(
  partidos: PartidoCorregible[],
  partidoId: string,
  nuevaPista: number,
): Cambio[] {
  const destino = partidos.find((p) => p.id === partidoId);
  if (!destino || destino.pista === nuevaPista) return [];

  const ocupante = partidos.find(
    (p) => p.pista === nuevaPista && p.id !== destino.id,
  );

  if (!ocupante) return [{ id: destino.id, campos: { pista: nuevaPista } }];

  return [
    { id: destino.id, campos: { pista: nuevaPista } },
    { id: ocupante.id, campos: { pista: destino.pista } },
  ];
}

/**
 * Aplica los cambios sobre la lista, para poder comprobar el resultado sin
 * base de datos. La acción de servidor escribe fila a fila; esto es lo que
 * permite que los tests hablen de cuadros y no de UPDATEs.
 */
export function aplicar(
  partidos: PartidoCorregible[],
  cambios: Cambio[],
): PartidoCorregible[] {
  return partidos.map((p) => {
    const suyo = cambios.find((c) => c.id === p.id);
    return suyo ? { ...p, ...suyo.campos } : p;
  });
}

/** Nadie puede jugar dos partidos a la vez ni dos partidos compartir pista. */
export function cuadroValido(partidos: PartidoCorregible[]): boolean {
  const jugadores = partidos.flatMap((p) => POSICIONES.map((pos) => p[pos]));
  const pistas = partidos.map((p) => p.pista);

  return (
    new Set(jugadores).size === jugadores.length &&
    new Set(pistas).size === pistas.length
  );
}
