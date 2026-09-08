/**
 * El motor: de una lista de partidos a ratings, divisiones y auditoría.
 *
 * Dos reglas mandan sobre el diseño de este fichero:
 *
 * 1. **Nunca se toca un rating sin dejar escrito cómo se llegó a él.** Cada
 *    partido produce una transacción por jugador con el antes, el después, la
 *    probabilidad que se esperaba y contra quién. Sin eso, un rating es un
 *    número que nadie puede discutir ni arreglar.
 *
 * 2. **El rating se reconstruye, no se acumula.** Aquí entra el historial entero
 *    y sale el estado. Cambiar la fórmula no obliga a migrar nada: se vuelve a
 *    pasar. Por eso cada transacción guarda la versión del algoritmo con la que
 *    se calculó.
 *
 * Y una consecuencia práctica: **el mismo partido no puede puntuar dos veces.**
 * El motor ignora los identificadores repetidos, así que reprocesar de más es
 * inofensivo — que es lo que hace falta cuando el proceso se reintenta.
 */

import {
  confianzaDe,
  CONFIANZA_POR_ORIGEN,
  kDe,
  modificadorPorMarcador,
  OPCIONES,
  probabilidadEsperada,
  puntua,
  ratingDePareja,
  ratingNuevo,
  VERSION_ALGORITMO,
  type JugadorId,
  type Opciones,
  type PartidoPuntuable,
  type RatingJugador,
} from "./algoritmo.ts";
import {
  ESCALA_UY,
  estadoInicial,
  RATING_DESCONOCIDO,
  evaluarDivision,
  REGLAS,
  type CambioDeDivision,
  type EscalaDeDivisiones,
  type EstadoDeDivision,
  type ReglasDeDivision,
} from "./divisiones.ts";

/** El apunte contable de un cambio de rating. Nunca se borra. */
export type TransaccionDeRating = {
  partidoId: string;
  jugadorId: JugadorId;
  fecha: string;
  ratingAntes: number;
  ratingDespues: number;
  delta: number;
  /** Lo que el sistema esperaba que pasara, de 0 a 1. */
  probabilidadEsperada: number;
  /** Fuerza de la pareja rival, para poder explicar el ajuste. */
  ratingRivales: number;
  /** 1 ganó, 0,5 empató, 0 perdió. Es el `S` que entró en la fórmula. */
  resultado: number;
  version: string;
};

export type CambioDeDivisionRegistrado = CambioDeDivision & {
  jugadorId: JugadorId;
  fecha: string;
  partidoId: string;
};

export type MotivoIgnorado = "sin_puntuar" | "repetido" | "sin_marcador";

export type Estado = {
  ratings: Map<JugadorId, RatingJugador>;
  divisiones: Map<JugadorId, EstadoDeDivision>;
  transacciones: TransaccionDeRating[];
  historialDeDivision: CambioDeDivisionRegistrado[];
  ignorados: { partidoId: string; motivo: MotivoIgnorado }[];
};

export type EntradaDelMotor = {
  /** Ratings de partida, de la división que cada uno declaró al registrarse. */
  ratingsIniciales?: ReadonlyMap<JugadorId, number>;
  opciones?: Opciones;
  escala?: EscalaDeDivisiones;
  reglas?: ReglasDeDivision;
};

/**
 * Procesa el historial entero y devuelve el estado resultante.
 *
 * Los partidos se ordenan por fecha —y por id a igualdad, para que sea
 * reproducible— porque el orden cambia el resultado: no es lo mismo ganarle a
 * alguien antes o después de que ese alguien subiera.
 */
