/**
 * Los cuatro ámbitos de un ranking: club, ciudad, país y red.
 *
 * `ranking.ts` sabe ordenar y sabe cuándo una tabla es una estimación en vez de
 * un ranking. Lo que no sabe es **a quién meter en la tabla**, y ésa es toda la
 * función de este fichero: traducir las filas que devuelven las dos funciones de
 * Postgres al mapa de ratings que come el ranking, y filtrar por división.
 *
 * Dos cosas que parecen detalles y no lo son:
 *
 * 1. **Cuanto más ancho el ámbito, menos fiable la tabla.** No por el tamaño:
 *    porque los grupos que nunca se han cruzado no se pueden comparar. Dentro de
 *    un club todos han jugado americanos juntos y el ranking es un ranking; el de
 *    un país, hasta que haya torneos abiertos, son doce tablas apiladas. Eso ya lo
 *    calcula `fiabilidadDeLosGrupos`, y aquí se le dan los datos para que pueda.
 * 2. **La división del ranking es la guardada, no la del rating.** Filtrar por
 *    `divisionDe(rating)` metería en 2ª a quien está por encima del umbral pero
 *    todavía no ha ascendido, y esa persona no compite en 2ª.
 */

import { esProvisional, type JugadorId, type RatingJugador } from "../rating/algoritmo.ts";
import { ESCALA_UY, type EscalaDeDivisiones } from "../rating/divisiones.ts";
import {
  fiabilidadDeLosGrupos,
  gruposDeCamarillas,
  puestosDe,
  ranking,
  type Fiabilidad,
  type FilaRanking,
  type OpcionesRanking,
} from "./ranking.ts";

/** Los cuatro ámbitos, de más estrecho a más ancho. Ese orden es el de fiabilidad. */
export const AMBITOS = ["club", "ciudad", "pais", "red"] as const;

export type Ambito = (typeof AMBITOS)[number];

export const ETIQUETA_AMBITO: Record<Ambito, string> = {
  club: "Club",
  ciudad: "Ciudad",
  pais: "País",
  red: "Toda la red",
};

export function esAmbito(valor: string): valor is Ambito {
  return (AMBITOS as readonly string[]).includes(valor);
}

/** Una fila de `jugadores_del_ambito()`. */
export type FilaDelAmbito = {
  player_id: string;
  nombre: string;
  apellido: string | null;
  apodo: string | null;
  rating: number;
  desviacion: number;
  confianza: number;
  partidos_puntuados: number;
  ultimo_partido: string | null;
  division: string;
  escala: string;
};

/** Una fila de `coincidencias_del_ambito()`. */
export type FilaDeCoincidencia = {
  partido_id: string;
  player_id: string;
};

/**
 * Las filas como las quiere `ranking()`.
 *
 * Se conserva el rating sin redondear: el ranking ordena por él, y redondear
 * antes de ordenar convierte diferencias reales de medio punto en empates.
 */
export function ratingsDeLasFilas(
  filas: readonly FilaDelAmbito[],
): Map<JugadorId, RatingJugador> {
  return new Map(
    filas.map((f) => [
      f.player_id,
      {
        jugadorId: f.player_id,
        rating: f.rating,
        desviacion: f.desviacion,
        confianza: f.confianza,
        partidosPuntuados: f.partidos_puntuados,
        ultimoPartido: f.ultimo_partido,
      },
    ]),
  );
}

/**
 * Quién coincidió con quién, de las transacciones.
 *
 * Dos jugadores con una transacción del mismo partido jugaron ese partido. Es la
 * misma información que da la lista de partidos, y para una ciudad es la única que
 * se puede pedir sin traerse el historial de doce clubes.
 */
export function camarillasDeLasCoincidencias(
  filas: readonly FilaDeCoincidencia[],
): JugadorId[][] {
  const porPartido = new Map<string, JugadorId[]>();
  for (const fila of filas) {
    const suyos = porPartido.get(fila.partido_id);
    if (suyos) suyos.push(fila.player_id);
    else porPartido.set(fila.partido_id, [fila.player_id]);
  }
  return [...porPartido.values()];
}

