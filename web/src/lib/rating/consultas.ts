/**
 * De las filas de Supabase al motor, y del motor a lo que se guarda.
 *
 * Es la mitad pura del servicio: aquí no hay red ni cliente de base de datos,
 * sólo la traducción entre dos formas de decir lo mismo. Está separada de
 * `servicio.ts` por una razón práctica — esta parte es la que se equivoca, y es
 * la única que se puede probar sin una base de datos delante.
 *
 * Lo que manda en las dos direcciones:
 *
 * - **Hacia el motor**: nada se adivina. Una fila a la que le falta su ronda o
 *   su torneo no se completa con valores por defecto, se descarta con su motivo
 *   (mismo criterio que `jugador/desde-el-panel.ts`, y por eso se reutiliza).
 * - **Hacia la base de datos**: se guarda el número entero, sin redondear. El
 *   rating se enseña redondeado, pero se guarda como salió: cada reconstrucción
 *   parte de lo guardado, y redondear en cada pasada acumula error.
 */

import {
  divisionDe,
  ESCALA_UY,
  ratingInicialDe,
  type EscalaDeDivisiones,
} from "./divisiones.ts";
import type { Estado } from "./motor.ts";
import type { JugadorId } from "./algoritmo.ts";
import {
  identidadesDe,
  partidosDelPanel,
  soloPuntuables,
  type Descarte,
  type FilaDelPanel,
} from "../jugador/desde-el-panel.ts";
import type { PartidoPuntuable } from "./algoritmo.ts";

// ============================================================ filas que entran
// Nombres de columna tal cual salen de Postgres: snake_case y sin tocar. La
// traducción a camelCase se hace una vez, aquí, y no en cada consulta.

/** `matches`, con lo que el rating necesita. */
export type FilaDeMatch = {
  id: string;
  round_id: string;
  pista: number;
  a1: string | null;
  a2: string | null;
  b1: string | null;
  b2: string | null;
  juegos_a: number | null;
  juegos_b: number | null;
};

/** `rounds`. Sólo hace falta para saber de qué torneo es y en qué orden fue. */
export type FilaDeRonda = {
  id: string;
  tournament_id: string;
  numero: number;
};

/** `tournaments`. La fecha y la unidad del marcador son del torneo, no del partido. */
export type FilaDeTorneo = {
  id: string;
  fecha: string;
  formato: string;
  unidad_marcador: string;
};

/** `tournament_players`: el inscrito y a qué persona se unificó, si se unificó. */
export type FilaDeInscrito = {
  id: string;
  player_id: string | null;
};

/** `players`, sólo lo que el motor usa de entrada. */
export type FilaDeJugador = {
  id: string;
  division_declarada: string | null;
};

export type MotivoHuerfano = "sin_ronda" | "sin_torneo";

export type Huerfano = {
  filaId: string;
  motivo: MotivoHuerfano;
};

export type Entrada = {
  filas: FilaDelPanel[];
  /** Filas cuya ronda o torneo no vino en la consulta. No debería pasar nunca. */
  huerfanos: Huerfano[];
};

/**
 * Junta las tres tablas en las filas que come el resto de la cadena.
 *
 * El `join` se hace en memoria y no en SQL a propósito: el resto del panel lo
 * hace igual (`torneo/publico.ts`), y tres consultas por clave primaria son más
 * baratas y más predecibles que un `select` anidado que Supabase traduce a algo
 * que nadie lee.
 *
 * Un huérfano —partido cuya ronda no está— no puede ocurrir con las claves
 * ajenas puestas, pero puede ocurrir si alguien filtra mal la consulta. Sale
 * con su motivo en vez de desaparecer, que es la diferencia entre un aviso y un
 * ranking misteriosamente incompleto.
 */
