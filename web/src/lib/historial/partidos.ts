/**
 * El historial de un jugador, visto desde él.
 *
 * Un partido en la base de datos no tiene lados propios ni ajenos: tiene un lado
 * A y un lado B. Todo lo que se enseña en la app —"ganaste 6-4", "tu compañero
 * fue Javi"— es ese mismo partido girado hacia una persona. Aquí está el giro, y
 * las cuentas que salen de él.
 *
 * Dos reglas de producto que se ven en los tipos:
 *
 * - **Lo verificado alimenta la competición; el amistoso alimenta tu
 *   actividad.** Por eso `resumen` devuelve dos bloques y no uno: el porcentaje
 *   de victorias y la racha salen sólo de torneos y marcador, mientras que
 *   "cuánto has jugado" lo suma todo.
 * - **En un americano el resultado del día no es la suma de partidos, es el
 *   puesto.** Por eso el historial se agrupa por evento: la gente dice "salí
 *   tercero en el americano del sábado", no "gané cinco de ocho".
 *
 * Sin base de datos y sin React, como el resto de `lib/`: entra una lista de
 * partidos y salen cuentas.
 */

import { puntua, type JugadorId, type OrigenDelPartido } from "../rating/algoritmo.ts";

export type { JugadorId, OrigenDelPartido };

/**
 * De dónde salió el partido.
 *
 * Es la misma lista que usa el rating, y a propósito: si el historial tuviera su
 * propia idea de qué es un partido "verificado", tarde o temprano diría una cosa
 * distinta de la que dice el ranking sobre el mismo partido.
 */
export type Origen = OrigenDelPartido;

export type Formato = "americano" | "parejas";
export type Unidad = "juegos" | "sets" | "puntos";

export type Partido = {
  id: string;
  /** El torneo del que sale. Null en un amistoso suelto. */
  eventoId: string | null;
  /** ISO. Sólo se usa para ordenar y para agrupar por mes. */
  fecha: string;
  origen: Origen;
  formato: Formato;
  unidad: Unidad;
  a: readonly [JugadorId, JugadorId];
  b: readonly [JugadorId, JugadorId];
  marcadorA: number;
  marcadorB: number;
};

export type Resultado = "ganado" | "empatado" | "perdido";

/** Un partido girado hacia un jugador. */
export type Vista = {
  partido: Partido;
  companero: JugadorId;
  rivales: readonly [JugadorId, JugadorId];
  propio: number;
  contrario: number;
  resultado: Resultado;
};

/** Cuenta para el récord exactamente lo mismo que cuenta para el rating. */
export function esVerificado(partido: Partido): boolean {
  return puntua(partido.origen);
}

/**
 * El partido desde el punto de vista de un jugador, o null si no jugó.
 *
 * Un empate es posible y no es un caso raro: los americanos se juegan a tiempo y
 * terminan en tablas más de lo que parece.
 */
export function comoLoVio(jugador: JugadorId, partido: Partido): Vista | null {
  const enA = partido.a.indexOf(jugador);
  const enB = partido.b.indexOf(jugador);
  if (enA === -1 && enB === -1) return null;

  const propio = enA !== -1 ? partido.marcadorA : partido.marcadorB;
  const contrario = enA !== -1 ? partido.marcadorB : partido.marcadorA;

  return {
    partido,
    companero: enA !== -1 ? partido.a[1 - enA] : partido.b[1 - enB],
    rivales: enA !== -1 ? partido.b : partido.a,
    propio,
    contrario,
    resultado: propio > contrario ? "ganado" : propio < contrario ? "perdido" : "empatado",
  };
}

/** Los partidos de un jugador, del más antiguo al más nuevo. */
export function partidosDe(
  jugador: JugadorId,
  partidos: readonly Partido[],
): Vista[] {
  return partidos
    .map((p) => comoLoVio(jugador, p))
    .filter((v): v is Vista => v !== null)
    .sort(
      (x, y) =>
        x.partido.fecha.localeCompare(y.partido.fecha) ||
        x.partido.id.localeCompare(y.partido.id),
    );
}

// ---------------------------------------------------------------- totales

export type Totales = {
  partidos: number;
  ganados: number;
  empatados: number;
  perdidos: number;
  /**
   * Sobre partidos jugados, no sobre partidos decididos: un empate no es media
   * victoria, es un partido que no se ganó.
   */
  porcentaje: number;
  favor: number;
  contra: number;
  diferencia: number;
};

export function totalesDe(vistas: readonly Vista[]): Totales {
  const t: Totales = {
    partidos: 0,
    ganados: 0,
    empatados: 0,
    perdidos: 0,
    porcentaje: 0,
    favor: 0,
    contra: 0,
    diferencia: 0,
  };

  for (const v of vistas) {
    t.partidos++;
    if (v.resultado === "ganado") t.ganados++;
    else if (v.resultado === "empatado") t.empatados++;
    else t.perdidos++;
    t.favor += v.propio;
    t.contra += v.contrario;
  }

  t.diferencia = t.favor - t.contra;
  t.porcentaje = t.partidos === 0 ? 0 : t.ganados / t.partidos;
  return t;
}