export function procesar(
  partidos: readonly PartidoPuntuable[],
  entrada: EntradaDelMotor = {},
): Estado {
  const opciones = entrada.opciones ?? OPCIONES;
  const escala = entrada.escala ?? ESCALA_UY;
  const reglas = entrada.reglas ?? REGLAS;
  const iniciales = entrada.ratingsIniciales ?? new Map<JugadorId, number>();

  const estado: Estado = {
    ratings: new Map(),
    divisiones: new Map(),
    transacciones: [],
    historialDeDivision: [],
    ignorados: [],
  };

  const yaProcesados = new Set<string>();

  const ratingDe = (id: JugadorId): RatingJugador => {
    let rating = estado.ratings.get(id);
    if (!rating) {
      // Quien no declaró división empieza en el centro de la escala, no en el
      // suelo: dar por hecho que alguien es de la última división es peor que
      // admitir que no se sabe.
      rating = ratingNuevo(id, iniciales.get(id) ?? RATING_DESCONOCIDO, opciones);
      estado.ratings.set(id, rating);
      estado.divisiones.set(id, estadoInicial(escala, rating.rating));
    }
    return rating;
  };

  const ordenados = [...partidos].sort(
    (x, y) => x.fecha.localeCompare(y.fecha) || x.id.localeCompare(y.id),
  );

  for (const partido of ordenados) {
    if (yaProcesados.has(partido.id)) {
      estado.ignorados.push({ partidoId: partido.id, motivo: "repetido" });
      continue;
    }
    if (!puntua(partido.origen)) {
      estado.ignorados.push({ partidoId: partido.id, motivo: "sin_puntuar" });
      continue;
    }
    if (partido.marcadorA + partido.marcadorB <= 0) {
      estado.ignorados.push({ partidoId: partido.id, motivo: "sin_marcador" });
      continue;
    }
    yaProcesados.add(partido.id);

    const ladoA = [ratingDe(partido.a[0]), ratingDe(partido.a[1])];
    const ladoB = [ratingDe(partido.b[0]), ratingDe(partido.b[1])];

    const parejaA = ratingDePareja(ladoA[0].rating, ladoA[1].rating);
    const parejaB = ratingDePareja(ladoB[0].rating, ladoB[1].rating);
    const esperadoA = probabilidadEsperada(parejaA, parejaB);

    // Manda ganar o perder. El marcador sólo modula, y poco.
    const realA =
      partido.marcadorA > partido.marcadorB
        ? 1
        : partido.marcadorA < partido.marcadorB
          ? 0
          : 0.5;

    const modificador = modificadorPorMarcador(
      partido.marcadorA,
      partido.marcadorB,
      opciones,
    );
    const fiabilidad = CONFIANZA_POR_ORIGEN[partido.origen];

    const aplicar = (
      jugadores: readonly JugadorId[],
      lado: RatingJugador[],
      real: number,
      esperado: number,
      rivales: number,
    ) => {
      jugadores.forEach((id, i) => {
        const antes = lado[i];
        const delta = kDe(antes, opciones) * modificador * fiabilidad * (real - esperado);
        const despues = antes.rating + delta;

        const desviacion = Math.max(
          opciones.desviacionMinima,
          opciones.desviacionMinima +
            (antes.desviacion - opciones.desviacionMinima) * opciones.decaimiento,
        );

        estado.ratings.set(id, {
          jugadorId: id,
          rating: despues,
          desviacion,
          confianza: confianzaDe(desviacion, opciones),
          partidosPuntuados: antes.partidosPuntuados + 1,
          ultimoPartido: partido.fecha,
        });

        estado.transacciones.push({
          partidoId: partido.id,
          jugadorId: id,
          fecha: partido.fecha,
          ratingAntes: antes.rating,
          ratingDespues: despues,
          delta,
          probabilidadEsperada: esperado,
          ratingRivales: rivales,
          resultado: real,
          version: VERSION_ALGORITMO,
        });

        // La división se evalúa después de mover el rating, y sólo con partidos
        // que puntúan: los partidos sin puntuar no ascienden ni descienden.
        const previo = estado.divisiones.get(id)!;
        const evaluado = evaluarDivision(previo, despues, escala, reglas);
        estado.divisiones.set(id, evaluado.estado);
        if (evaluado.cambio) {
          estado.historialDeDivision.push({
            ...evaluado.cambio,
            jugadorId: id,
            fecha: partido.fecha,
            partidoId: partido.id,
          });
        }
      });
    };

    aplicar(partido.a, ladoA, realA, esperadoA, parejaB);
    aplicar(partido.b, ladoB, 1 - realA, 1 - esperadoA, parejaA);
  }

  return estado;
}

// ------------------------------------------------------------- consultas

export type PuntoDelHistorial = {
  fecha: string;
  rating: number;
  delta: number;
  partidoId: string;
};

/** Para el gráfico de evolución del perfil. */
export function historialDeRating(
  estado: Estado,
  jugadorId: JugadorId,
): PuntoDelHistorial[] {
  return estado.transacciones
    .filter((t) => t.jugadorId === jugadorId)
    .map((t) => ({
      fecha: t.fecha,
      rating: t.ratingDespues,
      delta: t.delta,
      partidoId: t.partidoId,
    }));
}

export type ResumenDeRating = {
  actual: number;
  maximo: number;
  minimo: number;
  /** Cambio en los últimos N días, contra la fecha de referencia. */
  cambio: number;
};

