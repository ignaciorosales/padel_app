/**
 * Las horas de las rondas de un torneo, cuando el sábado se tuerce.
 *
 * TypeScript puro y sin base de datos, como el resto de `lib/torneo`: entra el
 * horario que hay y sale el que debería quedar.
 */

export type RondaConHora = {
  id: string;
  numero: number;
  /** "HH:MM" o "HH:MM:SS", tal y como viene de Postgres. Puede no tenerla. */
  hora: string | null;
};

export type CambioDeHora = { id: string; hora: string | null };

const MINUTOS_DEL_DIA = 24 * 60;

function aMinutos(hora: string): number {
  const [h, m] = hora.split(":").map(Number);
  return h * 60 + m;
}

function aHora(minutos: number): string {
  const total = Math.max(0, Math.min(minutos, MINUTOS_DEL_DIA - 1));
  const hh = String(Math.floor(total / 60)).padStart(2, "0");
  const mm = String(total % 60).padStart(2, "0");
  return `${hh}:${mm}`;
}

/**
 * Cambiar la hora de una ronda arrastra las siguientes el mismo rato.
 *
 * Es lo que quiere decir el encargado cuando toca una hora a media mañana: no
 * «la ronda 3 empieza media hora más tarde y las demás siguen igual», sino
 * «vamos media hora tarde». Dejar las posteriores quietas produce un horario
 * que no se puede jugar —dos rondas pisándose en las mismas pistas— y que la
 * agenda del club rechaza a trozos.
 *
 * Las rondas anteriores no se tocan: ya se jugaron.
 *
 * Casos en los que no hay nada que arrastrar, y devuelve sólo esa ronda:
 *
 * - Vaciar la hora. Es válido —hay clubes que no las anuncian— pero no define
 *   ningún desplazamiento.
 * - Ponerle hora a una ronda que no tenía. No hay «antes» del que medir.
 */
export function cambiarHoraDeRonda(
  rondas: RondaConHora[],
  rondaId: string,
  horaNueva: string | null,
): CambioDeHora[] {
  const ronda = rondas.find((r) => r.id === rondaId);
  if (!ronda) return [];

  if (horaNueva === null || ronda.hora === null) {
    return [{ id: ronda.id, hora: horaNueva }];
  }

  const desplazamiento = aMinutos(horaNueva) - aMinutos(ronda.hora);
  if (desplazamiento === 0) return [];

  const cambios: CambioDeHora[] = [{ id: ronda.id, hora: horaNueva }];

  for (const otra of rondas) {
    if (otra.numero <= ronda.numero || otra.hora === null) continue;
    cambios.push({ id: otra.id, hora: aHora(aMinutos(otra.hora) + desplazamiento) });
  }

  return cambios;
}
