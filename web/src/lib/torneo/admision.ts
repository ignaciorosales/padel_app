/**
 * Quién entra en un torneo restringido, y por qué no.
 *
 * "Americano de cuarta y quinta" es lo que el club escribe en el cartel. Esto lo
 * convierte en una comprobación por inscrito, con dos reglas de producto que
 * mandan sobre todo lo demás:
 *
 * **1. No saber no es motivo para dejar fuera a nadie.** Un inscrito sin
 * identificar no tiene rating, y un inscrito identificado puede no haber jugado
 * nunca. Los dos casos salen como `sin_datos`, que es distinto de `fuera`: uno
 * dice "no encaja" y el otro "no sé". Tratar el segundo como el primero dejaría
 * fuera a diecinueve de veinticuatro el primer sábado.
 *
 * **2. Un rating provisional no excluye a nadie.** Con menos de quince partidos
 * el número está donde le dejó su división declarada, no donde está su juego. Si
 * eso bastara para cerrar la puerta, el sistema estaría echando gente de un torneo
 * por un número que él mismo dice que no se cree.
 *
 * La excepción del organizador está por encima de todo: él conoce a la gente y el
 * sistema no. Lo único que hace el sistema es que la excepción quede escrita.
 */

import { esProvisional, OPCIONES, type Opciones, type RatingJugador } from "../rating/algoritmo.ts";

/** Las restricciones de un torneo, tal cual están en `tournaments`. */
export type Restriccion = {
  ratingMinimo: number | null;
  ratingMaximo: number | null;
  /** Nombres de división. Vacío es cualquiera. */
  divisionesAdmitidas: readonly string[];
};

/** Un torneo sin restricciones, que es lo normal. */
export const SIN_RESTRICCION: Restriccion = {
  ratingMinimo: null,
  ratingMaximo: null,
  divisionesAdmitidas: [],
};

export function restringe(restriccion: Restriccion): boolean {
  return (
    restriccion.ratingMinimo !== null ||
    restriccion.ratingMaximo !== null ||
    restriccion.divisionesAdmitidas.length > 0
  );
}

export type Veredicto =
  /** Encaja, o el torneo no restringe nada. */
  | "encaja"
  /** No encaja, y se puede demostrar. */
  | "fuera"
  /** El organizador le deja entrar de todas formas. */
  | "excepcion"
  /** No hay con qué juzgarle: sin identificar, sin rating o provisional. */
  | "sin_datos";

export type Admision = {
  veredicto: Veredicto;
  /**
   * Por qué, en una frase que se puede enseñar tal cual.
   *
   * Null cuando encaja: no hace falta explicar lo que no llama la atención, y una
   * lista de veinticuatro explicaciones esconde las tres que importan.
   */
  motivo: string | null;
};

export type Candidato = {
  /** El rating guardado, o null si no tiene ficha o no tiene rating. */
  rating: RatingJugador | null;
  /** La división guardada. Null si no hay rating. */
  division: string | null;
  excepcionAprobada: boolean;
};

/**
 * ¿Entra este inscrito en este torneo?
 *
 * El orden de las comprobaciones es el orden en que hay que leerlas, y no es
 * casual: primero si el torneo restringe algo (casi nunca), luego si hay una
 * excepción escrita (que gana a todo), y sólo después los números.
 */
