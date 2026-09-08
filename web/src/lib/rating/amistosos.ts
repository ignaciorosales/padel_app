/**
 * Amistosos: de una fila de `friendly_matches` a un partido que puede puntuar.
 *
 * Un amistoso es el partido más común de un club y el menos fiable: lo apunta
 * uno de los cuatro desde el móvil, de memoria, media hora después. Por eso nace
 * sin puntuar y sólo cuenta cuando los cuatro lo aceptan.
 *
 * Aquí vive la traducción de ese ciclo de vida al lenguaje del motor, que sólo
 * entiende de orígenes y confianzas. Es una función de cuatro líneas y merece un
 * fichero porque es la única: si el panel, la app y el servicio dedujeran cada
 * uno por su cuenta cuándo un amistoso puntúa, acabarían discrepando sobre el
 * mismo partido — y el jugador vería "confirmado" en una pantalla y "pendiente"
 * en otra.
 */

import type { OrigenDelPartido } from "./algoritmo.ts";
import type { Partido, Unidad } from "../historial/partidos.ts";

/** El ciclo de vida de un amistoso, tal cual está en la columna `estado`. */
export type EstadoDelAmistoso = "pendiente" | "confirmado" | "rechazado";

/**
 * De dónde salió el resultado. Decide la confianza **una vez confirmado**, y por
 * eso no incluye `sin_puntuar`: eso no es un origen, es no estar confirmado.
 */
export type OrigenConfirmado = "confirmado" | "club" | "liga" | "marcador";

/** Una fila de `friendly_matches`, con los nombres de columna de Postgres. */
export type FilaDeAmistoso = {
  id: string;
  club_id: string | null;
  fecha: string;
  a1: string;
  a2: string;
  b1: string;
  b2: string;
  marcador_a: number;
  marcador_b: number;
  unidad: string;
  estado: string;
  origen_confirmado: string;
};

/** Una fila de `friendly_match_confirmations`. */
export type FilaDeRespuesta = {
  match_id: string;
  player_id: string;
  respuesta: string;
};

const ESTADOS = new Set<string>(["pendiente", "confirmado", "rechazado"]);
const ORIGENES = new Set<string>(["confirmado", "club", "liga", "marcador"]);
const UNIDADES = new Set<string>(["juegos", "sets", "puntos"]);

/**
 * Qué origen ve el motor.
 *
 * Las dos columnas dicen cosas distintas y ninguna sobra: `estado` es si ya
 * cuenta, `origen_confirmado` es cuánto vale cuando cuente. Un amistoso
 * confirmado por los cuatro vale 0,8; el mismo partido cargado por el club vale
 * 0,9, porque el club no tiene por qué haber jugado y no gana nada mintiendo.
 *
 * Un valor que no se reconoce se trata como sin puntuar. Es la respuesta segura
 * en la única dirección que importa: un origen desconocido que puntuara movería
 * ratings con una confianza que nadie eligió.
 */
export function origenDelAmistoso(
  estado: string,
  origenConfirmado: string,
): OrigenDelPartido {
  if (estado !== "confirmado") return "sin_puntuar";
  if (!ORIGENES.has(origenConfirmado)) return "sin_puntuar";
  return origenConfirmado as OrigenDelPartido;
}

export type MotivoDeDescarteDeAmistoso =
  | "sin_juego"
  | "estado_desconocido"
  | "unidad_desconocida"
  | "jugadores_repetidos";

export type DescarteDeAmistoso = {
  filaId: string;
  motivo: MotivoDeDescarteDeAmistoso;
};

export type ConversionDeAmistosos = {
  partidos: Partido[];
  descartes: DescarteDeAmistoso[];
};

/**
 * Las filas de amistosos como partidos del historial.
 *
 * Salen todos, también los que aún no puntúan: un amistoso pendiente sí cuenta
 * para "cuánto has jugado este mes", que es la mitad de para qué sirve
 * apuntarlos. El que decide qué mueve el rating es el motor, mirando el origen.
 *
 * Mismo trato que en `jugador/desde-el-panel.ts`: nada se descarta en silencio.
 */
