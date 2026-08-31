/**
 * Generador de rondas de americano.
 *
 * Es la única pieza del MVP con dificultad de verdad, así que vive aparte: sin
 * base de datos, sin React y sin fechas. Entra una lista de jugadores y salen
 * las rondas; el resto del programa se encarga de guardarlas y de ponerles hora.
 *
 * El problema (repartir a N jugadores en parejas distintas ronda tras ronda) es
 * el del "social golfer" y no tiene solución exacta rápida. Lo que se hace aquí
 * es lo que hace falta en un club: construir cada ronda con una heurística
 * voraz, repetir el intento muchas veces con semillas distintas y quedarse con
 * el mejor resultado. Con la misma semilla sale siempre lo mismo, así que el
 * organizador puede regenerar y obtener el cuadro que ya había visto.
 *
 * Prioridades, en este orden:
 *   1. Nadie juega dos veces en la misma ronda.
 *   2. Todos juegan un número parecido de partidos.
 *   3. Que no se repitan compañeros.
 *   4. Que no se repitan rivales.
 */

export type Partido = {
  /** 1..pistas */
  pista: number;
  equipoA: [string, string];
  equipoB: [string, string];
};

export type Ronda = {
  /** 1..rondas */
  numero: number;
  partidos: Partido[];
  descansan: string[];
};

export type Calidad = {
  /** Veces que dos jugadores repiten como compañeros. 0 es lo ideal. */
  companerosRepetidos: number;
  /** Veces que dos jugadores repiten como rivales. Menos importante. */
  rivalesRepetidos: number;
  partidosPorJugador: { min: number; max: number };
  descansosPorJugador: { min: number; max: number };
};

export type Cuadro = {
  rondas: Ronda[];
  calidad: Calidad;
  /** Semilla con la que se generó: guárdala para poder reproducirlo. */
  semilla: number;
};

export type OpcionesAmericano = {
  jugadores: string[];
  pistas: number;
  rondas: number;
  /** Por defecto 1. Misma semilla y mismas opciones ⇒ mismo cuadro. */
  semilla?: number;
  /** Cuántas construcciones distintas se prueban. Por defecto 200. */
  intentos?: number;
};

/** Repetir compañero molesta mucho más que repetir rival. */
const PESO_COMPANERO = 10;
const PESO_RIVAL = 1;

