/**
 * Los logros, y por qué existen.
 *
 * El rating ya premia jugar bien contra gente buena. Si los logros premiaran lo
 * mismo, serían una segunda tabla que dice lo que ya dice la primera y sólo la
 * ganaría quien ya gana. **Los logros están para premiar lo que el rating no
 * puede premiar**: aparecer, apuntar el resultado, confirmar el del rival, jugar
 * con gente nueva. Eso es lo que hace que un club esté vivo y lo que un número de
 * habilidad, por diseño, ignora.
 *
 * De ahí las tres reglas del catálogo:
 *
 * 1. **Casi todos se sacan jugando, no ganando.** Los que dependen de ganar son
 *    los menos, y ninguno pide ganar mucho: piden ganar algo difícil una vez.
 * 2. **Se calculan, no se guardan.** Un logro es una consulta sobre el historial,
 *    igual que el rating es una consulta sobre los partidos. Guardarlos obligaría
 *    a migrarlos cada vez que se añade uno, y a que un logro nuevo no exista para
 *    quien ya se lo había ganado.
 * 3. **Nada de rachas negativas ni de castigos.** Un logro que se pierde no es un
 *    logro, es una amenaza — y el sistema ya tiene un número que baja.
 *
 * El catálogo es **dato, no código**: añadir un logro es añadir un objeto a una
 * lista. Lo que no es dato es la condición, porque una condición es código; pero
 * cada una cabe en una línea y todas leen del mismo resumen.
 */

import type { Perfil } from "../jugador/perfil.ts";

export type Familia =
  /** Aparecer y seguir apareciendo. */
  | "constancia"
  /** Jugar con gente distinta. */
  | "club"
  /** Apuntar y confirmar resultados. */
  | "honestidad"
  /** Lo difícil, que se saca una vez. */
  | "gesta";

export type Logro = {
  id: string;
  nombre: string;
  /** Qué hay que hacer, en la voz en que se le dice al jugador. */
  descripcion: string;
  familia: Familia;
  /**
   * Cuántos hacen falta. Los logros con `meta` enseñan barra de progreso; los
   * demás son de sí o no.
   */
  meta?: number;
};

/**
 * Cuánto cuenta de un perfil para los logros.
 *
 * Se extrae del perfil una sola vez y se le pasa a todas las condiciones: sin
 * esto, veinte logros recorren el historial veinte veces y cada uno con su propia
 * idea de qué cuenta.
 */
export type Cuentas = {
  /** Todos los partidos, amistosos incluidos. Es «cuánto juega». */
  jugados: number;
  /** Sólo los que puntúan. Se usa poco a propósito. */
  puntuados: number;
  /** Amistosos que llegaron a confirmarse. La recompensa de apuntar. */
  amistososConfirmados: number;
  /** Personas distintas con las que ha jugado, de compañero o de rival. */
  gente: number;
  /** Compañeros distintos. */
  companeros: number;
  /** Meses distintos con al menos un partido. */
  meses: number;
  /** Mejor racha ganando. Nunca se cuenta la de perder. */
  mejorRacha: number;
  /** Ascensos de división. Los descensos no quitan ninguno. */
  ascensos: number;
  /** Victorias con menos de una cuarta parte de probabilidad. */
  gestas: number;
  /** Victorias contra una pareja más fuerte que su propio rating. */
  contraMasFuertes: number;
};

/**
 * Las cuentas de un perfil.
 *
 * Todo sale del perfil ya montado: los logros no vuelven a la base de datos ni
 * repiten ninguna regla del rating.
 */
export function cuentasDe(perfil: Perfil): Cuentas {
  const gente = new Set<string>([
    ...perfil.companeros.map((c) => c.jugadorId),
    ...perfil.rivales.map((r) => r.jugadorId),
  ]);

  const amistososConfirmados = perfil.eventos.filter(
    (e) => e.eventoId === null && e.origen === "confirmado",
  ).length;

  return {
    jugados: perfil.resumen.actividad.partidos,
    puntuados: perfil.partidosPuntuados,
    amistososConfirmados,
    gente: gente.size,
    companeros: perfil.companeros.length,
    meses: perfil.meses.length,
    mejorRacha:
      perfil.resumen.oficial.racha.tipo === "ganando"
        ? Math.max(perfil.resumen.oficial.racha.largo, perfil.resumen.oficial.racha.mejor)
        : perfil.resumen.oficial.racha.mejor,
    ascensos: perfil.cambiosDeDivision.filter((c) => c.tipo === "ascenso").length,
    // De las cuentas del perfil y no de `mejoresVictorias`, que está recortada a
    // cinco: contar sobre una lista para pintar da un máximo de cinco.
    gestas: perfil.gestas,
    contraMasFuertes: perfil.victoriasContraMasFuertes,
  };
}

