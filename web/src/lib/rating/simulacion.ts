/**
 * Banco de pruebas del nivel: jugadores con fuerza real, americanos de verdad.
 *
 * Los tests del motor comprueban la mecánica —ganar sube, el marcador modula
 * poco— pero no responden a la única pregunta que importa:
 * **¿el número que sale se parece a lo bueno que es el jugador?** Eso no se
 * opina, y no hace falta esperar a tener clubes para medirlo.
 *
 * Aquí se le da a cada jugador una fuerza oculta, se generan americanos con el
 * mismo generador que usa el panel, se simulan los marcadores y se compara lo
 * estimado con lo real. Sirve para tres cosas:
 *
 * 1. Saber a partir de cuántos partidos el orden es de fiar (el umbral de
 *    "provisional" es hoy un número puesto a mano).
 * 2. Medir si la escala se comprime o se ensancha, que decide el ancho de las
 *    bandas de división.
 * 3. Ver si el rating medio de la red se mueve con el tiempo. Debería quedarse
 *    quieto: lo que gana una pareja lo pierde la otra.
 *
 * **Lo que esto NO prueba** es que el pádel de verdad se comporte como un Elo.
 * El modelo de aquí es una hipótesis razonable, no el mundo. Lo que se está
 * probando es la maquinaria: la K, la incertidumbre y el rating de partida.
 */

import { generarAmericano } from "../torneo/americano.ts";
import type { JugadorId, PartidoPuntuable } from "./algoritmo.ts";
import { procesar } from "./motor.ts";

export type JugadorSimulado = {
  id: JugadorId;
  /** Lo bueno que es de verdad, en la misma escala que el Elo. */
  fuerza: number;
};

/**
 * Ancho de la escala **por punto**, no por partido.
 *
 * Un partido lo gana el mejor mucho más a menudo de lo que gana cada punto: en
 * pádel un favorito claro gana 6-4, no 6-0. Con 1150 aquí, una diferencia de 150
 * —una categoría— da el 57 % de los puntos y alrededor del 70 % de los partidos
 * a 24 puntos, que es lo que significa esa diferencia en la escala del Elo.
 */
export const ESCALA_POR_PUNTO = 1150;

export function probabilidadDePunto(fuerzaA: number, fuerzaB: number): number {
  return 1 / (1 + 10 ** ((fuerzaB - fuerzaA) / ESCALA_POR_PUNTO));
}