// ----------------------------------------------------------------- rachas

export type Racha = {
  tipo: "ganando" | "perdiendo" | "ninguna";
  /** Partidos seguidos del mismo signo, ahora mismo. */
  largo: number;
  /** La mejor racha de victorias de toda su historia. */
  mejor: number;
};

/**
 * Un empate corta la racha sin abrir otra: no se ha ganado, pero tampoco se ha
 * perdido, y contarlo como derrota sería mentir en la dirección que más molesta.
 */
export function rachaDe(vistas: readonly Vista[]): Racha {
  let mejor = 0;
  let seguidas = 0;
  for (const v of vistas) {
    seguidas = v.resultado === "ganado" ? seguidas + 1 : 0;
    if (seguidas > mejor) mejor = seguidas;
  }

  let largo = 0;
  let tipo: Racha["tipo"] = "ninguna";
  for (let i = vistas.length - 1; i >= 0; i--) {
    const r = vistas[i].resultado;
    if (r === "empatado") break;
    const suyo = r === "ganado" ? "ganando" : "perdiendo";
    if (tipo === "ninguna") tipo = suyo;
    else if (tipo !== suyo) break;
    largo++;
  }

  return { tipo: largo === 0 ? "ninguna" : tipo, largo, mejor };
}

// ---------------------------------------------------------------- resumen

export type Resumen = {
  /** Torneos y marcador. Es lo que se enseña como récord y lo que rankea. */
  oficial: Totales & { racha: Racha };
  /** Todo, amistosos incluidos. Es "cuánto juegas", no "cómo juegas". */
  actividad: Totales;
};

export function resumen(jugador: JugadorId, partidos: readonly Partido[]): Resumen {
  const todos = partidosDe(jugador, partidos);
  const verificados = todos.filter((v) => esVerificado(v.partido));

  return {
    oficial: { ...totalesDe(verificados), racha: rachaDe(verificados) },
    actividad: totalesDe(todos),
  };
}

// ----------------------------------------------------------- por evento

export type Evento = {
  /** El id del torneo, o el del propio partido cuando es un amistoso suelto. */
  id: string;
  /** Null cuando no viene de un torneo. */
  eventoId: string | null;
  fecha: string;
  formato: Formato;
  origen: Origen;
  partidos: Vista[];
  totales: Totales;
};

/**
 * Agrupa el historial por evento, del más nuevo al más antiguo.
 *
 * Los amistosos no tienen torneo, así que cada uno es su propio evento: en el
 * historial se ven como una fila suelta, que es lo que son.
 */
export function porEvento(
  jugador: JugadorId,
  partidos: readonly Partido[],
): Evento[] {
  const eventos = new Map<string, Evento>();

  for (const v of partidosDe(jugador, partidos)) {
    const clave = v.partido.eventoId ?? `suelto:${v.partido.id}`;
    let evento = eventos.get(clave);
    if (!evento) {
      evento = {
        id: clave,
        eventoId: v.partido.eventoId,
        fecha: v.partido.fecha,
        formato: v.partido.formato,
        origen: v.partido.origen,
        partidos: [],
        totales: totalesDe([]),
      };
      eventos.set(clave, evento);
    }
    evento.partidos.push(v);
    if (v.partido.fecha < evento.fecha) evento.fecha = v.partido.fecha;
  }

  const lista = [...eventos.values()];
  for (const evento of lista) evento.totales = totalesDe(evento.partidos);
  return lista.sort((x, y) => y.fecha.localeCompare(x.fecha) || y.id.localeCompare(x.id));
}

// --------------------------------------------------------------- por mes

export type Mes = {
  /** "2026-08". */
  mes: string;
  eventos: number;
  totales: Totales;
};

/** El resumen mensual que abre cada bloque del historial. Del más nuevo al más antiguo. */
export function porMes(jugador: JugadorId, partidos: readonly Partido[]): Mes[] {
  const meses = new Map<string, { vistas: Vista[]; eventos: Set<string> }>();

  for (const v of partidosDe(jugador, partidos)) {
    const mes = v.partido.fecha.slice(0, 7);
    let bloque = meses.get(mes);
    if (!bloque) {
      bloque = { vistas: [], eventos: new Set() };
      meses.set(mes, bloque);
    }
    bloque.vistas.push(v);
    bloque.eventos.add(v.partido.eventoId ?? `suelto:${v.partido.id}`);
  }

  return [...meses.entries()]
    .map(([mes, bloque]) => ({
      mes,
      eventos: bloque.eventos.size,
      totales: totalesDe(bloque.vistas),
    }))
    .sort((x, y) => y.mes.localeCompare(x.mes));
}
