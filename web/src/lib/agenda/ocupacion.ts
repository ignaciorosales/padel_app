/**
 * Ocupación de pista: pista + rango horario + motivo.
 *
 * Es el objeto central del calendario del club (docs/producto/README.md). Aquí
 * vive sólo la parte que no toca la base de datos: convertir lo que ya sabe un
 * torneo —qué día es, a qué hora empieza cada ronda, cuánto dura, en qué pista
 * se juega cada partido— en las filas que ocupan el calendario.
 *
 * Está separado en TypeScript puro por la misma razón que el generador de
 * americanos: se puede probar a fondo sin levantar Supabase, y el día que la
 * agenda de la fase 2 tenga que colocar clases y reservas, reutiliza esto sin
 * arrastrar nada del panel de torneos.
 */

/** Motivos que caben en el enum `occupancy_reason` de la 0012. */
export type MotivoOcupacion = "torneo" | "clase" | "reserva" | "bloqueo";

/** Un partido, visto desde el calendario: dónde y cuándo, nada más. */
export type PartidoEnAgenda = {
  id: string;
  /** El número de pista dentro del torneo, o sea `matches.pista`. */
  pista: number;
  /** Hora de su ronda, "HH:MM" o "HH:MM:SS". Sin ella no ocupa nada. */
  hora: string | null;
};

export type DatosOcupacionTorneo = {
  clubId: string;
  torneoId: string;
  /** "2026-09-05" */
  fecha: string;
  minutosPorRonda: number;
  /** Número de pista del torneo -> id de la pista real del club. */
  pistaAPista: Map<number, string>;
  partidos: PartidoEnAgenda[];
};

/** Una fila de `court_occupancies`, con los nombres de columna de la 0012. */
export type FilaOcupacion = {
  club_id: string;
  court_id: string;
  durante: string;
  motivo: MotivoOcupacion;
  tournament_id: string | null;
  match_id: string | null;
};

/**
 * El literal de `tsrange` que entiende Postgres: `["inicio","fin")`.
 *
 * Medio abierto por el final a propósito: dos partidos seguidos en la misma
 * pista, uno de 10:00 a 10:20 y otro de 10:20 a 10:40, no se solapan. Con el
 * intervalo cerrado compartirían el instante 10:20 y la restricción de
 * exclusión los rechazaría, que es justo lo contrario de lo que se quiere.
 */
export function rangoTsrange(
  fecha: string,
  hora: string,
  minutos: number,
): string {
  const inicio = `${fecha} ${normalizarHora(hora)}`;
  const fin = `${fecha} ${normalizarHora(sumarMinutosAHora(hora, minutos))}`;
  return `["${inicio}","${fin}")`;
}

/** "18:30" y "18:30:00" son la misma hora; Postgres quiere la larga. */
function normalizarHora(hora: string): string {
  const [h = "00", m = "00", s = "00"] = hora.split(":");
  return `${h.padStart(2, "0")}:${m.padStart(2, "0")}:${s.padStart(2, "0")}`;
}

/**
 * Suma minutos a una hora del día, sin dar la vuelta al reloj.
 *
 * `sumarMinutos` de torneo/tipos.ts sí da la vuelta, porque allí sólo sirve
 * para enseñar la hora de una ronda. Aquí no puede: un partido que empieza a
 * las 23:50 y dura media hora terminaría a las 00:20 del *mismo* día y el
 * rango saldría al revés, que la base de datos rechaza. Se queda pegado a las
 * 23:59, y el club recoloca ese torneo si de verdad juega a medianoche.
 */
function sumarMinutosAHora(hora: string, minutos: number): string {
  const [h, m] = hora.split(":").map(Number);
  const total = Math.min(h * 60 + m + minutos, 24 * 60 - 1);
  const hh = String(Math.floor(total / 60)).padStart(2, "0");
  const mm = String(total % 60).padStart(2, "0");
  return `${hh}:${mm}`;
}

/**
 * Las ocupaciones que genera un torneo tal y como está ahora mismo.
 *
 * Se queda fuera, en silencio y a propósito:
 *
 * - El partido cuya ronda no tiene hora. Hay clubes que no las anuncian, y
 *   media ocupación (una pista, ningún horario) no es una ocupación.
 * - El partido en una pista que el torneo no tiene mapeada. Puede pasar si el
 *   organizador mueve un partido a una pista de más; el torneo funciona igual y
 *   el calendario simplemente no lo ve.
 *
 * Ninguno de los dos casos es un error que deba parar un sábado por la mañana:
 * el torneo no depende de la agenda, la alimenta.
 */
export function ocupacionesDeTorneo(d: DatosOcupacionTorneo): FilaOcupacion[] {
  const filas: FilaOcupacion[] = [];

  for (const partido of d.partidos) {
    if (!partido.hora) continue;

    const courtId = d.pistaAPista.get(partido.pista);
    if (!courtId) continue;

    filas.push({
      club_id: d.clubId,
      court_id: courtId,
      durante: rangoTsrange(d.fecha, partido.hora, d.minutosPorRonda),
      motivo: "torneo",
      tournament_id: d.torneoId,
      match_id: partido.id,
    });
  }

  return filas;
}

/**
 * Los nombres por defecto de las pistas que le faltan a un club.
 *
 * Un club que monta su primer torneo de cuatro pistas todavía no ha dado de
 * alta ninguna. En vez de pedírselas antes de dejarle empezar —un formulario
 * más entre él y sus rondas, que es justo lo que mide la métrica de los cinco
 * minutos— se le crean con el nombre que casi siempre acierta y las renombra
 * cuando quiera.
 */
export function pistasQueFaltan(
  ordenesExistentes: number[],
  necesarias: number,
): { nombre: string; orden: number }[] {
  const hay = new Set(ordenesExistentes);
  const nuevas: { nombre: string; orden: number }[] = [];

  for (let orden = 1; orden <= necesarias; orden++) {
    if (!hay.has(orden)) nuevas.push({ nombre: `Pista ${orden}`, orden });
  }

  return nuevas;
}
