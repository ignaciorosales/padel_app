/**
 * El perfil de un jugador, montado de lo que ya está guardado.
 *
 * La diferencia con `rating/motor.ts` es de dónde saca los números y no es un
 * detalle: **el motor calcula, esto lee.** El perfil de una persona se abre
 * muchas veces al día y no puede reconstruir la red entera para pintar una barra
 * de progreso, así que trabaja sobre `player_ratings` y `rating_transactions` —
 * las filas que el servicio ya dejó escritas.
 *
 * De ahí sale la regla que gobierna el fichero: aquí no hay ninguna fórmula del
 * algoritmo. Si hiciera falta una, sería la segunda implementación de la misma
 * cosa y las dos acabarían discrepando sobre el mismo jugador. Lo que hay son
 * lecturas y derivados de lo escrito: el techo histórico, cuánto se ha movido en
 * los últimos treinta días, contra quién ha ganado lo más difícil.
 *
 * ## Lo que se enseña y lo que se guarda
 *
 * El rating se guarda sin redondear y **se enseña redondeado**. "1547" es un
 * número que la gente repite; "1546,8231" es un número que nadie se cree. El
 * redondeo vive aquí, en la capa que enseña, y nunca en la que guarda.
 *
 * Las fechas se pasan, no se leen del reloj: un perfil que depende de `Date.now()`
 * no se puede probar y da resultados distintos según a qué hora se abra.
 */

import {
  divisionDe,
  ESCALA_UY,
  progresoDeDivision,
  RATING_DESCONOCIDO,
  REGLAS,
  type EscalaDeDivisiones,
  type EstadoDeDivision,
  type ProgresoDeDivision,
  type ReglasDeDivision,
} from "../rating/divisiones.ts";
import {
  esProvisional,
  OPCIONES,
  type Opciones,
  type RatingJugador,
} from "../rating/algoritmo.ts";
import {
  porEvento,
  porMes,
  resumen,
  type Evento,
  type JugadorId,
  type Mes,
  type Partido,
  type Resumen,
} from "../historial/partidos.ts";
import {
  companeros,
  destacados,
  rivales,
  type Destacados,
  type FilaGente,
} from "../historial/gente.ts";

// ============================================================ lo que se lee

/** Una fila de `player_ratings`. */
export type FilaDeRating = {
  player_id: string;
  rating: number;
  desviacion: number;
  confianza: number;
  partidos_puntuados: number;
  ultimo_partido: string | null;
  escala: string;
  division: string;
  partidos_en_zona_de_ascenso: number;
  partidos_en_zona_de_descenso: number;
};

/** Una fila de `rating_transactions`. */
export type FilaDeTransaccion = {
  match_id: string | null;
  friendly_match_id: string | null;
  player_id: string;
  fecha: string;
  rating_antes: number;
  rating_despues: number;
  delta: number;
  probabilidad_esperada: number;
  rating_rivales: number;
  resultado: number;
};

/** Una fila de `player_division_history`. */
export type FilaDeCambioDeDivision = {
  player_id: string;
  fecha: string;
  anterior: string;
  nueva: string;
  tipo: string;
  rating_al_cambiar: number;
};

// ========================================================== lo que se enseña

export type PuntoDeEvolucion = {
  fecha: string;
  /** Sin redondear: el gráfico dibuja mejor con el número entero. */
  rating: number;
  delta: number;
  partidoId: string;
};

export type Pico = {
  rating: number;
  fecha: string;
};

export type Movimiento = {
  /** Días de la ventana. */
  dias: number;
  /** Suma de los deltas dentro de la ventana. Puede ser negativa. */
  cambio: number;
  partidos: number;
};

export type Victoria = {
  partidoId: string;
  fecha: string;
  /** Fuerza de la pareja a la que ganó. Es lo que hace grande una victoria. */
  ratingRivales: number;
  delta: number;
  /** Lo que el sistema le daba de probabilidad. Cuanto menor, más gesta. */
  probabilidadEsperada: number;
};

export type Perfil = {
  jugadorId: JugadorId;
  /** Redondeado, que es como se dice. */
  rating: number;
  /** 0..1. Se enseña como porcentaje. */
  confianza: number;
  /** Por debajo del umbral no sale en rankings, y hay que decirlo. */
  provisional: boolean;
  partidosPuntuados: number;
  ultimoPartido: string | null;

  division: string;
  progreso: ProgresoDeDivision;
  /** El último ascenso o descenso, para "subiste a 3ª en marzo". */
  ultimoCambio: FilaDeCambioDeDivision | null;
  cambiosDeDivision: FilaDeCambioDeDivision[];

  pico: Pico | null;
  /** Cambio a 7, 30 y 90 días, en ese orden. */
  movimientos: Movimiento[];
  evolucion: PuntoDeEvolucion[];
  mejoresVictorias: Victoria[];

  /** Del historial: victorias, derrotas, racha, partidos jugados. */
  resumen: Resumen;
  eventos: Evento[];
  meses: Mes[];
  /** Las dos tarjetas: con quien mejor le va y contra quien peor. */
  destacados: Destacados;
  /** Con quién ha jugado y contra quién, de más veces a menos. */
  companeros: FilaGente[];
  rivales: FilaGente[];
};