/** De cada logro, cuánto lleva. Lo que decide si está sacado y cuánto falta. */
type Progreso = (cuentas: Cuentas) => number;

const PROGRESOS: Record<string, Progreso> = {
  primer_partido: (c) => c.jugados,
  diez_partidos: (c) => c.jugados,
  cincuenta_partidos: (c) => c.jugados,
  cien_partidos: (c) => c.jugados,
  seis_meses: (c) => c.meses,
  primer_amistoso: (c) => c.amistososConfirmados,
  diez_amistosos: (c) => c.amistososConfirmados,
  cincuenta_amistosos: (c) => c.amistososConfirmados,
  diez_personas: (c) => c.gente,
  veinticinco_personas: (c) => c.gente,
  cinco_companeros: (c) => c.companeros,
  sale_del_provisional: (c) => c.puntuados,
  racha_de_cinco: (c) => c.mejorRacha,
  primer_ascenso: (c) => c.ascensos,
  tres_ascensos: (c) => c.ascensos,
  primera_gesta: (c) => c.gestas,
  matagigantes: (c) => c.contraMasFuertes,
};

/**
 * El catálogo. Añadir un logro es añadir un objeto aquí y una línea en `PROGRESOS`.
 *
 * El reparto por familias no es decorativo: **doce de diecisiete se sacan sin ganar
 * un solo partido.** Si esa proporción se invierte, los logros dejan de ser la
 * recompensa del que aparece y se vuelven otro ranking.
 */
export const CATALOGO: Logro[] = [
  // ---------------------------------------------------------- constancia
  {
    id: "primer_partido",
    nombre: "Primer partido",
    descripcion: "Jugaste tu primer partido en Puntazo.",
    familia: "constancia",
    meta: 1,
  },
  {
    id: "diez_partidos",
    nombre: "Habitual",
    descripcion: "Diez partidos jugados.",
    familia: "constancia",
    meta: 10,
  },
  {
    id: "cincuenta_partidos",
    nombre: "De la casa",
    descripcion: "Cincuenta partidos jugados.",
    familia: "constancia",
    meta: 50,
  },
  {
    id: "cien_partidos",
    nombre: "Centenario",
    descripcion: "Cien partidos jugados.",
    familia: "constancia",
    meta: 100,
  },
  {
    id: "seis_meses",
    nombre: "Medio año",
    descripcion: "Jugaste en seis meses distintos.",
    familia: "constancia",
    meta: 6,
  },
  {
    id: "sale_del_provisional",
    nombre: "Rating de verdad",
    descripcion: "Quince partidos puntuados: tu rating deja de ser provisional.",
    familia: "constancia",
    meta: 15,
  },

  // ------------------------------------------------------------- el club
  {
    id: "diez_personas",
    nombre: "Conocido",
    descripcion: "Jugaste con diez personas distintas.",
    familia: "club",
    meta: 10,
  },
  {
    id: "veinticinco_personas",
    nombre: "Todo el club",
    descripcion: "Jugaste con veinticinco personas distintas.",
    familia: "club",
    meta: 25,
  },
  {
    id: "cinco_companeros",
    nombre: "Se juega con cualquiera",
    descripcion: "Cinco compañeros distintos.",
    familia: "club",
    meta: 5,
  },

  // -------------------------------------------------------- honestidad
  // Éstos son el corazón del asunto: el amistoso no puntúa hasta que los cuatro lo
  // confirman, y confirmar el resultado del rival no tiene ninguna otra recompensa.
  {
    id: "primer_amistoso",
    nombre: "Queda escrito",
    descripcion: "Tu primer amistoso confirmado por los cuatro.",
    familia: "honestidad",
    meta: 1,
  },
  {
    id: "diez_amistosos",
    nombre: "Palabra dada",
    descripcion: "Diez amistosos confirmados.",
    familia: "honestidad",
    meta: 10,
  },
  {
    id: "cincuenta_amistosos",
    nombre: "El que apunta",
    descripcion: "Cincuenta amistosos confirmados. Media liga vive de esto.",
    familia: "honestidad",
    meta: 50,
  },

  // ------------------------------------------------------------- gestas
  {
    id: "racha_de_cinco",
    nombre: "Cinco seguidos",
    descripcion: "Cinco partidos ganados de seguido.",
    familia: "gesta",
    meta: 5,
  },
  {
    id: "primer_ascenso",
    nombre: "Un escalón",
    descripcion: "Subiste de división por primera vez.",
    familia: "gesta",
    meta: 1,
  },
  {
    id: "tres_ascensos",
    nombre: "Tres escalones",
    descripcion: "Subiste de división tres veces.",
    familia: "gesta",
    meta: 3,
  },
  {
    id: "primera_gesta",
    nombre: "Nadie lo vio venir",
    descripcion: "Ganaste un partido que se te daba por perdido.",
    familia: "gesta",
    meta: 1,
  },
  {
    id: "matagigantes",
    nombre: "Matagigantes",
    descripcion: "Le ganaste a una pareja más fuerte que tú.",
    familia: "gesta",
    meta: 1,
  },
];

