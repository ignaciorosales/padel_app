export type EstadoTorneo = "borrador" | "en_juego" | "terminado";

export type Torneo = {
  id: string;
  club_id: string;
  slug: string;
  nombre: string;
  fecha: string;
  hora_inicio: string | null;
  pistas: number;
  rondas: number;
  minutos_por_ronda: number;
  /** "americano" | "parejas" */
  formato: string;
  /** Sólo en los de parejas. */
  grupos?: number | null;
  clasifican_por_grupo?: number | null;
  /** "juegos" | "sets" | "puntos". Sólo cambia cómo se llama en pantalla. */
  unidad_marcador?: string | null;
  estado: EstadoTorneo;
  semilla: number | null;
  publico: boolean;
  /** Criterios de desempate en orden. Se normaliza con normalizarDesempates(). */
  desempates: string[] | null;
  created_at: string;
};

export type Inscrito = {
  id: string;
  tournament_id: string;
  nombre: string;
  telefono: string | null;
  orden: number;
  /**
   * Lo que paga por la inscripción, y si el club ya lo cobró (0013).
   *
   * Nulo es «este torneo no cobra»; 0 es «éste no paga». No cruzan a la página
   * pública: el anónimo tiene revocado el permiso sobre esas columnas.
   */
  importe: number | null;
  pagado: boolean;
};

/**
 * Un inscrito visto desde la página pública: su nombre y su sitio en la lista.
 *
 * Tipo aparte, y no un `Partial<Inscrito>`, porque la diferencia no es
 * casualidad: el teléfono y el dinero no cruzan esa puerta, y el tipo tiene que
 * decirlo tan claro como lo dicen los permisos de la base de datos.
 */
export type InscritoPublico = {
  id: string;
  tournament_id: string;
  nombre: string;
  orden: number;
};

export type PartidoFila = {
  id: string;
  round_id: string;
  pista: number;
  /**
   * Los cuatro jugadores. `null` sólo en un hueco del cuadro que todavía no
   * tiene ocupante — en un americano y en la fase de grupos van siempre.
   */
  a1: string | null;
  a2: string | null;
  b1: string | null;
  b2: string | null;
  juegos_a: number | null;
  juegos_b: number | null;
  /** De qué pareja es cada lado. NULL en los americanos. */
  pareja_a?: string | null;
  pareja_b?: string | null;
};

export type RondaFila = {
  id: string;
  tournament_id: string;
  numero: number;
  hora: string | null;
  /** "grupo" o el nombre de una ronda del cuadro. Ver la migración 0006. */
  fase?: string | null;
};

const TITULO_DE_FASE: Record<string, string> = {
  sesentaicuatroavos: "Sesentaicuatroavos",
  treintaidosavos: "Treintaidosavos",
  dieciseisavos: "Dieciseisavos",
  octavos: "Octavos",
  cuartos: "Cuartos de final",
  semifinal: "Semifinales",
  final: "Final",
  tercer_puesto: "Tercer puesto",
};

/**
 * Cómo se llama una ronda en pantalla.
 *
 * En el cuadro manda la fase: nadie dice «ronda 7», dice «semifinales». En la
 * fase de grupos y en un americano manda el número, porque ahí todas las
 * rondas son iguales.
 */
export function tituloDeRonda(
  ronda: RondaFila,
  formato: string,
): string {
  const titulo = ronda.fase ? TITULO_DE_FASE[ronda.fase] : undefined;
  if (titulo) return titulo;
  return formato === "parejas" ? `Jornada ${ronda.numero}` : `Ronda ${ronda.numero}`;
}

/** ¿Esta ronda es del cuadro eliminatorio? */
export function esDelCuadro(ronda: RondaFila): boolean {
  return !!ronda.fase && ronda.fase !== "grupo";
}

export const ETIQUETA_TORNEO: Record<
  EstadoTorneo,
  { texto: string; tono: "neutro" | "acento" | "ok" }
> = {
  borrador: { texto: "Borrador", tono: "neutro" },
  en_juego: { texto: "En juego", tono: "acento" },
  terminado: { texto: "Terminado", tono: "ok" },
};

/** "18:30" a partir de una hora de inicio y los minutos que se le suman. */
export function sumarMinutos(hora: string, minutos: number): string {
  const [h, m] = hora.split(":").map(Number);
  const total = (h * 60 + m + minutos) % (24 * 60);
  const hh = String(Math.floor(total / 60)).padStart(2, "0");
  const mm = String(total % 60).padStart(2, "0");
  return `${hh}:${mm}`;
}

/** Recorta "18:30:00" a "18:30" para enseñarlo. */
export function soloHoraMinuto(hora: string | null): string | null {
  return hora ? hora.slice(0, 5) : null;
}
