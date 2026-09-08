/**
 * Del esquema del panel a lo que come la app del jugador.
 *
 * Los módulos de nivel e historial trabajan con partidos limpios: cuatro
 * personas y un marcador. La base de datos del panel no es así, y no es un
 * defecto suyo — es que guarda cosas que la app del jugador no puede usar:
 *
 * - **partidos sin jugar**: `juegos_a` y `juegos_b` son nulos hasta que alguien
 *   mete el resultado;
 * - **huecos y byes del cuadro**: desde que existen los torneos de parejas, los
 *   cuatro jugadores pueden ser nulos — un hueco cuya ronda anterior no ha
 *   terminado no tiene ocupante todavía;
 * - **inscritos sin unificar**: mientras nadie diga quién es "Nacho R.", ese
 *   nombre no es una persona y su partido no puede ir al historial de nadie.
 *
 * La decisión de diseño que manda aquí: **nada se descarta en silencio.** Cada
 * fila que no pasa sale con el motivo. Tirar filas calladamente es exactamente
 * como se esconde un fallo de datos: el ranking sale raro y nadie sabe por qué.
 * Con el motivo delante, el panel puede decir "faltan 12 partidos porque hay
 * ocho personas sin identificar", que además es una tarea, no un error.
 */

import type { Formato, Partido, Unidad } from "../historial/partidos.ts";
import { puntua, type PartidoPuntuable } from "../rating/algoritmo.ts";

/** Una fila de `matches` con lo que hace falta de su ronda y su torneo. */
export type FilaDelPanel = {
  id: string;
  torneoId: string;
  /** `tournaments.fecha`. */
  fecha: string;
  /** `tournaments.formato`: texto en la base de datos, con restricción. */
  formato: string;
  /** `tournaments.unidad_marcador`. */
  unidad: string;
  /** `rounds.numero`, para ordenar dentro del día. */
  ronda: number;
  pista: number;
  a1: string | null;
  a2: string | null;
  b1: string | null;
  b2: string | null;
  juegosA: number | null;
  juegosB: number | null;
};

/** De id de inscrito a id de persona. Falta el que todavía no se ha unificado. */
export type Identidades = ReadonlyMap<string, string>;

export type MotivoDeDescarte =
  | "sin_resultado"
  | "hueco_o_bye"
  | "sin_identificar"
  | "sin_juego"
  | "formato_desconocido"
  | "unidad_desconocida";

export type Descarte = {
  filaId: string;
  torneoId: string;
  motivo: MotivoDeDescarte;
};

export type Conversion = {
  partidos: Partido[];
  descartes: Descarte[];
};

const FORMATOS = new Set<string>(["americano", "parejas"]);
const UNIDADES = new Set<string>(["juegos", "sets", "puntos"]);

/**
 * Convierte las filas del panel en partidos de la app.
 *
 * El orden de salida es el que se jugó: fecha, ronda, pista. Importa porque el
 * nivel se calcula recorriendo los partidos en orden, y dos órdenes distintos
 * dan dos niveles distintos.
 */
export function partidosDelPanel(
  filas: readonly FilaDelPanel[],
  identidades: Identidades,
): Conversion {
  const partidos: Partido[] = [];
  const descartes: Descarte[] = [];

  const ordenadas = [...filas].sort(
    (x, y) =>
      x.fecha.localeCompare(y.fecha) ||
      x.ronda - y.ronda ||
      x.pista - y.pista ||
      x.id.localeCompare(y.id),
  );

  for (const fila of ordenadas) {
    const descartar = (motivo: MotivoDeDescarte) => {
      descartes.push({ filaId: fila.id, torneoId: fila.torneoId, motivo });
    };

    // Un hueco del cuadro no es un partido: es un sitio reservado.
    if (fila.a1 === null || fila.a2 === null || fila.b1 === null || fila.b2 === null) {
      descartar("hueco_o_bye");
      continue;
    }

    if (fila.juegosA === null || fila.juegosB === null) {
      descartar("sin_resultado");
      continue;
    }

    // Un 0-0 no distingue "empataron a cero" de "se anotó y no se jugó", y para
    // el nivel no aporta nada en ninguno de los dos casos.
    if (fila.juegosA + fila.juegosB <= 0) {
      descartar("sin_juego");
      continue;
    }

    // Adivinar el formato o la unidad corrompería el nivel en silencio: el peso
    // de un partido depende de los dos. Mejor que falte y se vea.
    if (!FORMATOS.has(fila.formato)) {
      descartar("formato_desconocido");
      continue;
    }
    if (!UNIDADES.has(fila.unidad)) {
      descartar("unidad_desconocida");
      continue;
    }

    const personas = [fila.a1, fila.a2, fila.b1, fila.b2].map((i) => identidades.get(i));
    if (personas.some((p) => p === undefined)) {
      descartar("sin_identificar");
      continue;
    }
    const [a1, a2, b1, b2] = personas as string[];

    // La misma persona a los dos lados: una unificación mal hecha. No se puede
    // puntuar, y es justo el aviso que hay que dar.
    if (new Set([a1, a2, b1, b2]).size !== 4) {
      descartar("sin_identificar");
      continue;
    }

    partidos.push({
      id: fila.id,
      eventoId: fila.torneoId,
      fecha: fila.fecha,
      origen: "torneo",
      formato: fila.formato as Formato,
      unidad: fila.unidad as Unidad,
      a: [a1, a2],
      b: [b1, b2],
      marcadorA: fila.juegosA,
      marcadorB: fila.juegosB,
    });
  }

  return { partidos, descartes };
}

/** El mapa de identidades a partir de los inscritos. Los sin unificar no entran. */
export function identidadesDe(
  inscritos: readonly { id: string; playerId: string | null }[],
): Identidades {
  const mapa = new Map<string, string>();
  for (const inscrito of inscritos) {
    if (inscrito.playerId !== null) mapa.set(inscrito.id, inscrito.playerId);
  }
  return mapa;
}

/**
 * Lo que se enseña cuando faltan partidos.
 *
 * "Faltan 12 partidos: 8 por gente sin identificar" es una tarea para el club.
 * "El ranking sale raro" no lo es.
 */
export function resumenDeDescartes(
  descartes: readonly Descarte[],
): Record<MotivoDeDescarte, number> {
  const cuenta: Record<MotivoDeDescarte, number> = {
    sin_resultado: 0,
    hueco_o_bye: 0,
    sin_identificar: 0,
    sin_juego: 0,
    formato_desconocido: 0,
    unidad_desconocida: 0,
  };
  for (const descarte of descartes) cuenta[descarte.motivo]++;
  return cuenta;
}

/**
 * El mismo partido, como lo quiere el motor de rating.
 *
 * Son la misma cosa vista por dos módulos: al historial le importa de qué torneo
 * salió y en qué unidad está el marcador; al rating, quién jugó y quién ganó.
 * Un solo tipo canónico y una proyección evitan que las dos formas se separen.
 */
export function paraRating(partido: Partido): PartidoPuntuable {
  return {
    id: partido.id,
    fecha: partido.fecha,
    origen: partido.origen,
    a: partido.a,
    b: partido.b,
    marcadorA: partido.marcadorA,
    marcadorB: partido.marcadorB,
  };
}

/**
 * Los que puntúan.
 *
 * El motor ya ignora por su cuenta lo que no puntúa, así que esto es comodidad,
 * no seguridad: sirve para saber de antemano cuántos partidos van a mover el
 * rating.
 */
export function soloPuntuables(partidos: readonly Partido[]): PartidoPuntuable[] {
  return partidos.filter((p) => puntua(p.origen)).map(paraRating);
}
