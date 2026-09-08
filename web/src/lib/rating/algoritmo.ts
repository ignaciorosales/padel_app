/**
 * Puntazo Rating · algoritmo v1 (Elo de parejas).
 *
 * El rating es del **jugador**, nunca del club: quien tiene 1650 lo tiene juegue
 * donde juegue, y los clubes sólo agrupan para hacer rankings locales. Cuantos
 * más clubes y partidos hay en la red, más preciso se vuelve el número.
 *
 * Tres decisiones de producto que dan forma a la fórmula:
 *
 * 1. **Manda ganar o perder.** El marcador sólo modula, y poco (±15 %). Ganarle
 *    a una pareja fuerte importa mucho más que ganar por paliza a una floja, y
 *    un sistema que premia las palizas premia jugar contra quien no debe.
 *
 * 2. **Ganar nunca baja el rating, y sale gratis.** Con `S` de 1 ó 0, el
 *    esperado siempre es menor que 1, así que el ganador siempre suma y el
 *    perdedor siempre resta. No hace falta ningún suelo artificial — y sin
 *    suelo, lo que gana un lado es exactamente lo que pierde el otro y el
 *    rating medio de la red no se mueve.
 *
 * 3. **La incertidumbre decide la velocidad.** Un jugador nuevo tiene que
 *    llegar rápido a su sitio; uno asentado no puede bailar. Esa es toda la
 *    función de la desviación en v1 — un Glicko-2 la usará de verdad, y por eso
 *    se guarda desde ahora aunque v1 la aproveche poco.
 *
 * El algoritmo se versiona y cada transacción guarda con cuál se calculó, para
 * poder rehacer la historia entera cuando cambie.
 */

export const VERSION_ALGORITMO = "PuntazoRating-v1";

export type JugadorId = string;

/** De dónde viene el resultado. Decide si puntúa y cuánto se fía el sistema. */
export type OrigenDelPartido =
  | "sin_puntuar"
  | "confirmado"
  | "club"
  | "torneo"
  | "liga"
  | "marcador";

/**
 * Cuánto se fía el sistema de cada fuente.
 *
 * Un resultado que sale del marcador de la pista no admite discusión; uno que
 * han confirmado los cuatro jugadores, casi. Los números son configurables a
 * propósito: son una hipótesis hasta que haya datos.
 */
export const CONFIANZA_POR_ORIGEN: Record<OrigenDelPartido, number> = {
  sin_puntuar: 0,
  confirmado: 0.8,
  club: 0.9,
  torneo: 1,
  liga: 1,
  marcador: 1,
};

export function puntua(origen: OrigenDelPartido): boolean {
  return CONFIANZA_POR_ORIGEN[origen] > 0;
}

export type RatingJugador = {
  jugadorId: JugadorId;
  rating: number;
  /** Incertidumbre. Alta al empezar, baja según se juega. */
  desviacion: number;
  /** 0..1. Lo que se enseña como "Confidence: 87 %". */
  confianza: number;
  partidosPuntuados: number;
  /** ISO del último partido que le movió el rating. Null si nunca jugó. */
  ultimoPartido: string | null;
};

export type PartidoPuntuable = {
  id: string;
  fecha: string;
  origen: OrigenDelPartido;
  a: readonly [JugadorId, JugadorId];
  b: readonly [JugadorId, JugadorId];
  /** Juegos, puntos o sets: sólo se usa para saber quién ganó y por cuánto. */
  marcadorA: number;
  marcadorB: number;
};

export type Opciones = {
  /** Desviación de alguien de quien no se sabe nada. */
  desviacionInicial: number;
  /** Suelo: nunca se está completamente seguro. */
  desviacionMinima: number;
  /**
   * Cuánto se estrecha la incertidumbre con cada partido puntuado.
   *
   * Calibrado para que la confianza tarde en llegar arriba: con 0,97 son ~37 %
   * a los quince partidos, 60 % a los treinta y 97 % pasados los cien. Con un
   * decaimiento más agresivo todo el mundo llegaba al 100 % en dos meses de
   * americanos, y un sistema que dice estar seguro de todo no se cree.
   */
  decaimiento: number;
  /** K con la máxima incertidumbre y con la mínima. Entre medias, interpola. */
  kMaxima: number;
  kMinima: number;
  /** Partidos por debajo de los cuales el rating es provisional. */
  partidosProvisionales: number;
  /** Extremos del modificador por marcador. Ganar apretado vs. ganar 6-0. */
  modificadorMinimo: number;
  modificadorMaximo: number;
  /** Días sin jugar tras los cuales la incertidumbre empieza a crecer otra vez. */
  diasHastaOxidarse: number;
};

