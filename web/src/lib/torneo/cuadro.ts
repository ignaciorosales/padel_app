/**
 * Cuentas de un cuadro de americano, para poder enseñarle al organizador qué
 * va a pasar antes de generar nada.
 *
 * Las rondas NO salen del número de jugadores: salen del tiempo que el club
 * tiene reservada la pista. Lo que sí depende de los jugadores es cuántos
 * caben por ronda, cuántos descansan y a partir de cuántas rondas es
 * matemáticamente imposible no repetir compañero.
 */

import { sumarMinutos } from "./tipos.ts";

export type AvisoCuadro = {
  tono: "info" | "warn" | "danger";
  texto: string;
};

export type Cuadro = {
  /** Pistas que se llenan de verdad; el resto sobran. */
  pistasUtiles: number;
  jugadoresPorRonda: number;
  descansanPorRonda: number;
  /** Partidos que jugará cada persona, repartidos lo más igual posible. */
  partidosPorJugador: { min: number; max: number };
  duracionMinutos: number;
  horaFin: string | null;
  /**
   * Tope teórico de rondas sin que nadie repita compañero.
   *
   * Cada jugador puede tener como mucho N-1 compañeros distintos, así que
   * quien juega R rondas necesita R ≤ N-1. Como con descansos no todos juegan
   * todas las rondas, el tope en rondas totales sube en esa proporción.
   * Es una cota de conteo: dice cuándo es imposible, no garantiza que sea
   * posible por debajo. El generador informa de las repeticiones reales.
   */
  maxRondasSinRepetir: number;
  avisos: AvisoCuadro[];
};

export function describirCuadro({
  inscritos,
  pistas,
  rondas,
  minutosPorRonda,
  horaInicio,
}: {
  inscritos: number;
  pistas: number;
  rondas: number;
  minutosPorRonda: number;
  horaInicio?: string | null;
}): Cuadro {
  const pistasUtiles = Math.max(0, Math.min(pistas, Math.floor(inscritos / 4)));
  const jugadoresPorRonda = pistasUtiles * 4;
  const descansanPorRonda = Math.max(0, inscritos - jugadoresPorRonda);

  const plazas = jugadoresPorRonda * rondas;
  const partidosPorJugador =
    inscritos > 0
      ? {
          min: Math.floor(plazas / inscritos),
          max: plazas % inscritos === 0
            ? Math.floor(plazas / inscritos)
            : Math.floor(plazas / inscritos) + 1,
        }
      : { min: 0, max: 0 };

  const duracionMinutos = rondas * minutosPorRonda;
  const horaFin = horaInicio ? sumarMinutos(horaInicio.slice(0, 5), duracionMinutos) : null;

  const maxRondasSinRepetir =
    jugadoresPorRonda > 0
      ? Math.floor((inscritos * (inscritos - 1)) / jugadoresPorRonda)
      : 0;

  const avisos: AvisoCuadro[] = [];

  if (inscritos < 4) {
    avisos.push({
      tono: "danger",
      texto: `Con ${inscritos} inscrito${inscritos === 1 ? "" : "s"} no se puede montar ni un partido. Hacen falta 4.`,
    });
  } else {
    if (pistas > pistasUtiles) {
      avisos.push({
        tono: "warn",
        texto: `Sobran pistas: con ${inscritos} jugadores sólo se llenan ${pistasUtiles} de las ${pistas}.`,
      });
    }

    if (descansanPorRonda > 0) {
      avisos.push({
        tono: "info",
        texto: `Descansan ${descansanPorRonda} por ronda, rotando. Cada uno jugará ${
          partidosPorJugador.min === partidosPorJugador.max
            ? `${partidosPorJugador.min} partidos`
            : `${partidosPorJugador.min} o ${partidosPorJugador.max} partidos`
        }.`,
      });
    }

    if (rondas > maxRondasSinRepetir) {
      avisos.push({
        tono: "warn",
        texto: `Con ${inscritos} jugadores, a partir de ${maxRondasSinRepetir} rondas alguien tendrá que repetir compañero. Es matemático, no del programa.`,
      });
    }

    if (inscritos % 4 !== 0 && descansanPorRonda === 0) {
      avisos.push({
        tono: "info",
        texto: "El número de inscritos no es múltiplo de 4; sobran plazas sueltas.",
      });
    }
  }

  return {
    pistasUtiles,
    jugadoresPorRonda,
    descansanPorRonda,
    partidosPorJugador,
    duracionMinutos,
    horaFin,
    maxRondasSinRepetir,
    avisos,
  };
}

/** "2 h 40 min" */
export function formatearDuracion(minutos: number): string {
  const h = Math.floor(minutos / 60);
  const m = minutos % 60;
  if (h === 0) return `${m} min`;
  if (m === 0) return `${h} h`;
  return `${h} h ${m} min`;
}