export function partidosDeLosAmistosos(
  filas: readonly FilaDeAmistoso[],
): ConversionDeAmistosos {
  const partidos: Partido[] = [];
  const descartes: DescarteDeAmistoso[] = [];

  const ordenadas = [...filas].sort(
    (x, y) => x.fecha.localeCompare(y.fecha) || x.id.localeCompare(y.id),
  );

  for (const fila of ordenadas) {
    const descartar = (motivo: MotivoDeDescarteDeAmistoso) => {
      descartes.push({ filaId: fila.id, motivo });
    };

    // La base de datos ya lo impide con una restricción; el filtro está para que
    // una fila vieja o importada no se cuele si alguna vez se relaja.
    if (fila.marcador_a + fila.marcador_b <= 0) {
      descartar("sin_juego");
      continue;
    }
    if (new Set([fila.a1, fila.a2, fila.b1, fila.b2]).size !== 4) {
      descartar("jugadores_repetidos");
      continue;
    }
    if (!ESTADOS.has(fila.estado)) {
      descartar("estado_desconocido");
      continue;
    }
    if (!UNIDADES.has(fila.unidad)) {
      descartar("unidad_desconocida");
      continue;
    }

    partidos.push({
      id: fila.id,
      // Un amistoso no sale de ningún torneo, y en el historial se ve como una
      // fila suelta. `porEvento` ya lo trata así.
      eventoId: null,
      fecha: fila.fecha,
      origen: origenDelAmistoso(fila.estado, fila.origen_confirmado),
      formato: "amistoso",
      unidad: fila.unidad as Unidad,
      a: [fila.a1, fila.a2],
      b: [fila.b1, fila.b2],
      marcadorA: fila.marcador_a,
      marcadorB: fila.marcador_b,
    });
  }

  return { partidos, descartes };
}

// ------------------------------------------------------ quién falta por decir

export type Confirmaciones = {
  /** Los cuatro que jugaron, en el orden en que están en el partido. */
  jugadores: string[];
  aceptan: string[];
  rechazan: string[];
  /** Los que no han contestado todavía. No es lo mismo que haber dicho que no. */
  faltan: string[];
  /**
   * Si con estas respuestas el partido debería estar confirmado.
   *
   * **La base de datos es la autoridad**: el estado lo calcula un disparador
   * dentro de la misma transacción que escribe la respuesta, porque el último de
   * los cuatro en aceptar es el que confirma y dos móviles pueden aceptar a la
   * vez. Esto es la misma regla en el idioma de la app, para poder decir "falta
   * Santi" sin volver a preguntar al servidor. Si alguna vez discrepan, manda la
   * columna `estado`.
   */
  listo: boolean;
};

export function confirmacionesDe(
  fila: FilaDeAmistoso,
  respuestas: readonly FilaDeRespuesta[],
): Confirmaciones {
  const jugadores = [fila.a1, fila.a2, fila.b1, fila.b2];
  const suyas = respuestas.filter(
    (r) => r.match_id === fila.id && jugadores.includes(r.player_id),
  );

  // Si alguien contestó dos veces, manda la última: la clave primaria de la
  // tabla lo impide, pero el orden de llegada de una lista no está garantizado.
  const porJugador = new Map<string, string>();
  for (const r of suyas) porJugador.set(r.player_id, r.respuesta);

  const aceptan = jugadores.filter((j) => porJugador.get(j) === "acepta");
  const rechazan = jugadores.filter((j) => porJugador.get(j) === "rechaza");
  const faltan = jugadores.filter((j) => !porJugador.has(j));

  return {
    jugadores,
    aceptan,
    rechazan,
    faltan,
    // Asimétrico a propósito, igual que el disparador: uno que dice que no lo
    // tumba, y hacen falta los cuatro para levantarlo.
    listo: rechazan.length === 0 && aceptan.length === jugadores.length,
  };
}

/**
 * Un amistoso cargado por el club no espera a nadie.
 *
 * El club es la autoridad de sus pistas: si el resultado lo apunta quien está
 * detrás del mostrador, pedirle a los cuatro que lo ratifiquen no añade
 * información, sólo fricción — y el 0,9 de confianza ya dice que se le cree más
 * que a los propios jugadores.
 */
export function necesitaConfirmacion(fila: FilaDeAmistoso): boolean {
  return fila.origen_confirmado !== "club";
}