export type EntradaDelPerfil = {
  jugadorId: JugadorId;
  /** Null cuando la persona existe pero nunca ha puntuado nada. */
  rating: FilaDeRating | null;
  transacciones: readonly FilaDeTransaccion[];
  cambios: readonly FilaDeCambioDeDivision[];
  /** Su historial completo, amistosos sin confirmar incluidos. */
  partidos: readonly Partido[];
  /** ISO (`2026-09-08`). Se pasa para que el perfil sea determinista. */
  hoy: string;
  escala?: EscalaDeDivisiones;
  reglas?: ReglasDeDivision;
  opciones?: Opciones;
};

/** Las tres ventanas del perfil. Son las que la gente mira. */
export const VENTANAS = [7, 30, 90];

/** Redondeo de lo que se enseña. Nunca de lo que se guarda. */
export function comoSeDice(rating: number): number {
  return Math.round(rating);
}

function restarDias(iso: string, dias: number): string {
  const fecha = new Date(`${iso}T00:00:00Z`);
  fecha.setUTCDate(fecha.getUTCDate() - dias);
  return fecha.toISOString().slice(0, 10);
}

/**
 * Todo lo que el perfil enseña, de las cuatro consultas.
 *
 * Aguanta que falte todo: una persona recién creada no tiene fila en
 * `player_ratings` ni una sola transacción, y su perfil tiene que pintarse igual
 * —con el rating de partida de su división y la barra a cero— porque es
 * exactamente el estado en el que se abre la app por primera vez.
 */
export function perfilDe(entrada: EntradaDelPerfil): Perfil {
  const escala = entrada.escala ?? ESCALA_UY;
  const reglas = entrada.reglas ?? REGLAS;
  const opciones = entrada.opciones ?? OPCIONES;

  const suyas = [...entrada.transacciones]
    .filter((t) => t.player_id === entrada.jugadorId)
    // Por fecha, y a igualdad por el rating de antes: es el orden en que
    // ocurrieron, y es el que dibuja la línea del gráfico.
    .sort((x, y) => x.fecha.localeCompare(y.fecha) || x.rating_antes - y.rating_antes);

  const suyos = [...entrada.cambios]
    .filter((c) => c.player_id === entrada.jugadorId)
    .sort((x, y) => x.fecha.localeCompare(y.fecha));

  // El rating de la fila guardada; si no hay fila, el de su última transacción.
  const ratingCrudo =
    entrada.rating?.rating ??
    (suyas.length > 0 ? suyas[suyas.length - 1].rating_despues : null);

  // Quien no tiene ni fila ni transacciones está donde arranca quien no dice su
  // división: en el centro de la escala. No es un 1500 inventado, es el mismo
  // valor que usa el motor para lo mismo.
  const efectivo = ratingCrudo ?? RATING_DESCONOCIDO;

  // La división guardada manda sobre la que toca por rating, porque lleva dentro
  // la histéresis: quien está por encima del umbral pero le faltan partidos por
  // sostener sigue en la de abajo. Sólo se deduce del rating cuando no hay fila.
  const division = entrada.rating?.division ?? divisionDe(escala, efectivo).nombre;

  const estadoDeDivision: EstadoDeDivision = {
    division,
    partidosEnZonaDeAscenso: entrada.rating?.partidos_en_zona_de_ascenso ?? 0,
    partidosEnZonaDeDescenso: entrada.rating?.partidos_en_zona_de_descenso ?? 0,
  };

  const partidosPuntuados = entrada.rating?.partidos_puntuados ?? suyas.length;

  // Se construye el rating completo en vez de preguntar por el umbral a mano: el
  // umbral de provisionalidad es del algoritmo, y repetirlo aquí sería la segunda
  // copia de la misma regla.
  const comoRating: RatingJugador = {
    jugadorId: entrada.jugadorId,
    rating: efectivo,
    desviacion: entrada.rating?.desviacion ?? opciones.desviacionInicial,
    confianza: entrada.rating?.confianza ?? 0,
    partidosPuntuados,
    ultimoPartido: entrada.rating?.ultimo_partido ?? null,
  };

  const evolucion: PuntoDeEvolucion[] = suyas.map((t) => ({
    fecha: t.fecha,
    rating: t.rating_despues,
    delta: t.delta,
    partidoId: t.match_id ?? t.friendly_match_id ?? "",
  }));

  // El techo se busca en el recorrido completo, no sólo en los "después": si su
  // mejor momento fue el punto de partida, ése es el techo.
  let pico: Pico | null = null;
  if (suyas.length > 0) {
    pico = { rating: suyas[0].rating_antes, fecha: suyas[0].fecha };
    for (const t of suyas) {
      if (t.rating_despues > pico.rating) {
        pico = { rating: t.rating_despues, fecha: t.fecha };
      }
    }
  } else if (entrada.rating) {
    pico = { rating: entrada.rating.rating, fecha: entrada.rating.ultimo_partido ?? entrada.hoy };
  }

  const movimientos: Movimiento[] = VENTANAS.map((dias) => {
    const desde = restarDias(entrada.hoy, dias);
    const dentro = suyas.filter((t) => t.fecha >= desde);
    return {
      dias,
      cambio: dentro.reduce((total, t) => total + t.delta, 0),
      partidos: dentro.length,
    };
  });

  // Las mejores victorias se ordenan por la fuerza de los rivales, no por el
  // delta. Son casi lo mismo, pero no del todo: un delta grande también sale de
  // tener el rating desajustado, y "le ganaste a una pareja de 1780" es lo que
  // de verdad se cuenta.
  const mejoresVictorias: Victoria[] = suyas
    .filter((t) => t.resultado === 1)
    .sort(
      (x, y) =>
        y.rating_rivales - x.rating_rivales || x.probabilidad_esperada - y.probabilidad_esperada,
    )
    .slice(0, 5)
    .map((t) => ({
      partidoId: t.match_id ?? t.friendly_match_id ?? "",
      fecha: t.fecha,
      ratingRivales: t.rating_rivales,
      delta: t.delta,
      probabilidadEsperada: t.probabilidad_esperada,
    }));

  return {
    jugadorId: entrada.jugadorId,
    rating: comoSeDice(efectivo),
    confianza: entrada.rating?.confianza ?? 0,
    provisional: esProvisional(comoRating, opciones),
    partidosPuntuados,
    ultimoPartido: entrada.rating?.ultimo_partido ?? null,

    division,
    progreso: progresoDeDivision(estadoDeDivision, efectivo, escala, reglas),
    ultimoCambio: suyos.length > 0 ? suyos[suyos.length - 1] : null,
    cambiosDeDivision: suyos,

    pico,
    movimientos,
    evolucion,
    mejoresVictorias,

    resumen: resumen(entrada.jugadorId, entrada.partidos),
    eventos: porEvento(entrada.jugadorId, entrada.partidos),
    meses: porMes(entrada.jugadorId, entrada.partidos),
    destacados: destacados(entrada.jugadorId, entrada.partidos),
    companeros: companeros(entrada.jugadorId, entrada.partidos),
    rivales: rivales(entrada.jugadorId, entrada.partidos),
  };
}