/** Mulberry32: pequeño, reproducible y suficiente. El mismo que el generador de rondas. */
export function crearAzar(semilla: number): () => number {
  let estado = semilla >>> 0;
  return function siguiente() {
    estado = (estado + 0x6d2b79f5) >>> 0;
    let t = estado;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Juega `tope` puntos y reparte el marcador. Así se juega un americano a puntos. */
export function simularMarcador(
  fuerzaA: number,
  fuerzaB: number,
  tope: number,
  azar: () => number,
): [number, number] {
  const p = probabilidadDePunto(fuerzaA, fuerzaB);
  let a = 0;
  for (let i = 0; i < tope; i++) if (azar() < p) a++;
  return [a, tope - a];
}

export type OpcionesTemporada = {
  jugadores: readonly JugadorSimulado[];
  /** Cuántos americanos se juegan. */
  torneos: number;
  rondas: number;
  pistas: number;
  /** Puntos por partido. 24 es lo habitual en un americano. */
  tope?: number;
  semilla?: number;
};

/**
 * Una temporada entera de americanos, en el orden en que se jugarían.
 *
 * Las rondas salen del generador real: mismas restricciones, mismos descansos y
 * mismas repeticiones de compañero que tendría el club.
 */
export function simularTemporada(opciones: OpcionesTemporada): PartidoPuntuable[] {
  const { jugadores, torneos, rondas, pistas } = opciones;
  const tope = opciones.tope ?? 24;
  const azar = crearAzar(opciones.semilla ?? 1);
  const fuerza = new Map(jugadores.map((j) => [j.id, j.fuerza]));
  const ids = jugadores.map((j) => j.id);

  const partidos: PartidoPuntuable[] = [];
  // Un torneo por semana, para que las fechas ordenen como se jugó.
  const fechaDe = (t: number, ronda: number) =>
    new Date(Date.UTC(2026, 0, 4 + t * 7, ronda)).toISOString().slice(0, 10);

  for (let t = 0; t < torneos; t++) {
    const cuadro = generarAmericano({
      jugadores: ids,
      pistas,
      rondas,
      semilla: t + 1,
      intentos: 40,
    });

    for (const ronda of cuadro.rondas) {
      for (const partido of ronda.partidos) {
        const [a1, a2] = partido.equipoA;
        const [b1, b2] = partido.equipoB;
        const [marcadorA, marcadorB] = simularMarcador(
          (fuerza.get(a1)! + fuerza.get(a2)!) / 2,
          (fuerza.get(b1)! + fuerza.get(b2)!) / 2,
          tope,
          azar,
        );

        partidos.push({
          id: `t${t}-r${ronda.numero}-p${partido.pista}`,
          fecha: fechaDe(t, ronda.numero),
          origen: "torneo",
          a: [a1, a2],
          b: [b1, b2],
          marcadorA,
          marcadorB,
        });
      }
    }
  }

  return partidos;
}

// -------------------------------------------------------------------- medir

/** Correlación de orden (Spearman): 1 es el orden perfecto, 0 es ruido. */
export function correlacionDeOrden(
  reales: readonly number[],
  estimados: readonly number[],
): number {
  const n = reales.length;
  if (n < 2) return 0;

  const puestos = (valores: readonly number[]): number[] => {
    const orden = valores.map((v, i) => ({ v, i })).sort((x, y) => x.v - y.v);
    const salida = new Array<number>(n);
    // Los empates comparten el puesto medio, como en una clasificación.
    let i = 0;
    while (i < n) {
      let j = i;
      while (j + 1 < n && orden[j + 1].v === orden[i].v) j++;
      const medio = (i + j) / 2 + 1;
      for (let k = i; k <= j; k++) salida[orden[k].i] = medio;
      i = j + 1;
    }
    return salida;
  };

  const a = puestos(reales);
  const b = puestos(estimados);
  const media = (n + 1) / 2;
  let arriba = 0;
  let ladoA = 0;
  let ladoB = 0;
  for (let i = 0; i < n; i++) {
    const da = a[i] - media;
    const db = b[i] - media;
    arriba += da * db;
    ladoA += da * da;
    ladoB += db * db;
  }
  return ladoA === 0 || ladoB === 0 ? 0 : arriba / Math.sqrt(ladoA * ladoB);
}

/**
 * Cuánto se estira o se encoge la escala estimada respecto de la real.
 *
 * Es la pendiente de la recta que las relaciona. Por debajo de 1 el sistema
 * **comprime**: dos jugadores separados por 150 puntos de verdad acaban más
 * juntos en la tabla, y entonces las bandas de categoría —que están definidas en
 * puntos de Elo— son demasiado anchas y todo el mundo cae en las de en medio.
 */
export function compresionDeEscala(
  reales: readonly number[],
  estimados: readonly number[],
): number {
  const n = reales.length;
  const mediaR = reales.reduce((x, y) => x + y, 0) / n;
  const mediaE = estimados.reduce((x, y) => x + y, 0) / n;
  let arriba = 0;
  let abajo = 0;
  for (let i = 0; i < n; i++) {
    arriba += (reales[i] - mediaR) * (estimados[i] - mediaE);
    abajo += (reales[i] - mediaR) ** 2;
  }
  return abajo === 0 ? 0 : arriba / abajo;
}

export function media(valores: readonly number[]): number {
  return valores.reduce((x, y) => x + y, 0) / valores.length;
}

export type Medida = {
  /** 1 = el orden de la tabla es exactamente el orden real. */
  orden: number;
  /** <1 = la escala estimada está comprimida. */
  compresion: number;
  /** Rating medio del grupo. Comparado con el de partida, dice si se infla. */
  nivelMedio: number;
  partidosPorJugador: number;
};

/** Corre una temporada y devuelve las cuatro medidas que importan. */
export function medirTemporada(
  opciones: OpcionesTemporada,
  semillas?: ReadonlyMap<JugadorId, number>,
): Medida {
  const partidos = simularTemporada(opciones);
  const { ratings: niveles } = procesar(partidos, { ratingsIniciales: semillas });

  const reales: number[] = [];
  const estimados: number[] = [];
  let jugados = 0;

  for (const jugador of opciones.jugadores) {
    const nivel = niveles.get(jugador.id);
    if (!nivel) continue;
    reales.push(jugador.fuerza);
    estimados.push(nivel.rating);
    jugados += nivel.partidosPuntuados;
  }

  return {
    orden: correlacionDeOrden(reales, estimados),
    compresion: compresionDeEscala(reales, estimados),
    nivelMedio: media(estimados),
    partidosPorJugador: jugados / reales.length,
  };
}

/**
 * Un club: jugadores repartidos por las categorías, con su fuerza real.
 *
 * `separacion` es la distancia real entre categorías contiguas. 150 es la
 * hipótesis que hay hoy en `categorias.ts`.
 */
export function crearClub(
  prefijo: string,
  porCategoria: number,
  categorias: number,
  centro = 1600,
  separacion = 150,
): JugadorSimulado[] {
  const jugadores: JugadorSimulado[] = [];
  const azar = crearAzar(prefijo.length * 977 + categorias);

  for (let c = 0; c < categorias; c++) {
    for (let i = 0; i < porCategoria; i++) {
      jugadores.push({
        id: `${prefijo}-${c}-${i}`,
        // Dentro de una categoría la gente no es idéntica: se reparte alrededor.
        fuerza: centro + (c - (categorias - 1) / 2) * separacion + (azar() - 0.5) * separacion * 0.6,
      });
    }
  }

  return jugadores;
}
