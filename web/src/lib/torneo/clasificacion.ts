/**
 * Clasificación de un americano individual.
 *
 * Cada jugador cambia de compañero cada ronda, así que la tabla es personal:
 * lo que cuenta son los juegos que ha ganado, no los de su pareja de turno.
 *
 * Criterios, en orden:
 *   1. Juegos a favor (es el criterio habitual en los clubes)
 *   2. Diferencia entre juegos a favor y en contra
 *   3. Partidos ganados
 *
 * Los empates a todo comparten puesto y se dejan en el orden en que llegaron,
 * que en la práctica es el de inscripción.
 */

export type PartidoJugado = {
  a1: string;
  a2: string;
  b1: string;
  b2: string;
  juegosA: number;
  juegosB: number;
};

export type FilaClasificacion = {
  jugadorId: string;
  puesto: number;
  partidos: number;
  ganados: number;
  empatados: number;
  perdidos: number;
  juegosFavor: number;
  juegosContra: number;
  diferencia: number;
};

export function calcularClasificacion(
  jugadorIds: string[],
  partidos: PartidoJugado[],
): FilaClasificacion[] {
  const filas = new Map<string, FilaClasificacion>();

  for (const id of jugadorIds) {
    filas.set(id, {
      jugadorId: id,
      puesto: 0,
      partidos: 0,
      ganados: 0,
      empatados: 0,
      perdidos: 0,
      juegosFavor: 0,
      juegosContra: 0,
      diferencia: 0,
    });
  }

  for (const p of partidos) {
    const equipoA = [p.a1, p.a2];
    const equipoB = [p.b1, p.b2];

    for (const [equipo, favor, contra] of [
      [equipoA, p.juegosA, p.juegosB],
      [equipoB, p.juegosB, p.juegosA],
    ] as const) {
      for (const id of equipo) {
        const fila = filas.get(id);
        // Un partido de un jugador que ya no está inscrito no cuenta para nadie.
        if (!fila) continue;

        fila.partidos++;
        fila.juegosFavor += favor;
        fila.juegosContra += contra;
        if (favor > contra) fila.ganados++;
        else if (favor < contra) fila.perdidos++;
        else fila.empatados++;
      }
    }
  }

  const orden = [...filas.values()];
  for (const fila of orden) {
    fila.diferencia = fila.juegosFavor - fila.juegosContra;
  }

  const posicionInicial = new Map(jugadorIds.map((id, i) => [id, i]));

  orden.sort((x, y) => {
    if (y.juegosFavor !== x.juegosFavor) return y.juegosFavor - x.juegosFavor;
    if (y.diferencia !== x.diferencia) return y.diferencia - x.diferencia;
    if (y.ganados !== x.ganados) return y.ganados - x.ganados;
    return (posicionInicial.get(x.jugadorId) ?? 0) - (posicionInicial.get(y.jugadorId) ?? 0);
  });

  let puesto = 0;
  let anterior: FilaClasificacion | null = null;

  orden.forEach((fila, indice) => {
    const empatado =
      anterior !== null &&
      anterior.juegosFavor === fila.juegosFavor &&
      anterior.diferencia === fila.diferencia &&
      anterior.ganados === fila.ganados;

    puesto = empatado ? puesto : indice + 1;
    fila.puesto = puesto;
    anterior = fila;
  });

  return orden;
}