/**
 * Los números del perfil: el de ahora, el techo histórico y cuánto se ha movido.
 *
 * `desde` se pasa en lugar de mirar el reloj para que sea determinista y se
 * pueda probar; quien llama decide si son 7, 30 o 90 días.
 */
export function resumenDeRating(
  estado: Estado,
  jugadorId: JugadorId,
  desde?: string,
): ResumenDeRating | null {
  const suyas = estado.transacciones.filter((t) => t.jugadorId === jugadorId);
  const rating = estado.ratings.get(jugadorId);
  if (!rating) return null;
  if (suyas.length === 0) {
    return { actual: rating.rating, maximo: rating.rating, minimo: rating.rating, cambio: 0 };
  }

  const recorridos = [suyas[0].ratingAntes, ...suyas.map((t) => t.ratingDespues)];
  const enVentana = desde === undefined ? suyas : suyas.filter((t) => t.fecha >= desde);

  return {
    actual: rating.rating,
    maximo: Math.max(...recorridos),
    minimo: Math.min(...recorridos),
    cambio: enVentana.reduce((total, t) => total + t.delta, 0),
  };
}

/** El último ascenso o descenso de un jugador, para el perfil. */
export function ultimoCambioDeDivision(
  estado: Estado,
  jugadorId: JugadorId,
): CambioDeDivisionRegistrado | null {
  const suyos = estado.historialDeDivision.filter((c) => c.jugadorId === jugadorId);
  return suyos.length === 0 ? null : suyos[suyos.length - 1];
}

// ------------------------------------------------- divisiones mal declaradas

/**
 * Quién parece estar en la división equivocada.
 *
 * Un rating que arranca lejos de la verdad tarda en llegar, y subir la `K` para
 * acelerarlo pondría a temblar el rating de todos los demás — que es peor que el
 * problema. La respuesta no es matemática, es de producto: **detectarlo y
 * preguntar.** Una división mal declarada es un dato de entrada equivocado, y el
 * club la corrige en un toque.
 *
 * Si alguien gana sistemáticamente más de lo que su rating predice, es que su
 * punto de partida está mal. Medido en simulación: un 2ª que se declara 6ª sale
 * el primero de veinticuatro **tras dos torneos**, y a los cuatro es el único
 * marcado de todo el club.
 */
export type Revision = {
  jugadorId: JugadorId;
  partidos: number;
  /** Media de `(S − E)`. Cerca de cero es que el rating encaja con lo que juega. */
  sesgo: number;
  veredicto: "encaja" | "parece_mas_fuerte" | "parece_mas_flojo";
};

/**
 * Cuántas desviaciones típicas tiene que desviarse alguien para preguntar.
 *
 * El umbral **no puede ser un número fijo**. Como el resultado es 1 ó 0, cada
 * partido se desvía mucho de lo esperado por pura suerte: con ocho partidos, el
 * error típico de la media ronda 0,18, así que un umbral fijo de 0,1 marcaría a
 * media plantilla. Escalándolo con la raíz del número de partidos, la tasa de
 * falsos positivos se queda donde se decide y no donde caiga.
 */
export const SIGMAS_SOSPECHOSAS = 2;

/** Error típico de la media de `(S − E)` con n partidos, con S de 1 ó 0. */
function errorTipico(partidos: number): number {
  return 0.5 / Math.sqrt(partidos);
}

export function revisarDivisionDeclarada(
  estado: Estado,
  minimoPartidos = 12,
  sigmas: number = SIGMAS_SOSPECHOSAS,
): Revision[] {
  const porJugador = new Map<JugadorId, number[]>();
  for (const t of estado.transacciones) {
    const desvio = t.resultado - t.probabilidadEsperada;
    const suyos = porJugador.get(t.jugadorId);
    if (suyos) suyos.push(desvio);
    else porJugador.set(t.jugadorId, [desvio]);
  }

  const revisiones: Revision[] = [];
  for (const [jugadorId, desvios] of porJugador) {
    if (desvios.length < minimoPartidos) continue;
    const sesgo = desvios.reduce((a, b) => a + b, 0) / desvios.length;
    const umbral = sigmas * errorTipico(desvios.length);
    revisiones.push({
      jugadorId,
      partidos: desvios.length,
      sesgo,
      veredicto:
        sesgo > umbral
          ? "parece_mas_fuerte"
          : sesgo < -umbral
            ? "parece_mas_flojo"
            : "encaja",
    });
  }

  return revisiones.sort((x, y) => Math.abs(y.sesgo) - Math.abs(x.sesgo));
}
