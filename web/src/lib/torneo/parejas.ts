/**
 * Fase de grupos de un torneo de parejas fijas.
 *
 * Nada que ver con el americano, y por eso vive aparte. Allí el problema es
 * repartir compañeros distintos ronda tras ronda y no tiene solución exacta;
 * aquí cada pareja juega contra todas las de su grupo y eso sí tiene una
 * solución conocida y exacta desde hace siglo y medio: el método del círculo.
 * Sin heurística, sin semillas y sin intentos — con las mismas parejas sale
 * siempre el mismo calendario.
 *
 * Lo único que se parece al americano es el final: repartir partidos en
 * jornadas sin que nadie juegue dos veces a la vez y sin pasar del número de
 * pistas que tiene el club.
 */

import {
  DESEMPATES_PAREJAS_POR_DEFECTO,
  filaVacia,
  ordenarYNumerar,
  type Criterio,
  type FilaClasificacion,
} from "./clasificacion.ts";

export type ParejaId = string;

export type PartidoParejas = {
  /** 1..pistas */
  pista: number;
  parejaA: ParejaId;
  parejaB: ParejaId;
  /** 1..grupos */
  grupo: number;
};

export type JornadaParejas = {
  numero: number;
  partidos: PartidoParejas[];
  /** Parejas de cualquier grupo que esta jornada no juegan. */
  descansan: ParejaId[];
};

export type FaseGrupos = {
  /** Las parejas de cada grupo. El índice 0 es el grupo 1. */
  grupos: ParejaId[][];
  jornadas: JornadaParejas[];
};

/**
 * Reparte las parejas en grupos en serpentina (1,2,3,3,2,1,…) y no por bloques.
 *
 * Si vinieran ordenadas por nivel —y el que inscribe suele apuntar primero a
 * los buenos—, por bloques saldría un grupo de la muerte y otro de relleno.
 * En serpentina cada grupo recibe una de cada franja.
 */
export function repartirEnGrupos(
  parejas: ParejaId[],
  grupos: number,
): ParejaId[][] {
  const total = Math.max(1, Math.min(grupos, parejas.length));
  const reparto: ParejaId[][] = Array.from({ length: total }, () => []);

  parejas.forEach((pareja, i) => {
    const vuelta = Math.floor(i / total);
    const dentro = i % total;
    // Las vueltas impares se recorren al revés: ahí está la serpentina.
    const grupo = vuelta % 2 === 0 ? dentro : total - 1 - dentro;
    reparto[grupo].push(pareja);
  });

  return reparto;
}

/**
 * Método del círculo: con N parejas salen N-1 vueltas y cada pareja juega
 * contra todas las demás exactamente una vez.
 *
 * Con N impar se añade un hueco —un `null`, no una cadena mágica que algún día
 * choque con un id— y quien lo tenga enfrente descansa esa vuelta.
 */
export function roundRobin(ids: ParejaId[]): [ParejaId, ParejaId][][] {
  if (ids.length < 2) return [];

  const lista: (ParejaId | null)[] = [...ids];
  if (lista.length % 2 === 1) lista.push(null);

  const n = lista.length;
  const vueltas: [ParejaId, ParejaId][][] = [];

  for (let v = 0; v < n - 1; v++) {
    const partidos: [ParejaId, ParejaId][] = [];

    for (let i = 0; i < n / 2; i++) {
      const a = lista[i];
      const b = lista[n - 1 - i];
      if (a !== null && b !== null) partidos.push([a, b]);
    }

    vueltas.push(partidos);

    // La primera queda fija y las demás rotan una posición.
    lista.splice(1, 0, lista.pop()!);
  }

  return vueltas;
}

/**
 * El calendario completo de la fase de grupos.
 *
 * Los partidos de todos los grupos se mezclan en las mismas jornadas: si hay
 * cuatro pistas no tiene sentido que el grupo 1 juegue mientras el 2 mira. Se
 * colocan uno a uno en la primera jornada que tenga pista libre y en la que
 * ninguna de las dos parejas juegue ya.
 */