export type Tabla = {
  filas: FilaRanking[];
  fiabilidad: Fiabilidad;
  /** Cómo se llama cada uno, para no pintar uuids. */
  nombrePor: Map<string, string>;
  /** Cuántos se quedaron fuera por ser provisionales. Se dice, no se esconde. */
  provisionales: number;
  /** Las divisiones que aparecen en el ámbito, para llenar el filtro. */
  divisiones: string[];
};

export type OpcionesDeTabla = OpcionesRanking & {
  /** Sólo una división. Null es todas. */
  division?: string | null;
};

/**
 * La tabla completa de un ámbito, lista para pintar.
 *
 * El filtro de división se aplica **antes** de ordenar, y por eso los puestos son
 * los de la división y no los de la tabla general: quien mira el ranking de 3ª
 * quiere saber que va tercero de 3ª, no que va cuadragésimo de la ciudad.
 */
export function tablaDelAmbito(
  jugadores: readonly FilaDelAmbito[],
  coincidencias: readonly FilaDeCoincidencia[],
  opciones: OpcionesDeTabla = {},
): Tabla {
  const division = opciones.division ?? null;
  const enAmbito = division === null
    ? jugadores
    : jugadores.filter((f) => f.division === division);

  const ratings = ratingsDeLasFilas(enAmbito);
  const filas = ranking(ratings, opciones);

  // Los que el ranking dejó fuera. Decir "hay 8 más con menos de quince partidos"
  // convierte una tabla incompleta en una tabla que explica lo que le falta.
  const enLaTabla = new Set(filas.map((f) => f.jugadorId));
  const provisionales = [...ratings.values()].filter(
    (r) => !enLaTabla.has(r.jugadorId) && esProvisional(r),
  ).length;

  const camarillas = camarillasDeLasCoincidencias(coincidencias);

  return {
    filas,
    // La fiabilidad se calcula sobre la tabla que se enseña: si se filtra por
    // división, lo que importa es si esos jugadores se han cruzado entre ellos.
    fiabilidad: fiabilidadDeLosGrupos(filas, gruposDeCamarillas(camarillas)),
    nombrePor: new Map(enAmbito.map((f) => [f.player_id, comoSeLlamaEnLaTabla(f)])),
    provisionales,
    divisiones: divisionesPresentes(jugadores, opciones.escala ?? ESCALA_UY),
  };
}

/**
 * Las divisiones que hay gente en este ámbito, de la más alta a la más baja.
 *
 * En el orden de la escala y no en el de aparición: un desplegable que pone "3ª,
 * 7ª, 1ª" según quién se registró primero se lee como un error.
 */
function divisionesPresentes(
  jugadores: readonly FilaDelAmbito[],
  escala: EscalaDeDivisiones,
): string[] {
  const presentes = new Set(jugadores.map((f) => f.division));
  return [...escala.divisiones]
    .reverse()
    .map((d) => d.nombre)
    .filter((nombre) => presentes.has(nombre));
}

/**
 * Cómo se llama alguien en un ranking.
 *
 * Nombre y primer apellido, no el nombre completo: en una tabla de cuarenta filas
 * lo que hace falta es reconocer a alguien de un vistazo, y "Ignacio Rosales
 * Pérez" ocupa el triple sin distinguir mejor. El apodo no se usa aquí —a
 * diferencia del historial— porque un ranking es un documento y los apodos no se
 * reconocen fuera del club propio.
 */
export function comoSeLlamaEnLaTabla(fila: FilaDelAmbito): string {
  const primerApellido = fila.apellido?.trim().split(/\s+/)[0] ?? "";
  return [fila.nombre, primerApellido].filter(Boolean).join(" ");
}

export { puestosDe };
