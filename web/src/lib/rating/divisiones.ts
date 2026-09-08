/**
 * Divisiones: la traducción del Puntazo Rating a como se habla en la pista.
 *
 * Dos conceptos, y no son el mismo:
 *
 * - **Rating** es dónde está exactamente el jugador. Es la fuente de verdad.
 * - **División** es dónde está, dicho de forma que se entienda sin explicar
 *   nada. Un 1608 y un 1732 son los dos terceras, pero el segundo está a punto
 *   de subir.
 *
 * Los rangos y los ratings de partida son **datos, no código**: cambian por país
 * y se van a recalibrar en cuanto haya partidos reales. La escala de aquí es la
 * uruguaya de ocho divisiones; añadir otra es añadir un objeto.
 *
 * La división **no puede bailar** alrededor del límite. Un jugador que es tercera
 * el sábado, cuarta el domingo y tercera otra vez el martes deja de creerse el
 * sistema entero, y con él el rating. De ahí la histéresis: para subir hay que
 * cruzar el umbral **y sostenerlo**; para bajar hay que caer bastante por debajo
 * **y sostenerlo también**.
 */

export type Division = {
  /** Como se dice: "3ª". */
  nombre: string;
  /** Suelo de la división. La más baja no tiene suelo real. */
  desde: number;
  /** Rating de partida de quien declara esta división al registrarse. */
  ratingInicial: number;
};

export type EscalaDeDivisiones = {
  /** Identifica la calibración, para poder cambiarla sin perder el historial. */
  id: string;
  /** De menor a mayor. */
  divisiones: Division[];
};

/** Uruguay: ocho divisiones, de 8ª a 1ª. Bandas de 150 puntos. */
export const ESCALA_UY: EscalaDeDivisiones = {
  id: "uy-v1",
  divisiones: [
    { nombre: "8ª", desde: 0, ratingInicial: 950 },
    { nombre: "7ª", desde: 1000, ratingInicial: 1075 },
    { nombre: "6ª", desde: 1150, ratingInicial: 1225 },
    { nombre: "5ª", desde: 1300, ratingInicial: 1375 },
    { nombre: "4ª", desde: 1450, ratingInicial: 1525 },
    { nombre: "3ª", desde: 1600, ratingInicial: 1675 },
    { nombre: "2ª", desde: 1750, ratingInicial: 1825 },
    { nombre: "1ª", desde: 1900, ratingInicial: 1975 },
  ],
};

/** Rating de quien no sabe o no dice su división. El centro de la escala. */
export const RATING_DESCONOCIDO = 1375;

export type ReglasDeDivision = {
  /** Cuánto hay que caer por debajo del suelo propio para plantearse bajar. */
  margenDeDescenso: number;
  /** Partidos seguidos en zona de ascenso antes de subir de verdad. */
  partidosParaAscender: number;
  /** Partidos seguidos por debajo del margen antes de bajar. */
  partidosParaDescender: number;
};

export const REGLAS: ReglasDeDivision = {
  margenDeDescenso: 50,
  partidosParaAscender: 5,
  partidosParaDescender: 5,
};

// ------------------------------------------------------------------ consulta

/** La división que corresponde a un rating, sin mirar el pasado. */
export function divisionDe(escala: EscalaDeDivisiones, rating: number): Division {
  let actual = escala.divisiones[0];
  for (const division of escala.divisiones) {
    if (rating >= division.desde) actual = division;
  }
  return actual;
}

/** Rating de partida de quien declara su división al registrarse. */
export function ratingInicialDe(
  escala: EscalaDeDivisiones,
  nombre: string | null,
): number {
  if (nombre === null) return RATING_DESCONOCIDO;
  return (
    escala.divisiones.find((d) => d.nombre === nombre)?.ratingInicial ??
    RATING_DESCONOCIDO
  );
}

function indiceDe(escala: EscalaDeDivisiones, nombre: string): number {
  return escala.divisiones.findIndex((d) => d.nombre === nombre);
}

// --------------------------------------------------------------- histéresis

/**
 * Lo que hay que recordar entre partido y partido para decidir si alguien sube.
 *
 * Vive con el jugador, no con el partido: es la cuenta de cuántos partidos
 * seguidos lleva en zona de ascenso o de descenso.
 */
export type EstadoDeDivision = {
  division: string;
  partidosEnZonaDeAscenso: number;
  partidosEnZonaDeDescenso: number;
};

export type TipoDeCambio = "ascenso" | "descenso";

export type CambioDeDivision = {
  anterior: string;
  nueva: string;
  tipo: TipoDeCambio;
  ratingAlCambiar: number;
};

export function estadoInicial(
  escala: EscalaDeDivisiones,
  rating: number,
): EstadoDeDivision {
  return {
    division: divisionDe(escala, rating).nombre,
    partidosEnZonaDeAscenso: 0,
    partidosEnZonaDeDescenso: 0,
  };
}