export function entradaDelMotor(
  matches: readonly FilaDeMatch[],
  rondas: readonly FilaDeRonda[],
  torneos: readonly FilaDeTorneo[],
): Entrada {
  const rondaPor = new Map(rondas.map((r) => [r.id, r]));
  const torneoPor = new Map(torneos.map((t) => [t.id, t]));

  const filas: FilaDelPanel[] = [];
  const huerfanos: Huerfano[] = [];

  for (const match of matches) {
    const ronda = rondaPor.get(match.round_id);
    if (!ronda) {
      huerfanos.push({ filaId: match.id, motivo: "sin_ronda" });
      continue;
    }
    const torneo = torneoPor.get(ronda.tournament_id);
    if (!torneo) {
      huerfanos.push({ filaId: match.id, motivo: "sin_torneo" });
      continue;
    }

    filas.push({
      id: match.id,
      torneoId: torneo.id,
      fecha: torneo.fecha,
      formato: torneo.formato,
      unidad: torneo.unidad_marcador,
      ronda: ronda.numero,
      pista: match.pista,
      a1: match.a1,
      a2: match.a2,
      b1: match.b1,
      b2: match.b2,
      juegosA: match.juegos_a,
      juegosB: match.juegos_b,
    });
  }

  return { filas, huerfanos };
}

export type Puntuables = {
  partidos: PartidoPuntuable[];
  descartes: Descarte[];
  huerfanos: Huerfano[];
};

/**
 * El camino completo de filas a partidos que puntúan.
 *
 * Reutiliza `partidosDelPanel` en lugar de repetir sus reglas: si el rating
 * tuviera su propia idea de qué es un partido válido, tarde o temprano diría del
 * mismo partido algo distinto de lo que dice el historial.
 */
export function puntuablesDeLasFilas(
  matches: readonly FilaDeMatch[],
  rondas: readonly FilaDeRonda[],
  torneos: readonly FilaDeTorneo[],
  inscritos: readonly FilaDeInscrito[],
): Puntuables {
  const { filas, huerfanos } = entradaDelMotor(matches, rondas, torneos);
  const identidades = identidadesDe(
    inscritos.map((i) => ({ id: i.id, playerId: i.player_id })),
  );
  const { partidos, descartes } = partidosDelPanel(filas, identidades);
  return { partidos: soloPuntuables(partidos), descartes, huerfanos };
}

/**
 * El rating de partida de cada uno, de la división que declaró.
 *
 * Sólo entran los que declararon algo: el motor pone en el centro de la escala a
 * quien no está en el mapa, y decirlo dos veces sería una forma de que las dos
 * respuestas se separen.
 */
export function ratingsInicialesDe(
  jugadores: readonly FilaDeJugador[],
  escala: EscalaDeDivisiones = ESCALA_UY,
): Map<JugadorId, number> {
  const mapa = new Map<JugadorId, number>();
  for (const jugador of jugadores) {
    if (jugador.division_declarada === null) continue;
    mapa.set(jugador.id, ratingInicialDe(escala, jugador.division_declarada));
  }
  return mapa;
}

// =========================================================== filas que salen

/** Una fila de `player_ratings`, con los nombres de columna de Postgres. */
export type RatingParaGuardar = {
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
  version: string;
};

export type TransaccionParaGuardar = {
  /** Uno de los dos, nunca los dos: es la restricción `transaccion_de_un_solo_partido`. */
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
  version: string;
};

export type CambioParaGuardar = {
  player_id: string;
  match_id: string | null;
  friendly_match_id: string | null;
  fecha: string;
  escala: string;
  anterior: string;
  nueva: string;
  tipo: string;
  rating_al_cambiar: number;
};

export type Payload = {
  ratings: RatingParaGuardar[];
  transacciones: TransaccionParaGuardar[];
  divisiones: CambioParaGuardar[];
  /** Los partidos de torneo que de verdad movieron un rating. */
  partidos: string[];
  /** Lo mismo, para los amistosos. Van aparte porque son otra tabla. */
  amistosos: string[];
};