// =============================================== la pantalla del después

export type Movida = {
  jugadorId: JugadorId;
  antes: number;
  despues: number;
  delta: number;
  /** El lado en que jugó, para poder pintarlos enfrentados. */
  gano: boolean;
};

export type DespuesDelPartido = {
  partidoId: string;
  fecha: string;
  /** Los cuatro, ganadores primero. */
  movidas: Movida[];
  /** Lo que el sistema esperaba del lado que ganó. Bajo = sorpresa. */
  probabilidadDelGanador: number;
};

/**
 * "1532 → 1547" para cada uno de los cuatro.
 *
 * Es la pantalla que se enseña al meter el resultado, y la que hace que el rating
 * signifique algo para quien juega: un número que sólo aparece en una tabla no se
 * mira, uno que se mueve delante de ti después de cada partido sí.
 *
 * Los ganadores primero, y con la probabilidad que se les daba: cuando es baja,
 * lo que hay que contar no es "+15" sino "les ganasteis a una pareja que os daba
 * por perdedores".
 */
export function despuesDelPartido(
  partidoId: string,
  transacciones: readonly FilaDeTransaccion[],
): DespuesDelPartido | null {
  const suyas = transacciones.filter(
    (t) => t.match_id === partidoId || t.friendly_match_id === partidoId,
  );
  if (suyas.length === 0) return null;

  const movidas: Movida[] = suyas
    .map((t) => ({
      jugadorId: t.player_id,
      antes: comoSeDice(t.rating_antes),
      despues: comoSeDice(t.rating_despues),
      delta: t.delta,
      gano: t.resultado === 1,
    }))
    // Ganadores primero; dentro de cada lado, el que más se movió.
    .sort((x, y) => Number(y.gano) - Number(x.gano) || y.delta - x.delta);

  const ganador = suyas.find((t) => t.resultado === 1) ?? suyas[0];

  return {
    partidoId,
    fecha: suyas[0].fecha,
    movidas,
    probabilidadDelGanador: ganador.probabilidad_esperada,
  };
}