export function admision(
  restriccion: Restriccion,
  candidato: Candidato,
  opciones: Opciones = OPCIONES,
): Admision {
  if (!restringe(restriccion)) return { veredicto: "encaja", motivo: null };

  if (candidato.excepcionAprobada) {
    return {
      veredicto: "excepcion",
      motivo: "El organizador le deja entrar aunque no encaje.",
    };
  }

  if (candidato.rating === null) {
    return {
      veredicto: "sin_datos",
      motivo: "Sin identificar todavía: no hay rating con el que compararlo.",
    };
  }

  if (esProvisional(candidato.rating, opciones)) {
    return {
      veredicto: "sin_datos",
      motivo:
        `Rating provisional (${candidato.rating.partidosPuntuados} de ` +
        `${opciones.partidosProvisionales} partidos): todavía no dice dónde juega.`,
    };
  }

  const rating = candidato.rating.rating;

  if (restriccion.ratingMinimo !== null && rating < restriccion.ratingMinimo) {
    return {
      veredicto: "fuera",
      motivo: `${Math.round(rating)} está por debajo del mínimo de ${restriccion.ratingMinimo}.`,
    };
  }

  if (restriccion.ratingMaximo !== null && rating > restriccion.ratingMaximo) {
    return {
      veredicto: "fuera",
      motivo: `${Math.round(rating)} pasa del máximo de ${restriccion.ratingMaximo}.`,
    };
  }

  if (
    restriccion.divisionesAdmitidas.length > 0 &&
    (candidato.division === null ||
      !restriccion.divisionesAdmitidas.includes(candidato.division))
  ) {
    return {
      veredicto: "fuera",
      motivo:
        `Es de ${candidato.division ?? "división desconocida"}, y el torneo es de ` +
        `${listar(restriccion.divisionesAdmitidas)}.`,
    };
  }

  return { veredicto: "encaja", motivo: null };
}

/** "4ª y 5ª", no "4ª, 5ª": la lista se lee, no se enumera. */
export function listar(nombres: readonly string[]): string {
  if (nombres.length === 0) return "cualquier división";
  if (nombres.length === 1) return nombres[0];
  return `${nombres.slice(0, -1).join(", ")} y ${nombres[nombres.length - 1]}`;
}

/**
 * Cómo se cuenta el torneo en una línea.
 *
 * Es el texto del cartel, generado del dato. Sirve para la página pública y para
 * que el organizador vea escrito lo que acaba de configurar — que es como se
 * descubre que puso el mínimo y el máximo al revés.
 */
export function describirRestriccion(restriccion: Restriccion): string {
  if (!restringe(restriccion)) return "Abierto a cualquier nivel.";

  const partes: string[] = [];

  if (restriccion.divisionesAdmitidas.length > 0) {
    partes.push(listar(restriccion.divisionesAdmitidas));
  }

  const { ratingMinimo: min, ratingMaximo: max } = restriccion;
  if (min !== null && max !== null) partes.push(`rating de ${min} a ${max}`);
  else if (min !== null) partes.push(`rating desde ${min}`);
  else if (max !== null) partes.push(`rating hasta ${max}`);

  return `Sólo ${partes.join(", ")}.`;
}

export type Recuento = {
  encajan: number;
  fuera: number;
  excepciones: number;
  sinDatos: number;
};

/**
 * El resumen para la cabecera del torneo.
 *
 * "3 no encajan y 2 con excepción" es una tarea; una lista de veinticuatro filas
 * con un color cada una no lo es.
 */
export function recontar(admisiones: readonly Admision[]): Recuento {
  const cuenta: Recuento = { encajan: 0, fuera: 0, excepciones: 0, sinDatos: 0 };
  for (const a of admisiones) {
    if (a.veredicto === "encaja") cuenta.encajan++;
    else if (a.veredicto === "fuera") cuenta.fuera++;
    else if (a.veredicto === "excepcion") cuenta.excepciones++;
    else cuenta.sinDatos++;
  }
  return cuenta;
}

/**
 * Las restricciones tal como salen de una fila de `tournaments`.
 *
 * Una función y no un `as` porque Postgres devuelve el array como puede —vacío,
 * nulo o con nulos dentro si alguien escribió mal— y el resto del módulo asume que
 * es una lista de nombres.
 */
export function restriccionDeLaFila(fila: {
  rating_minimo?: number | null;
  rating_maximo?: number | null;
  divisiones_admitidas?: (string | null)[] | null;
}): Restriccion {
  return {
    ratingMinimo: fila.rating_minimo ?? null,
    ratingMaximo: fila.rating_maximo ?? null,
    divisionesAdmitidas: (fila.divisiones_admitidas ?? []).filter(
      (d): d is string => typeof d === "string" && d.trim().length > 0,
    ),
  };
}