export const OPCIONES: Opciones = {
  desviacionInicial: 350,
  desviacionMinima: 50,
  decaimiento: 0.97,
  kMaxima: 80,
  kMinima: 16,
  partidosProvisionales: 15,
  modificadorMinimo: 0.85,
  modificadorMaximo: 1.15,
  diasHastaOxidarse: 120,
};

/** Un jugador del que no se sabe nada más que la división que dice tener. */
export function ratingNuevo(
  jugadorId: JugadorId,
  ratingInicial: number,
  opciones: Opciones = OPCIONES,
): RatingJugador {
  return {
    jugadorId,
    rating: ratingInicial,
    desviacion: opciones.desviacionInicial,
    confianza: 0,
    partidosPuntuados: 0,
    ultimoPartido: null,
  };
}

/** Probabilidad de que gane la primera pareja. */
export function probabilidadEsperada(ratingA: number, ratingB: number): number {
  return 1 / (1 + 10 ** ((ratingB - ratingA) / 400));
}

/** La fuerza de una pareja: la media de los dos. */
export function ratingDePareja(uno: number, otro: number): number {
  return (uno + otro) / 2;
}

/**
 * Cuánto modula el marcador, entre 0,85 y 1,15.
 *
 * Un 6-5 vale 0,85; un 6-0, 1,15. El mismo número para los dos lados, para que
 * lo que gana uno lo siga perdiendo el otro exactamente.
 */
export function modificadorPorMarcador(
  marcadorA: number,
  marcadorB: number,
  opciones: Opciones = OPCIONES,
): number {
  const total = marcadorA + marcadorB;
  if (total <= 0) return 1;

  const dominio = Math.abs(marcadorA - marcadorB) / total;
  return (
    opciones.modificadorMinimo +
    (opciones.modificadorMaximo - opciones.modificadorMinimo) * dominio
  );
}

/** Cuánto se mueve un jugador: mucho si se sabe poco de él, poco si está asentado. */
export function kDe(rating: RatingJugador, opciones: Opciones = OPCIONES): number {
  const recorrido = opciones.desviacionInicial - opciones.desviacionMinima;
  const cuanta = Math.min(
    1,
    Math.max(0, (rating.desviacion - opciones.desviacionMinima) / recorrido),
  );
  return opciones.kMinima + (opciones.kMaxima - opciones.kMinima) * cuanta;
}

/** 0 recién llegado, cerca de 1 cuando el número ya se sostiene. */
export function confianzaDe(desviacion: number, opciones: Opciones = OPCIONES): number {
  const recorrido = opciones.desviacionInicial - opciones.desviacionMinima;
  const restante = (desviacion - opciones.desviacionMinima) / recorrido;
  return Math.min(1, Math.max(0, 1 - restante));
}

export function esProvisional(
  rating: RatingJugador,
  opciones: Opciones = OPCIONES,
): boolean {
  return rating.partidosPuntuados < opciones.partidosProvisionales;
}

/**
 * La incertidumbre crece con el tiempo parado.
 *
 * Quien lleva medio año sin jugar puede haber mejorado o haberse oxidado, y el
 * sistema no tiene forma de saberlo: lo honesto es admitir que sabe menos, no
 * bajarle el rating por no aparecer. Castigar la inactividad con puntos sería
 * empujar a jugar, que no es lo que este número mide.
 */
export function oxidar(
  rating: RatingJugador,
  hoy: string,
  opciones: Opciones = OPCIONES,
): RatingJugador {
  if (rating.ultimoPartido === null) return rating;

  const dias =
    (Date.parse(hoy) - Date.parse(rating.ultimoPartido)) / (1000 * 60 * 60 * 24);
  if (!Number.isFinite(dias) || dias <= opciones.diasHastaOxidarse) return rating;

  const periodos = dias / opciones.diasHastaOxidarse;
  const desviacion = Math.min(
    opciones.desviacionInicial,
    opciones.desviacionMinima +
      (rating.desviacion - opciones.desviacionMinima) * (1 + periodos),
  );

  return { ...rating, desviacion, confianza: confianzaDe(desviacion, opciones) };
}
