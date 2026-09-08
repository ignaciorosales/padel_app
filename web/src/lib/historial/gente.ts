/**
 * Con quién y contra quién.
 *
 * En pádel juegas siempre con las mismas personas, y eso es lo que la gente
 * comparte: "con Javi vamos 10-4", "a Tincho le gané 7 de 11". Es la parte del
 * historial que sale del club y llega al grupo de WhatsApp, así que es la que
 * tiene que estar bien.
 *
 * A diferencia del récord oficial, **aquí sí cuentan los amistosos**: si no dan
 * nivel, tienen que dar algo, y esto es lo que dan. Quien llame decide qué
 * partidos pasa.
 *
 * Un americano regala estos datos: al rotar compañero cada ronda, una sola
 * mañana deja ocho parejas distintas y veinticuatro cruces.
 */

import {
  partidosDe,
  totalesDe,
  type JugadorId,
  type Partido,
  type Resultado,
  type Totales,
  type Vista,
} from "./partidos.ts";

export type FilaGente = {
  jugadorId: JugadorId;
  totales: Totales;
};

function agrupar(
  vistas: readonly Vista[],
  conQuien: (v: Vista) => JugadorId[],
): FilaGente[] {
  const porJugador = new Map<JugadorId, Vista[]>();

  for (const v of vistas) {
    for (const id of conQuien(v)) {
      const suyas = porJugador.get(id);
      if (suyas) suyas.push(v);
      else porJugador.set(id, [v]);
    }
  }

  return [...porJugador.entries()]
    .map(([jugadorId, suyas]) => ({ jugadorId, totales: totalesDe(suyas) }))
    .sort(
      (x, y) =>
        y.totales.partidos - x.totales.partidos ||
        y.totales.ganados - x.totales.ganados ||
        x.jugadorId.localeCompare(y.jugadorId),
    );
}

/** Con quién ha jugado, de más veces a menos. */
export function companeros(
  jugador: JugadorId,
  partidos: readonly Partido[],
): FilaGente[] {
  return agrupar(partidosDe(jugador, partidos), (v) => [v.companero]);
}

/** Contra quién ha jugado, de más veces a menos. */
export function rivales(
  jugador: JugadorId,
  partidos: readonly Partido[],
): FilaGente[] {
  return agrupar(partidosDe(jugador, partidos), (v) => [...v.rivales]);
}

// ------------------------------------------------------------ cara a cara

export type CaraACara = {
  /** Enfrentados: es el dato que se enseña primero. */
  contra: Totales;
  /** Y las veces que jugaron juntos, que también cuentan la historia. */
  juntos: Totales;
  /** Los últimos enfrentamientos, del más nuevo al más antiguo. */
  ultimos: Resultado[];
};

export function caraACara(
  jugador: JugadorId,
  otro: JugadorId,
  partidos: readonly Partido[],
  cuantosUltimos = 5,
): CaraACara {
  const vistas = partidosDe(jugador, partidos);
  const enfrentados = vistas.filter((v) => v.rivales.includes(otro));
  const juntos = vistas.filter((v) => v.companero === otro);

  return {
    contra: totalesDe(enfrentados),
    juntos: totalesDe(juntos),
    ultimos: enfrentados
      .slice(-cuantosUltimos)
      .reverse()
      .map((v) => v.resultado),
  };
}

// ------------------------------------------------------------- destacados

/**
 * Partidos mínimos para que alguien pueda ser tu mejor compañero o tu némesis.
 *
 * Sin un mínimo, el mejor compañero de todo el mundo es aquel con quien jugó una
 * vez y ganó. Es la forma más rápida de que una estadística deje de creerse.
 */
export const MINIMO_PARA_DESTACAR = 4;

/**
 * Cuánto tira la media propia de un porcentaje con pocos partidos.
 *
 * Con k = 3, jugar cuatro veces y ganar las cuatro no da un 100 %: da algo alto
 * pero prudente, y quien lleve veinte partidos le pasa por delante. Es la misma
 * idea que "provisional" en el nivel: un número con poca base se enseña, pero no
 * manda.
 */
const SUAVIZADO = 3;

function tasaSuavizada(fila: FilaGente, media: number): number {
  return (fila.totales.ganados + SUAVIZADO * media) / (fila.totales.partidos + SUAVIZADO);
}

export type Destacado = {
  jugadorId: JugadorId;
  totales: Totales;
  /** El porcentaje ya suavizado, que es por el que se ordena. */
  tasa: number;
};

export type Destacados = {
  /** Con quien mejor le va, por encima de su propia media. */
  mejorCompanero: Destacado | null;
  /** Quien mejor se le da a él, o sea: contra quien peor le va. */
  nemesis: Destacado | null;
};

/**
 * Las dos tarjetas del perfil.
 *
 * Devuelve null cuando nadie llega al mínimo, y eso está bien: una ficha nueva
 * no tiene némesis, y decir que sí la tiene es peor que dejar el hueco.
 */
export function destacados(
  jugador: JugadorId,
  partidos: readonly Partido[],
  minimo: number = MINIMO_PARA_DESTACAR,
): Destacados {
  const vistas = partidosDe(jugador, partidos);
  const propia = totalesDe(vistas).porcentaje;

  const elegir = (
    filas: readonly FilaGente[],
    mejor: (candidata: number, actual: number) => boolean,
  ): Destacado | null => {
    let elegido: Destacado | null = null;
    for (const fila of filas) {
      if (fila.totales.partidos < minimo) continue;
      const tasa = tasaSuavizada(fila, propia);
      if (elegido === null || mejor(tasa, elegido.tasa)) {
        elegido = { jugadorId: fila.jugadorId, totales: fila.totales, tasa };
      }
    }
    return elegido;
  };

  return {
    mejorCompanero: elegir(companeros(jugador, partidos), (c, a) => c > a),
    nemesis: elegir(rivales(jugador, partidos), (c, a) => c < a),
  };
}