/**
 * El estado del motor, listo para `aplicar_rating`.
 *
 * Dos decisiones que no se ven en el tipo:
 *
 * **La división que se guarda es la del estado con histéresis, no la del rating
 * de hoy.** Son distintas a propósito: alguien con 1755 puede seguir siendo
 * tercera porque le faltan partidos por sostener. Guardar `divisionDe(rating)`
 * aquí sería ascender a todo el mundo en cuanto roza el umbral y tirar por la
 * ventana la mitad del diseño de las divisiones. La del rating sólo se usa como
 * red por si a alguien le falta el estado, que no debería pasar.
 *
 * **Sólo se marcan como procesados los partidos que produjeron una
 * transacción.** Los que el motor ignoró por no puntuar —un amistoso que
 * todavía nadie ha confirmado— siguen pendientes, y tienen que seguirlo: el día
 * que los cuatro lo confirmen hay que volver a mirarlos. Marcar todo lo que se
 * mira dejaría fuera para siempre a los que aún no podían puntuar.
 *
 * El tercer argumento es la lista de ids que son amistosos. El motor trabaja con
 * ids sueltos y no sabe —ni tiene por qué— de qué tabla salió cada uno; quien lo
 * sabe es el servicio, que hizo las dos consultas. Pasarlo aquí es más barato
 * que enseñarle al motor que existen dos clases de partido.
 */
export function paraGuardar(
  estado: Estado,
  escala: EscalaDeDivisiones = ESCALA_UY,
  amistosos: ReadonlySet<string> = new Set(),
): Payload {
  // Con qué versión se calculó el rating de cada uno: la de su última
  // transacción. No la constante del código, que es la versión de hoy — al
  // reprocesar por partes conviven filas de dos versiones, y saber cuáles se
  // quedaron atrás es justo para lo que sirve la columna.
  const versionPor = new Map<JugadorId, string>();
  for (const t of estado.transacciones) versionPor.set(t.jugadorId, t.version);

  const ratings: RatingParaGuardar[] = [];

  for (const [jugadorId, rating] of estado.ratings) {
    const division = estado.divisiones.get(jugadorId);
    ratings.push({
      player_id: jugadorId,
      rating: rating.rating,
      desviacion: rating.desviacion,
      confianza: rating.confianza,
      partidos_puntuados: rating.partidosPuntuados,
      ultimo_partido: rating.ultimoPartido,
      escala: escala.id,
      division: division?.division ?? divisionDe(escala, rating.rating).nombre,
      partidos_en_zona_de_ascenso: division?.partidosEnZonaDeAscenso ?? 0,
      partidos_en_zona_de_descenso: division?.partidosEnZonaDeDescenso ?? 0,
      version: versionPor.get(jugadorId) ?? VERSION_SIN_PARTIDOS,
    });
  }

  // De las dos columnas, exactamente una lleva el id. Es lo que exige la
  // restricción `transaccion_de_un_solo_partido` de la 0015.
  const columnaDe = (partidoId: string) =>
    amistosos.has(partidoId)
      ? { match_id: null, friendly_match_id: partidoId }
      : { match_id: partidoId, friendly_match_id: null };

  const transacciones: TransaccionParaGuardar[] = estado.transacciones.map((t) => ({
    ...columnaDe(t.partidoId),
    player_id: t.jugadorId,
    fecha: t.fecha,
    rating_antes: t.ratingAntes,
    rating_despues: t.ratingDespues,
    delta: t.delta,
    probabilidad_esperada: t.probabilidadEsperada,
    rating_rivales: t.ratingRivales,
    resultado: t.resultado,
    version: t.version,
  }));

  const divisiones: CambioParaGuardar[] = estado.historialDeDivision.map((c) => ({
    player_id: c.jugadorId,
    ...columnaDe(c.partidoId),
    fecha: c.fecha,
    escala: escala.id,
    anterior: c.anterior,
    nueva: c.nueva,
    tipo: c.tipo,
    rating_al_cambiar: c.ratingAlCambiar,
  }));

  const puntuados = new Set(estado.transacciones.map((t) => t.partidoId));

  return {
    ratings,
    transacciones,
    divisiones,
    partidos: [...puntuados].filter((id) => !amistosos.has(id)),
    amistosos: [...puntuados].filter((id) => amistosos.has(id)),
  };
}

/**
 * Versión que se anota a quien todavía no ha jugado nada que puntúe.
 *
 * No es la versión de ningún algoritmo: es que no ha pasado por ninguno. Ponerle
 * la v1 diría que su 1375 lo calculó la v1, y no lo calculó nadie — es el rating
 * de partida de su división declarada.
 */
export const VERSION_SIN_PARTIDOS = "sin-partidos";
