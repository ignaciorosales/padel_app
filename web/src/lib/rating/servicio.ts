import "server-only";

/**
 * El servicio de rating: la frontera entre el motor y el resto del mundo.
 *
 * Nada de lo que hay debajo de esta línea sabe qué fórmula se usa, y nada de lo
 * que hay encima sabe que existe Supabase. Es la única pieza que ve las dos
 * cosas, y es a propósito la más aburrida del sistema: leer, llamar al motor,
 * guardar.
 *
 * ## Por qué reconstruye entero en vez de puntuar sólo lo nuevo
 *
 * Porque el motor de la v1 no puede hacer otra cosa, y es mejor decirlo que
 * disimularlo. `procesar()` acepta ratings de partida (un número por jugador),
 * pero **no acepta un estado previo**: la desviación, la cuenta de partidos y la
 * cuenta de la histéresis no se pueden inyectar. Si se le pasaran sólo los
 * partidos nuevos, todo el mundo volvería a arrancar con desviación 350 — es
 * decir, con la K de un recién llegado — y un torneo movería los ratings el
 * triple de lo que debe.
 *
 * Así que cada pasada procesa el historial entero y reemplaza el resultado. No
 * es un apaño: es lo que significa "el rating se reconstruye, no se acumula".
 * Sale gratis mientras la red quepa en memoria, que a esta escala es de sobra.
 *
 * El día que no quepa, el camino está claro y no pasa por complicar esto:
 * ampliar `EntradaDelMotor` para que acepte el estado previo completo, y puntuar
 * incremental **sólo** cuando los partidos nuevos sean posteriores a todo lo ya
 * procesado. Cuando no lo sean —un club que carga el torneo del mes pasado—
 * sigue haciendo falta reconstruir, porque el orden cambia el resultado.
 *
 * ## Qué pasa si dos procesos coinciden
 *
 * Los dos calculan lo mismo, porque los dos leen el mismo historial. El que
 * llegue segundo choca con el índice único de `rating_transactions` y su
 * transacción se cae entera: no queda nada a medias y no hay nada que arreglar.
 * Ver backend/migrations/0014_esquema_del_rating.sql.
 */

import { createAdminClient } from "@/lib/supabase/admin";
import { ESCALA_UY, type EscalaDeDivisiones } from "./divisiones.ts";
import { procesar, revisarDivisionDeclarada, type Estado, type Revision } from "./motor.ts";
import {
  paraGuardar,
  puntuablesDeLasFilas,
  ratingsInicialesDe,
  type FilaDeInscrito,
  type FilaDeJugador,
  type FilaDeMatch,
  type FilaDeRonda,
  type FilaDeTorneo,
  type Huerfano,
} from "./consultas.ts";
import {
  partidosDeLosAmistosos,
  type DescarteDeAmistoso,
  type FilaDeAmistoso,
} from "./amistosos.ts";
import { paraRating } from "../jugador/desde-el-panel.ts";
import type { Descarte } from "../jugador/desde-el-panel.ts";
import type { Opciones } from "./algoritmo.ts";
import type { ReglasDeDivision } from "./divisiones.ts";

/** Postgres devuelve como máximo mil filas por petición; esto las trae todas. */
const PAGINA = 1000;

type Consulta = {
  tabla: string;
  columnas: string;
};

/**
 * Trae una tabla entera, por páginas.
 *
 * Sin esto el rating de una red con mil partidos sale bien y el de una con mil
 * uno sale mal en silencio, que es la peor clase de fallo: el límite de Supabase
 * no es un error, es una respuesta corta.
 */
async function todasLasFilas<T>(
  db: ReturnType<typeof createAdminClient>,
  { tabla, columnas }: Consulta,
): Promise<T[]> {
  const filas: T[] = [];

  for (let desde = 0; ; desde += PAGINA) {
    const { data, error } = await db
      .from(tabla)
      .select(columnas)
      // Un orden estable es imprescindible al paginar: sin él, dos páginas
      // pueden traer la misma fila y perderse otra.
      .order("id", { ascending: true })
      .range(desde, desde + PAGINA - 1);

    if (error) {
      throw new Error(`No se pudo leer ${tabla} para el rating: ${error.message}`);
    }

    const pagina = (data ?? []) as T[];
    filas.push(...pagina);
    if (pagina.length < PAGINA) return filas;
  }
}

export type Opcion = {
  opciones?: Opciones;
  escala?: EscalaDeDivisiones;
  reglas?: ReglasDeDivision;
};

export type Reconstruccion = {
  /** Partidos que movieron algún rating. */
  puntuados: number;
  /** Personas con rating después de la pasada. */
  jugadores: number;
  transacciones: number;
  cambiosDeDivision: number;
  /** Por qué se quedó fuera cada fila que no puntuó. */
  descartes: Descarte[];
  descartesDeAmistosos: DescarteDeAmistoso[];
  huerfanos: Huerfano[];
  /** Amistosos que existen pero todavía no puntúan: les faltan confirmaciones. */
  amistososSinConfirmar: number;
  /** Quién parece estar en la división equivocada. Es una tarea para el club. */
  revisiones: Revision[];
};

/**
 * Lee el historial entero, lo pasa por el motor y guarda el resultado.
 *
 * Escribe con la clave de servicio porque tiene que ver los partidos de todos
 * los clubes: el rating es de la red, y calcularlo club por club daría un número
 * distinto para la misma persona en cada uno.
 */
