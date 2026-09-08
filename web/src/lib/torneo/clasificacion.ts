/**
 * Clasificación de un americano individual.
 *
 * Cada jugador cambia de compañero cada ronda, así que la tabla es personal:
 * lo que cuenta son los juegos que ha ganado, no los de su pareja de turno.
 *
 * Los criterios de desempate los elige el club, porque no hay uno correcto:
 * unos cuentan juegos a favor y otros partidos ganados, y discutirlo el
 * sábado con la clasificación ya impresa es exactamente lo que hay que
 * evitar. Por defecto van los tres de siempre, en el orden habitual.
 *
 * Los empates a todos los criterios comparten puesto y se dejan en el orden en
 * que llegaron, que en la práctica es el de inscripción.
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

export const CRITERIOS = {
  juegos_favor: {
    texto: "Juegos a favor",
    valor: (f: FilaClasificacion) => f.juegosFavor,
    mayorEsMejor: true,
  },
  diferencia: {
    texto: "Diferencia de juegos",
    valor: (f: FilaClasificacion) => f.diferencia,
    mayorEsMejor: true,
  },
  ganados: {
    texto: "Partidos ganados",
    valor: (f: FilaClasificacion) => f.ganados,
    mayorEsMejor: true,
  },
  juegos_contra: {
    texto: "Menos juegos en contra",
    valor: (f: FilaClasificacion) => f.juegosContra,
    mayorEsMejor: false,
  },
} as const;

export type Criterio = keyof typeof CRITERIOS;

/**
 * Lo que usan los clubes en un americano cuando no dicen nada.
 *
 * Manda el total de juegos porque allí no existe "ganar el torneo" partido a
 * partido: cambias de compañero cada ronda y lo que acumulas es tuyo.
 */
export const DESEMPATES_POR_DEFECTO: Criterio[] = [
  "juegos_favor",
  "diferencia",
  "ganados",
];

/**
 * En un torneo de parejas manda otra cosa, y es al revés.
 *
 * Con pareja fija el objetivo es ganar partidos y pasar de ronda, así que una
 * pareja que gana tres ajustados va por delante de otra que perdió tres
 * goleando en uno. Poner aquí el orden del americano metería a la segunda en
 * semifinales, que es justo la injusticia que hace que un club no vuelva.
 */
export const DESEMPATES_PAREJAS_POR_DEFECTO: Criterio[] = [
  "ganados",
  "diferencia",
  "juegos_favor",
];

/**
 * Limpia lo que venga de la base de datos: descarta criterios desconocidos,
 * quita repetidos y cae a los de siempre si no queda ninguno. Una
 * clasificación sin criterios sería un orden arbitrario, y eso el sábado es
 * peor que una equivocada.
 */
export function normalizarDesempates(valor: unknown): Criterio[] {
  if (!Array.isArray(valor)) return DESEMPATES_POR_DEFECTO;

  const limpios = [...new Set(valor)].filter(
    (c): c is Criterio => typeof c === "string" && c in CRITERIOS,
  );

  return limpios.length > 0 ? limpios : DESEMPATES_POR_DEFECTO;
}

export function calcularClasificacion(
  jugadorIds: string[],
  partidos: PartidoJugado[],
  desempates: Criterio[] = DESEMPATES_POR_DEFECTO,
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

  return ordenarYNumerar([...filas.values()], jugadorIds, desempates);
}

/**
 * Ordena por los criterios elegidos y reparte los puestos.
 *
 * Vive aparte porque lo usan dos clasificaciones distintas —la individual del
 * americano y la de parejas del torneo tradicional— y los desempates tienen
 * que comportarse igual en las dos. Si divergieran, el mismo empate se
 * resolvería de dos maneras según el formato, y eso el sábado es una discusión.
 *
 * `ordenInicial` decide los empates a todo: es el orden de inscripción, que es
 * arbitrario pero estable, y estable es lo que importa para que la tabla no
 * baile entre recargas.
 */
export function ordenarYNumerar(
  filas: FilaClasificacion[],
  ordenInicial: string[],
  desempates: Criterio[] = DESEMPATES_POR_DEFECTO,
): FilaClasificacion[] {
  for (const fila of filas) {
    fila.diferencia = fila.juegosFavor - fila.juegosContra;
  }

  const posicionInicial = new Map(ordenInicial.map((id, i) => [id, i]));
  const criterios = normalizarDesempates(desempates);

  filas.sort((x, y) => {
    for (const clave of criterios) {
      const { valor, mayorEsMejor } = CRITERIOS[clave];
      const delta = mayorEsMejor ? valor(y) - valor(x) : valor(x) - valor(y);
      if (delta !== 0) return delta;
    }
    return (posicionInicial.get(x.jugadorId) ?? 0) - (posicionInicial.get(y.jugadorId) ?? 0);
  });

  let puesto = 0;
  let anterior: FilaClasificacion | null = null;

  filas.forEach((fila, indice) => {
    // Comparten puesto sólo quienes empatan en TODOS los criterios elegidos.
    const previa = anterior;
    const empatado =
      previa !== null &&
      criterios.every((c) => CRITERIOS[c].valor(previa) === CRITERIOS[c].valor(fila));

    puesto = empatado ? puesto : indice + 1;
    fila.puesto = puesto;
    anterior = fila;
  });

  return filas;
}

/** Una fila en blanco, para empezar a sumar. */
export function filaVacia(id: string): FilaClasificacion {
  return {
    jugadorId: id,
    puesto: 0,
    partidos: 0,
    ganados: 0,
    empatados: 0,
    perdidos: 0,
    juegosFavor: 0,
    juegosContra: 0,
    diferencia: 0,
  };
}
