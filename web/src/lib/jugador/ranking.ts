/**
 * El ranking, y cuándo tiene derecho a existir.
 *
 * Ordenar por nivel es la parte fácil. Lo que decide si un ranking se cree o no
 * son tres reglas que no se ven en la fórmula:
 *
 * 1. **Quien es provisional no aparece.** Enseñar en un puesto a alguien de
 *    quien todavía no se sabe nada es la forma más rápida de que la tabla deje
 *    de significar algo.
 * 2. **Los empates comparten puesto.** Dos jugadores con el mismo nivel están
 *    los dos terceros, y el siguiente es quinto. Es como se lee una clasificación
 *    y es como lo hace ya el panel.
 * 3. **Un ranking que mezcla gente que nunca se ha cruzado es una estimación.**
 *    Ésta es la importante, y la que no se le ocurre a nadie hasta que se mide:
 *    el rating sólo compara de verdad a quienes están unidos por partidos. En
 *    simulación, dos clubes separados por 300 puntos reales que nunca se cruzan
 *    acaban **los dos en el mismo número**. La tabla no queda imprecisa: dice que
 *    son iguales cuando no lo son.
 *
 * De ahí que aquí se calculen los **grupos conectados**: si el ranking abarca más
 * de uno, se marca como estimado y se dice por qué. Dentro de un club siempre hay
 * un solo grupo, así que el ranking del club nunca lleva ese aviso — que es
 * justamente por lo que el del club es el único que se puede enseñar de entrada.
 */

import { esProvisional, type JugadorId, type RatingJugador } from "../rating/algoritmo.ts";
import { divisionDe, ESCALA_UY, type EscalaDeDivisiones } from "../rating/divisiones.ts";
import type { Partido } from "../historial/partidos.ts";

export type FilaRanking = {
  puesto: number;
  jugadorId: JugadorId;
  rating: number;
  division: string;
  partidos: number;
  /** Puestos ganados desde la foto anterior. Null si no estaba. */
  movimiento: number | null;
};

export type OpcionesRanking = {
  /** Fuera por defecto: un rating sin base no merece un puesto. */
  incluirProvisionales?: boolean;
  /** Puestos de la foto anterior, para pintar las flechas. */
  anterior?: ReadonlyMap<JugadorId, number>;
  escala?: EscalaDeDivisiones;
};

export function ranking(
  ratings: ReadonlyMap<JugadorId, RatingJugador>,
  opciones: OpcionesRanking = {},
): FilaRanking[] {
  const escala = opciones.escala ?? ESCALA_UY;

  const candidatos = [...ratings.entries()]
    .filter(([, r]) => opciones.incluirProvisionales === true || !esProvisional(r))
    .sort(([idA, a], [idB, b]) => b.rating - a.rating || idA.localeCompare(idB));

  const filas: FilaRanking[] = [];
  let puesto = 0;
  let anterior: number | null = null;

  candidatos.forEach(([jugadorId, actual], indice) => {
    // Mismo rating, mismo puesto; el siguiente salta los que empataron.
    if (anterior === null || actual.rating !== anterior) puesto = indice + 1;
    anterior = actual.rating;

    const antes = opciones.anterior?.get(jugadorId);
    filas.push({
      puesto,
      jugadorId,
      rating: actual.rating,
      division: divisionDe(escala, actual.rating).nombre,
      partidos: actual.partidosPuntuados,
      movimiento: antes === undefined ? null : antes - puesto,
    });
  });

  return filas;
}

/** Los puestos de un ranking, para poder comparar con el de la semana que viene. */
export function puestosDe(filas: readonly FilaRanking[]): Map<JugadorId, number> {
  return new Map(filas.map((f) => [f.jugadorId, f.puesto]));
}

// ------------------------------------------------------- quién con quién

/**
 * Grupos de jugadores unidos por partidos, directa o indirectamente.
 *
 * Si A jugó con B y B jugó con C, los tres son comparables aunque A y C no se
 * hayan visto nunca: hay un camino entre ellos y el rating lo recorre. Lo que no
 * hay forma de comparar son dos grupos sin ningún partido en común.
 */
export function gruposConectados(partidos: readonly Partido[]): JugadorId[][] {
  const padre = new Map<JugadorId, JugadorId>();

  const raiz = (x: JugadorId): JugadorId => {
    let actual = padre.get(x) ?? x;
    if (!padre.has(x)) padre.set(x, x);
    while (actual !== padre.get(actual)) {
      const abuelo = padre.get(padre.get(actual)!)!;
      padre.set(actual, abuelo);
      actual = abuelo;
    }
    return actual;
  };

  const unir = (x: JugadorId, y: JugadorId) => {
    const rx = raiz(x);
    const ry = raiz(y);
    if (rx !== ry) padre.set(rx, ry);
  };

  for (const partido of partidos) {
    const cuatro = [...partido.a, ...partido.b];
    for (const jugador of cuatro) raiz(jugador);
    for (let i = 1; i < cuatro.length; i++) unir(cuatro[0], cuatro[i]);
  }

  const grupos = new Map<JugadorId, JugadorId[]>();
  for (const jugador of padre.keys()) {
    const r = raiz(jugador);
    const grupo = grupos.get(r);
    if (grupo) grupo.push(jugador);
    else grupos.set(r, [jugador]);
  }

  return [...grupos.values()]
    .map((g) => g.sort())
    .sort((x, y) => y.length - x.length || x[0].localeCompare(y[0]));
}

export type Fiabilidad = {
  /** True cuando todos los del ranking están unidos por partidos. */
  comparable: boolean;
  /** Cuántos grupos sin partidos en común hay dentro de esta tabla. */
  grupos: number;
  /** Para decirlo en pantalla sin que suene a error. */
  aviso: string | null;
};

/**
 * ¿Se puede enseñar esta tabla como un ranking, o sólo como una estimación?
 *
 * Dentro de un club siempre sale comparable: todos han jugado americanos juntos.
 * Al juntar clubes, no — hasta que haya torneos abiertos o gente que juegue en
 * los dos. Cada uno de esos partidos vale por diez de los demás.
 */
export function fiabilidadDelRanking(
  filas: readonly FilaRanking[],
  partidos: readonly Partido[],
): Fiabilidad {
  const enLaTabla = new Set(filas.map((f) => f.jugadorId));
  const grupos = gruposConectados(partidos)
    .map((g) => g.filter((id) => enLaTabla.has(id)))
    .filter((g) => g.length > 0);

  // Quien está en la tabla y no ha jugado ningún partido es un grupo suyo.
  const cubiertos = new Set(grupos.flat());
  const sueltos = [...enLaTabla].filter((id) => !cubiertos.has(id));
  const total = grupos.length + sueltos.length;

  if (total <= 1) return { comparable: true, grupos: total, aviso: null };

  return {
    comparable: false,
    grupos: total,
    aviso:
      `Estimado: hay ${total} grupos que no se han cruzado en ningún partido. ` +
      `Los niveles de un grupo y otro no se pueden comparar todavía.`,
  };
}
