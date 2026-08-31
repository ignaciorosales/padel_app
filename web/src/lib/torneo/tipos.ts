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
  formato: string;
  estado: EstadoTorneo;
  semilla: number | null;
  publico: boolean;
  created_at: string;
};

export type Inscrito = {
  id: string;
  tournament_id: string;
  nombre: string;
  telefono: string | null;
  orden: number;
};

export type PartidoFila = {
  id: string;
  round_id: string;
  pista: number;
  a1: string;
  a2: string;
  b1: string;
  b2: string;
  juegos_a: number | null;
  juegos_b: number | null;
};

export type RondaFila = {
  id: string;
  tournament_id: string;
  numero: number;
  hora: string | null;
};

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