export async function reconstruirRating(
  opcion: Opcion = {},
): Promise<Reconstruccion> {
  const db = createAdminClient();
  const escala = opcion.escala ?? ESCALA_UY;

  const [matches, rondas, torneos, inscritos, jugadores, amistosos] = await Promise.all([
    todasLasFilas<FilaDeMatch>(db, {
      tabla: "matches",
      columnas: "id, round_id, pista, a1, a2, b1, b2, juegos_a, juegos_b",
    }),
    todasLasFilas<FilaDeRonda>(db, {
      tabla: "rounds",
      columnas: "id, tournament_id, numero",
    }),
    todasLasFilas<FilaDeTorneo>(db, {
      tabla: "tournaments",
      columnas: "id, fecha, formato, unidad_marcador",
    }),
    todasLasFilas<FilaDeInscrito>(db, {
      tabla: "tournament_players",
      columnas: "id, player_id",
    }),
    todasLasFilas<FilaDeJugador>(db, {
      tabla: "players",
      columnas: "id, division_declarada",
    }),
    todasLasFilas<FilaDeAmistoso>(db, {
      tabla: "friendly_matches",
      columnas:
        "id, club_id, fecha, a1, a2, b1, b2, marcador_a, marcador_b, unidad, " +
        "estado, origen_confirmado",
    }),
  ]);

  const { partidos, descartes, huerfanos } = puntuablesDeLasFilas(
    matches,
    rondas,
    torneos,
    inscritos,
  );

  // Los amistosos entran todos, también los pendientes: el motor los ignora por
  // el origen y los deja sin marcar, y así el día que se confirmen vuelven a
  // pasar. Filtrarlos aquí los perdería de vista.
  const deAmistosos = partidosDeLosAmistosos(amistosos);
  const idsDeAmistosos = new Set(deAmistosos.partidos.map((p) => p.id));

  const estado = procesar([...partidos, ...deAmistosos.partidos.map(paraRating)], {
    ratingsIniciales: ratingsInicialesDe(jugadores, escala),
    opciones: opcion.opciones,
    escala,
    reglas: opcion.reglas,
  });

  await guardar(db, estado, escala, idsDeAmistosos, true);

  return {
    puntuados: new Set(estado.transacciones.map((t) => t.partidoId)).size,
    jugadores: estado.ratings.size,
    transacciones: estado.transacciones.length,
    cambiosDeDivision: estado.historialDeDivision.length,
    descartes,
    descartesDeAmistosos: deAmistosos.descartes,
    huerfanos,
    amistososSinConfirmar: deAmistosos.partidos.filter(
      (p) => p.origen === "sin_puntuar",
    ).length,
    revisiones: revisarDivisionDeclarada(estado),
  };
}

/**
 * Guarda el estado en una sola transacción.
 *
 * La transacción no la abre el cliente —no puede—, la abre la función de
 * Postgres. Cuatro escrituras que tienen que entrar juntas: un rating sin su
 * transacción es un número que nadie puede explicar, y un partido marcado como
 * procesado sin su rating se pierde para siempre.
 */
async function guardar(
  db: ReturnType<typeof createAdminClient>,
  estado: Estado,
  escala: EscalaDeDivisiones,
  amistosos: ReadonlySet<string>,
  desdeCero: boolean,
): Promise<void> {
  const payload = paraGuardar(estado, escala, amistosos);

  const { error } = await db.rpc("aplicar_rating", {
    p_ratings: payload.ratings,
    p_transacciones: payload.transacciones,
    p_divisiones: payload.divisiones,
    p_partidos: payload.partidos,
    p_amistosos: payload.amistosos,
    p_desde_cero: desdeCero,
  });

  if (error) {
    throw new Error(`No se pudo guardar el rating: ${error.message}`);
  }
}

export type Pendientes = {
  deTorneo: number;
  amistosos: number;
  total: number;
};

/**
 * Cuántos partidos que ya pueden puntuar no han pasado nunca por el motor.
 *
 * Es la pregunta que decide si hace falta reconstruir, y se responde con dos
 * `count` sobre índices parciales en vez de leyendo la historia entera. Cuando da
 * cero, no hay nada que hacer.
 *
 * Un amistoso sin confirmar **no cuenta como pendiente**, aunque tenga la marca a
 * null y un resultado escrito. No lo está: está esperando a tres personas, y
 * contarlo dejaría este número clavado por encima de cero para siempre — que es
 * la forma más rápida de que nadie vuelva a mirarlo.
 */
export async function pendientesDePuntuar(): Promise<Pendientes> {
  const db = createAdminClient();

  const [torneo, amistoso] = await Promise.all([
    db
      .from("matches")
      .select("id", { count: "exact", head: true })
      .is("rating_processed_at", null)
      .not("juegos_a", "is", null),
    db
      .from("friendly_matches")
      .select("id", { count: "exact", head: true })
      .is("rating_processed_at", null)
      .eq("estado", "confirmado"),
  ]);

  const error = torneo.error ?? amistoso.error;
  if (error) {
    throw new Error(`No se pudo contar lo pendiente: ${error.message}`);
  }

  const deTorneo = torneo.count ?? 0;
  const amistosos = amistoso.count ?? 0;
  return { deTorneo, amistosos, total: deTorneo + amistosos };
}