export type LogroConseguido = {
  logro: Logro;
  /** Cuánto lleva. */
  llevado: number;
  /** Cuánto falta. 0 si está sacado. */
  falta: number;
  conseguido: boolean;
  /** 0..1, para la barra. */
  fraccion: number;
};

/**
 * Qué tiene y qué le falta.
 *
 * Devuelve **todos** los logros, no sólo los conseguidos, y por eso la función se
 * llama así y no `logrosDe`: la mitad del valor de un logro es verlo antes de
 * tenerlo. Una lista que sólo enseña lo ya hecho no invita a hacer nada.
 */
export function logrosDelPerfil(perfil: Perfil): LogroConseguido[] {
  const cuentas = cuentasDe(perfil);

  return CATALOGO.map((logro) => {
    const meta = logro.meta ?? 1;
    const progreso = PROGRESOS[logro.id];
    const llevado = progreso === undefined ? 0 : progreso(cuentas);

    return {
      logro,
      llevado,
      falta: Math.max(0, meta - llevado),
      conseguido: llevado >= meta,
      fraccion: Math.min(1, meta === 0 ? 1 : llevado / meta),
    };
  });
}

/**
 * Los conseguidos primero, y entre los que faltan, los más cerca.
 *
 * Es el orden en que se mira: primero lo que se ha ganado, luego "te falta uno".
 * Un logro al 90 % arriba mueve más que veinte al 2 %.
 */
export function ordenados(logros: readonly LogroConseguido[]): LogroConseguido[] {
  return [...logros].sort(
    (x, y) =>
      Number(y.conseguido) - Number(x.conseguido) ||
      (x.conseguido
        ? // Entre los sacados, los más raros primero: los de meta más alta.
          (y.logro.meta ?? 1) - (x.logro.meta ?? 1)
        : y.fraccion - x.fraccion) ||
      x.logro.id.localeCompare(y.logro.id),
  );
}

export type Resumen = {
  conseguidos: number;
  total: number;
  /** Por familia, para poder decir "te faltan los de honestidad". */
  porFamilia: Record<Familia, { conseguidos: number; total: number }>;
  /** El más cerca de los que faltan, para enseñarlo aparte. */
  siguiente: LogroConseguido | null;
};

export function resumirLogros(logros: readonly LogroConseguido[]): Resumen {
  const porFamilia: Record<Familia, { conseguidos: number; total: number }> = {
    constancia: { conseguidos: 0, total: 0 },
    club: { conseguidos: 0, total: 0 },
    honestidad: { conseguidos: 0, total: 0 },
    gesta: { conseguidos: 0, total: 0 },
  };

  for (const entrada of logros) {
    const familia = porFamilia[entrada.logro.familia];
    familia.total++;
    if (entrada.conseguido) familia.conseguidos++;
  }

  const pendientes = logros.filter((l) => !l.conseguido);
  // El más avanzado, y a igualdad el que le falta menos en números absolutos: "te
  // falta un partido" es más accionable que "te falta el 8 %".
  const siguiente =
    pendientes.length === 0
      ? null
      : [...pendientes].sort((x, y) => y.fraccion - x.fraccion || x.falta - y.falta)[0];

  return {
    conseguidos: logros.filter((l) => l.conseguido).length,
    total: logros.length,
    porFamilia,
    siguiente,
  };
}

export const ETIQUETA_FAMILIA: Record<Familia, string> = {
  constancia: "Constancia",
  club: "Club",
  honestidad: "Palabra",
  gesta: "Gestas",
};