export function generarFaseGrupos({
  parejas,
  grupos,
  pistas,
}: {
  parejas: ParejaId[];
  grupos: number;
  pistas: number;
}): FaseGrupos {
  if (parejas.length < 2) {
    throw new Error("Hacen falta al menos 2 parejas para una fase de grupos.");
  }
  if (pistas < 1) {
    throw new Error("Hace falta al menos una pista.");
  }

  const reparto = repartirEnGrupos(parejas, grupos);

  // Los partidos de cada grupo, vuelta a vuelta. Se recorren en paralelo para
  // que los grupos avancen a la vez y no se termine uno antes de empezar otro.
  const porVuelta: { grupo: number; par: [ParejaId, ParejaId] }[][] = [];

  reparto.forEach((delGrupo, indice) => {
    roundRobin(delGrupo).forEach((vuelta, v) => {
      porVuelta[v] ??= [];
      for (const par of vuelta) porVuelta[v].push({ grupo: indice + 1, par });
    });
  });

  const jornadas: JornadaParejas[] = [];

  for (const vuelta of porVuelta) {
    for (const { grupo, par } of vuelta) {
      let jornada = jornadas.find(
        (j) =>
          j.partidos.length < pistas &&
          !j.partidos.some((p) =>
            [p.parejaA, p.parejaB].some((x) => x === par[0] || x === par[1]),
          ),
      );

      if (!jornada) {
        jornada = { numero: jornadas.length + 1, partidos: [], descansan: [] };
        jornadas.push(jornada);
      }

      jornada.partidos.push({
        pista: jornada.partidos.length + 1,
        parejaA: par[0],
        parejaB: par[1],
        grupo,
      });
    }
  }

  // Quién descansa se deduce, no se guarda: así no puede contradecir al cuadro.
  for (const jornada of jornadas) {
    const jugando = new Set(
      jornada.partidos.flatMap((p) => [p.parejaA, p.parejaB]),
    );
    jornada.descansan = parejas.filter((p) => !jugando.has(p));
  }

  return { grupos: reparto, jornadas };
}

export type PartidoJugadoParejas = {
  parejaA: ParejaId;
  parejaB: ParejaId;
  juegosA: number;
  juegosB: number;
};

/**
 * Clasificación de una lista de parejas.
 *
 * Misma forma de fila que la individual y mismos criterios de desempate: lo
 * único que cambia es que cada partido suma a dos competidores en vez de a
 * cuatro. El orden por defecto sí es distinto, y a propósito — ver
 * DESEMPATES_PAREJAS_POR_DEFECTO.
 */
export function clasificacionParejas(
  parejaIds: ParejaId[],
  partidos: PartidoJugadoParejas[],
  desempates: Criterio[] = DESEMPATES_PAREJAS_POR_DEFECTO,
): FilaClasificacion[] {
  const filas = new Map(parejaIds.map((id) => [id, filaVacia(id)]));

  for (const p of partidos) {
    for (const [id, favor, contra] of [
      [p.parejaA, p.juegosA, p.juegosB],
      [p.parejaB, p.juegosB, p.juegosA],
    ] as const) {
      const fila = filas.get(id);
      // Un partido de una pareja ya borrada no cuenta para nadie.
      if (!fila) continue;

      fila.partidos++;
      fila.juegosFavor += favor;
      fila.juegosContra += contra;
      if (favor > contra) fila.ganados++;
      else if (favor < contra) fila.perdidos++;
      else fila.empatados++;
    }
  }

  return ordenarYNumerar([...filas.values()], parejaIds, desempates);
}

/**
 * Una tabla por grupo, que es como se enseña y como se decide quién pasa.
 *
 * Cada grupo se numera desde el puesto 1: en un torneo de cuatro grupos hay
 * cuatro primeros, no un primero y tres que no lo son.
 */
export function clasificacionPorGrupo(
  grupos: ParejaId[][],
  partidos: PartidoJugadoParejas[],
  desempates: Criterio[] = DESEMPATES_PAREJAS_POR_DEFECTO,
): FilaClasificacion[][] {
  return grupos.map((delGrupo) => {
    const dentro = new Set(delGrupo);
    return clasificacionParejas(
      delGrupo,
      partidos.filter((p) => dentro.has(p.parejaA) && dentro.has(p.parejaB)),
      desempates,
    );
  });
}

/**
 * Las parejas que pasan al cuadro, en orden de siembra.
 *
 * Se intercalan los grupos (1º del A, 1º del B, 2º del A, 2º del B…) para que
 * el cruce de cuartos no enfrente en la primera ronda a dos que ya se vieron
 * en la fase de grupos, que es la queja clásica de cualquier torneo.
 */
export function clasificados(
  porGrupo: ParejaId[][],
  cuantasPorGrupo: number,
): ParejaId[] {
  const salida: ParejaId[] = [];

  for (let puesto = 0; puesto < cuantasPorGrupo; puesto++) {
    for (const grupo of porGrupo) {
      if (grupo[puesto] !== undefined) salida.push(grupo[puesto]);
    }
  }

  return salida;
}
