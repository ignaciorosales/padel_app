/**
 * Qué está pasando ahora mismo en un torneo.
 *
 * La página pública se abre veinticuatro veces a media mañana, casi siempre
 * desde el móvil y casi siempre con la misma pregunta: «¿voy yo ahora?». Con
 * seis rondas pintadas todas igual, esa pregunta se contesta leyendo la página
 * entera. Con la ronda que toca marcada, se contesta de un vistazo.
 *
 * TypeScript puro, sin base de datos ni React, como el resto de `lib/torneo`.
 */

export type EstadoRonda = {
  id: string;
  /** Partidos con resultado metido. */
  jugados: number;
  /** Partidos que tiene la ronda. */
  total: number;
};

export type RondaDestacada = {
  id: string;
  /**
   * `en juego` cuando ya hay algún resultado suyo, `siguiente` cuando todavía
   * no ha empezado. La diferencia importa: una dice «mira el marcador», la
   * otra dice «ve yendo a la pista».
   */
  marca: "en juego" | "siguiente";
};

/**
 * La ronda que toca: la primera que no está completa.
 *
 * Se mira en orden y se para en la primera con partidos sin resultado. Que una
 * ronda posterior tenga algún resultado suelto —pasa cuando cuatro que van
 * sobrados se adelantan— no la convierte en la ronda actual: la que manda es
 * la que el torneo está esperando.
 *
 * Devuelve `null` con el torneo entero jugado, sin rondas, o cuando todavía no
 * hay ningún partido: no hay nada que destacar y marcar la primera por marcar
 * algo sería mentir.
 */
export function rondaDestacada(rondas: EstadoRonda[]): RondaDestacada | null {
  for (const ronda of rondas) {
    if (ronda.total === 0) continue;
    if (ronda.jugados >= ronda.total) continue;

    return { id: ronda.id, marca: ronda.jugados > 0 ? "en juego" : "siguiente" };
  }

  return null;
}

/**
 * El porcentaje jugado, redondeado, para la barra de la cabecera.
 *
 * Nunca devuelve 0 habiendo empezado ni 100 sin terminar: una barra vacía con
 * un partido metido, o llena con uno por jugar, contradice al número que tiene
 * al lado y eso desmonta la confianza en toda la página.
 */
export function porcentajeJugado(jugados: number, total: number): number {
  if (total <= 0 || jugados <= 0) return 0;
  if (jugados >= total) return 100;

  return Math.min(99, Math.max(1, Math.round((jugados / total) * 100)));
}
