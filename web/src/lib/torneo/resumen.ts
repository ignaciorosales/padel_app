import type { EstadoTorneo } from "./tipos.ts";

export type DatosResumen = {
  estado: EstadoTorneo;
  fecha: string;
  jugadores: number;
  /** Partidos con resultado metido. */
  jugados: number;
  /** Partidos que hay en total, tengan resultado o no. */
  total: number;
  /** Quien va primero, sólo si el torneo ya terminó. */
  campeon: string | null;
};

/**
 * Cómo se describe un torneo en una línea, para el pie de la página pública.
 *
 * Existe porque ese pie decía «parejas de 1 rondas»: el formato en crudo tal y
 * como está en la base de datos, un número que en un torneo de parejas no
 * significa nada —`rondas` es del americano— y sin concordancia. Tres errores
 * en cinco palabras, en la página que el club enseña a sus socios.
 */
export function descripcionDelTorneo(t: {
  formato: string;
  rondas: number;
  /** Indefinido mientras la 0006 no esté aplicada; nulo si nadie los fijó. */
  grupos?: number | null;
}): string {
  if (t.formato === "parejas") {
    const grupos = t.grupos ?? 1;
    return `Torneo de parejas · ${grupos} grupo${grupos === 1 ? "" : "s"}`;
  }

  return `Americano de ${t.rondas} ronda${t.rondas === 1 ? "" : "s"}`;
}

/** "sábado, 6 de septiembre de 2026" */
export function fechaLarga(fecha: string): string {
  return new Date(`${fecha}T00:00:00`).toLocaleDateString("es-ES", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

/**
 * La frase que sale bajo el título al pegar el enlace en WhatsApp.
 *
 * Cambia con el estado del torneo, y ese es todo el truco: es lo que hace que
 * el enlace merezca abrirse. Antes dice cuándo es, durante dice por dónde va,
 * después dice quién ganó. Un texto fijo sólo sirve la primera vez que se pega
 * en el grupo, y el enlace se pega tres o cuatro veces el mismo día.
 */
export function resumenPublico(d: DatosResumen): string {
  const gente = `${d.jugadores} jugadores`;

  if (d.estado === "terminado" && d.campeon) {
    return `Ganó ${d.campeon}. Clasificación completa y todos los resultados.`;
  }

  if (d.estado === "terminado") {
    return `Clasificación final y todos los resultados. ${gente}.`;
  }

  if (d.jugados > 0 && d.jugados < d.total) {
    return `En juego: ${d.jugados} de ${d.total} partidos. Cruces y clasificación en directo.`;
  }

  if (d.jugados > 0 && d.jugados === d.total) {
    return `Todos los partidos jugados. Clasificación y resultados. ${gente}.`;
  }

  return `${fechaLarga(d.fecha)} · ${gente}. Cruces, resultados y clasificación.`;
}