/**
 * Un partido más: ¿cambia de división?
 *
 * Sube sólo tras `partidosParaAscender` partidos seguidos por encima del umbral;
 * un solo partido que le devuelva por debajo reinicia la cuenta. Igual para
 * bajar, y encima hay que caer `margenDeDescenso` por debajo del suelo propio:
 * rozar el límite desde arriba no descabalga a nadie.
 */
export function evaluarDivision(
  estado: EstadoDeDivision,
  rating: number,
  escala: EscalaDeDivisiones = ESCALA_UY,
  reglas: ReglasDeDivision = REGLAS,
): { estado: EstadoDeDivision; cambio: CambioDeDivision | null } {
  const indice = indiceDe(escala, estado.division);
  if (indice === -1) {
    // División de una escala que ya no existe: se recoloca sin ceremonia.
    return { estado: estadoInicial(escala, rating), cambio: null };
  }

  const actual = escala.divisiones[indice];
  const siguiente = escala.divisiones[indice + 1] ?? null;

  const enZonaDeAscenso = siguiente !== null && rating >= siguiente.desde;
  const enZonaDeDescenso = indice > 0 && rating < actual.desde - reglas.margenDeDescenso;

  const nuevo: EstadoDeDivision = {
    division: estado.division,
    partidosEnZonaDeAscenso: enZonaDeAscenso ? estado.partidosEnZonaDeAscenso + 1 : 0,
    partidosEnZonaDeDescenso: enZonaDeDescenso ? estado.partidosEnZonaDeDescenso + 1 : 0,
  };

  if (siguiente && nuevo.partidosEnZonaDeAscenso >= reglas.partidosParaAscender) {
    return {
      estado: {
        division: siguiente.nombre,
        partidosEnZonaDeAscenso: 0,
        partidosEnZonaDeDescenso: 0,
      },
      cambio: {
        anterior: actual.nombre,
        nueva: siguiente.nombre,
        tipo: "ascenso",
        ratingAlCambiar: rating,
      },
    };
  }

  if (indice > 0 && nuevo.partidosEnZonaDeDescenso >= reglas.partidosParaDescender) {
    const anterior = escala.divisiones[indice - 1];
    return {
      estado: {
        division: anterior.nombre,
        partidosEnZonaDeAscenso: 0,
        partidosEnZonaDeDescenso: 0,
      },
      cambio: {
        anterior: actual.nombre,
        nueva: anterior.nombre,
        tipo: "descenso",
        ratingAlCambiar: rating,
      },
    };
  }

  return { estado: nuevo, cambio: null };
}

// ----------------------------------------------------------------- progreso

export type ProgresoDeDivision = {
  division: Division;
  siguiente: Division | null;
  /** Puntos que faltan para el umbral de la siguiente. 0 en la más alta. */
  faltan: number;
  /** 0..1 dentro de la división, para la barra. */
  fraccion: number;
  /** True cuando ya está por encima del umbral y le faltan partidos. */
  enZonaDeAscenso: boolean;
  /** Partidos que le quedan por sostener. Null si no está en zona. */
  partidosParaConfirmar: number | null;
};

/**
 * Lo que se pinta en el perfil.
 *
 * "44 PR para 3ª" y "mantené 1600+ durante 3 partidos más" mueven a la gente;
 * "1556 de rating" no dice nada por sí solo.
 */
export function progresoDeDivision(
  estado: EstadoDeDivision,
  rating: number,
  escala: EscalaDeDivisiones = ESCALA_UY,
  reglas: ReglasDeDivision = REGLAS,
): ProgresoDeDivision {
  const indice = Math.max(0, indiceDe(escala, estado.division));
  const division = escala.divisiones[indice];
  const siguiente = escala.divisiones[indice + 1] ?? null;

  if (!siguiente) {
    return {
      division,
      siguiente: null,
      faltan: 0,
      fraccion: 1,
      enZonaDeAscenso: false,
      partidosParaConfirmar: null,
    };
  }

  const suelo =
    indice === 0 ? siguiente.desde - anchoTipico(escala) : division.desde;
  const enZona = rating >= siguiente.desde;

  return {
    division,
    siguiente,
    faltan: Math.max(0, Math.ceil(siguiente.desde - rating)),
    fraccion: Math.min(1, Math.max(0, (rating - suelo) / (siguiente.desde - suelo))),
    enZonaDeAscenso: enZona,
    partidosParaConfirmar: enZona
      ? Math.max(0, reglas.partidosParaAscender - estado.partidosEnZonaDeAscenso)
      : null,
  };
}

/** Ancho de banda más habitual; sirve para la división más baja, que no tiene suelo. */
function anchoTipico(escala: EscalaDeDivisiones): number {
  const anchos: number[] = [];
  for (let i = 1; i < escala.divisiones.length - 1; i++) {
    anchos.push(escala.divisiones[i + 1].desde - escala.divisiones[i].desde);
  }
  if (anchos.length === 0) return 150;
  anchos.sort((x, y) => x - y);
  return anchos[Math.floor(anchos.length / 2)];
}