/** Generador pseudoaleatorio con semilla (mulberry32): pequeño y reproducible. */
function crearAzar(semilla: number): () => number {
  let estado = semilla >>> 0;
  return function siguiente() {
    estado = (estado + 0x6d2b79f5) >>> 0;
    let t = estado;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function matrizCeros(n: number): number[][] {
  return Array.from({ length: n }, () => new Array<number>(n).fill(0));
}

function barajar<T>(lista: T[], azar: () => number): T[] {
  const copia = [...lista];
  for (let i = copia.length - 1; i > 0; i--) {
    const j = Math.floor(azar() * (i + 1));
    [copia[i], copia[j]] = [copia[j], copia[i]];
  }
  return copia;
}

type Construccion = {
  rondas: number[][][]; // ronda -> partido -> [a, b, c, d] (índices)
  descansos: number[][];
  coste: number;
  companero: number[][];
  rival: number[][];
  jugados: number[];
};

function construir(
  n: number,
  pistas: number,
  rondas: number,
  azar: () => number,
): Construccion {
  const companero = matrizCeros(n);
  const rival = matrizCeros(n);
  const jugados = new Array<number>(n).fill(0);

  const pistasUtiles = Math.min(pistas, Math.floor(n / 4));
  const cupo = pistasUtiles * 4;

  const salida: number[][][] = [];
  const descansos: number[][] = [];

  for (let r = 0; r < rondas; r++) {
    // Juegan los que menos han jugado; a igualdad, decide el azar. Así los
    // descansos van rotando solos sin llevar una lista aparte.
    const orden = barajar(
      Array.from({ length: n }, (_, i) => i),
      azar,
    ).sort((a, b) => jugados[a] - jugados[b]);

    const juegan = orden.slice(0, cupo);
    descansos.push(orden.slice(cupo).sort((a, b) => a - b));

    const disponibles = barajar(juegan, azar);
    const partidos: number[][] = [];

    while (disponibles.length >= 4) {
      const a = disponibles.shift()!;

      // Compañero de A: el que menos veces haya jugado con él.
      const b = extraerMejor(disponibles, (x) => companero[a][x] * PESO_COMPANERO, azar);

      // Primer rival: el que menos haya coincidido contra A y contra B.
      const c = extraerMejor(
        disponibles,
        (x) => (rival[a][x] + rival[b][x]) * PESO_RIVAL,
        azar,
      );

      // Compañero de C: pesa repetir pareja con C y repetir rivalidad con A y B.
      const d = extraerMejor(
        disponibles,
        (x) =>
          companero[c][x] * PESO_COMPANERO + (rival[a][x] + rival[b][x]) * PESO_RIVAL,
        azar,
      );

      partidos.push([a, b, c, d]);
    }

    for (const [a, b, c, d] of partidos) {
      anotarPareja(companero, a, b);
      anotarPareja(companero, c, d);
      for (const x of [a, b]) {
        for (const y of [c, d]) anotarPareja(rival, x, y);
      }
      for (const p of [a, b, c, d]) jugados[p]++;
    }

    salida.push(partidos);
  }

  return {
    rondas: salida,
    descansos,
    coste: calcularCoste(companero, rival, jugados),
    companero,
    rival,
    jugados,
  };
}

/** Saca de `pool` el elemento de menor coste y lo devuelve. */
function extraerMejor(
  pool: number[],
  coste: (x: number) => number,
  azar: () => number,
): number {
  let mejor = 0;
  let mejorCoste = Infinity;

  for (let i = 0; i < pool.length; i++) {
    // El desempate aleatorio es lo que hace que cada intento explore algo
    // distinto; sin él, todas las semillas darían lo mismo.
    const c = coste(pool[i]) + azar() * 0.001;
    if (c < mejorCoste) {
      mejorCoste = c;
      mejor = i;
    }
  }

  return pool.splice(mejor, 1)[0];
}

function anotarPareja(matriz: number[][], i: number, j: number) {
  matriz[i][j]++;
  matriz[j][i]++;
}

function repeticiones(matriz: number[][]): number {
  let total = 0;
  for (let i = 0; i < matriz.length; i++) {
    for (let j = i + 1; j < matriz.length; j++) {
      if (matriz[i][j] > 1) total += matriz[i][j] - 1;
    }
  }
  return total;
}

function calcularCoste(
  companero: number[][],
  rival: number[][],
  jugados: number[],
): number {
  const desequilibrio = Math.max(...jugados) - Math.min(...jugados);
  return (
    repeticiones(companero) * PESO_COMPANERO +
    repeticiones(rival) * PESO_RIVAL +
    desequilibrio * 100 // que todos jueguen lo mismo manda sobre lo demás
  );
}

export function generarAmericano(opciones: OpcionesAmericano): Cuadro {
  const { jugadores, pistas, rondas, semilla = 1, intentos = 200 } = opciones;

  if (jugadores.length < 4) {
    throw new Error("Hacen falta al menos 4 jugadores para un americano.");
  }
  if (new Set(jugadores).size !== jugadores.length) {
    throw new Error("Hay jugadores repetidos en la lista.");
  }
  if (pistas < 1) throw new Error("Hace falta al menos una pista.");
  if (rondas < 1) throw new Error("Hace falta al menos una ronda.");

  const n = jugadores.length;
  let mejor: Construccion | null = null;

  for (let intento = 0; intento < Math.max(1, intentos); intento++) {
    const candidato = construir(n, pistas, rondas, crearAzar(semilla + intento * 7919));
    if (!mejor || candidato.coste < mejor.coste) {
      mejor = candidato;
      if (mejor.coste === 0) break; // no se puede mejorar
    }
  }

  const elegido = mejor!;
  const descansosPorJugador = new Array<number>(n).fill(0);
  for (const ronda of elegido.descansos) {
    for (const p of ronda) descansosPorJugador[p]++;
  }

  return {
    semilla,
    rondas: elegido.rondas.map((partidos, i) => ({
      numero: i + 1,
      partidos: partidos.map(([a, b, c, d], pista) => ({
        pista: pista + 1,
        equipoA: [jugadores[a], jugadores[b]] as [string, string],
        equipoB: [jugadores[c], jugadores[d]] as [string, string],
      })),
      descansan: elegido.descansos[i].map((p) => jugadores[p]),
    })),
    calidad: {
      companerosRepetidos: repeticiones(elegido.companero),
      rivalesRepetidos: repeticiones(elegido.rival),
      partidosPorJugador: {
        min: Math.min(...elegido.jugados),
        max: Math.max(...elegido.jugados),
      },
      descansosPorJugador: {
        min: Math.min(...descansosPorJugador),
        max: Math.max(...descansosPorJugador),
      },
    },
  };
}
