/**
 * La pantalla de unificación, sin pintar nada.
 *
 * `unificar.ts` sabe comparar dos nombres. Esto decide **qué se le enseña al
 * encargado del club y en qué orden**, que es una pregunta distinta y es donde se
 * gana o se pierde la pantalla: hay ciento veinte nombres, quince minutos de
 * paciencia, y una unificación mal hecha mezcla el historial de dos personas y no
 * se deshace bien.
 *
 * Tres decisiones de producto viven aquí:
 *
 * 1. **Primero lo que ya existe, luego lo que hay que crear.** Si el club ya tiene
 *    personas, la pregunta fácil es "¿este Nacho R. es el Ignacio Rosales que ya
 *    tienes?". Sólo cuando no se parece a nadie toca crear.
 * 2. **Lo dudoso primero, no lo claro.** Al revés de lo que parece: los claros se
 *    confirman en bloque de un tirón, y dejar los dudosos para el final significa
 *    que nadie los mira nunca.
 * 3. **Nunca se une nada solo**, ni con un 0,99. Lo que hace el umbral alto es
 *    venir marcado, no confirmarse. Quien decide es el club.
 */

import {
  agruparInscritos,
  proponerPersonas,
  UMBRAL_CLARO,
  UMBRAL_PROPUESTA,
  type Candidato,
  type Grupo,
  type Inscrito,
  type Persona,
} from "./unificar.ts";

/** Una fila de `tournament_players` con lo que la pantalla necesita. */
export type FilaDeInscrito = {
  id: string;
  tournament_id: string;
  nombre: string;
  telefono: string | null;
  player_id: string | null;
};

/** Una fila de `players`. */
export type FilaDePersona = {
  id: string;
  nombre: string;
  apellido: string | null;
  apodo: string | null;
  telefono: string | null;
};

/** Un inscrito sin unificar, con a quién se parece y por qué. */
export type Pendiente = {
  inscrito: Inscrito;
  candidatos: Candidato[];
  /**
   * True cuando el primer candidato está por encima del umbral claro y no hay un
   * segundo pisándole los talones.
   *
   * La segunda condición es la que importa de verdad: dos hermanos con el mismo
   * apellido y el mismo teléfono de casa puntúan los dos alto, y venir marcado
   * con el primero de los dos es exactamente el error que no se deshace.
   */
  claro: boolean;
};

export type EstadoDeUnificacion = {
  /** Sin unificar, los dudosos primero. */
  pendientes: Pendiente[];
  /** Grupos de inscritos que parecen la misma persona nueva. */
  grupos: Grupo[];
  /** Cuántos inscritos del club ya tienen persona. */
  unificados: number;
  total: number;
  /** Los que no se parecen a nadie ni se agrupan con nadie: hay que crearlos. */
  sueltos: number;
};

/** Distancia mínima al segundo candidato para dar algo por claro. */
export const MARGEN_SOBRE_EL_SEGUNDO = 0.15;

function comoInscrito(fila: FilaDeInscrito): Inscrito {
  return {
    id: fila.id,
    tournamentId: fila.tournament_id,
    nombre: fila.nombre,
    telefono: fila.telefono,
  };
}

/**
 * Las personas, con los torneos donde ya se les ha reconocido.
 *
 * Sin esa lista, `proponerPersonas` no puede aplicar la regla que más falsos
 * positivos descarta: dos inscritos del mismo torneo nunca son la misma persona,
 * porque nadie juega un americano contra sí mismo.
 */
export function personasConSusTorneos(
  personas: readonly FilaDePersona[],
  inscritos: readonly FilaDeInscrito[],
): Persona[] {
  const torneosPor = new Map<string, string[]>();
  for (const fila of inscritos) {
    if (fila.player_id === null) continue;
    const suyos = torneosPor.get(fila.player_id) ?? [];
    suyos.push(fila.tournament_id);
    torneosPor.set(fila.player_id, suyos);
  }

  return personas.map((p) => ({
    id: p.id,
    nombre: p.nombre,
    apellido: p.apellido,
    apodo: p.apodo,
    telefono: p.telefono,
    torneos: torneosPor.get(p.id) ?? [],
  }));
}

/**
 * Todo lo que la pantalla enseña, de las dos consultas.
 *
 * El orden de `pendientes` es deliberado y no es el alfabético: **lo dudoso
 * primero.** Los claros se despachan en bloque con un botón; los dudosos son los
 * que necesitan a una persona mirándolos, y si van al final nadie llega.
 */
export function estadoDeUnificacion(
  inscritos: readonly FilaDeInscrito[],
  personas: readonly FilaDePersona[],
  umbral: number = UMBRAL_PROPUESTA,
): EstadoDeUnificacion {
  const conTorneos = personasConSusTorneos(personas, inscritos);
  const sinUnificar = inscritos.filter((i) => i.player_id === null);

  const pendientes: Pendiente[] = sinUnificar.map((fila) => {
    const inscrito = comoInscrito(fila);
    const candidatos = proponerPersonas(inscrito, conTorneos, umbral);
    const primero = candidatos[0];
    const segundo = candidatos[1];

    return {
      inscrito,
      candidatos,
      claro:
        primero !== undefined &&
        primero.puntuacion >= UMBRAL_CLARO &&
        (segundo === undefined ||
          primero.puntuacion - segundo.puntuacion >= MARGEN_SOBRE_EL_SEGUNDO),
    };
  });

  // Lo dudoso primero: con candidatos pero sin uno claro. Después los claros, que
  // son un repaso rápido. Al final los que no se parecen a nadie, que no se
  // resuelven aquí sino creando persona.
  const rango = (p: Pendiente): number => {
    if (p.candidatos.length === 0) return 2;
    return p.claro ? 1 : 0;
  };

  pendientes.sort(
    (x, y) =>
      rango(x) - rango(y) ||
      (y.candidatos[0]?.puntuacion ?? 0) - (x.candidatos[0]?.puntuacion ?? 0) ||
      x.inscrito.nombre.localeCompare(y.inscrito.nombre, "es"),
  );

  // Los grupos se calculan sólo con los que no se parecen a nadie existente: si
  // ya hay una persona candidata, proponer además crear una nueva es ofrecer dos
  // caminos para lo mismo, y uno de los dos duplica la ficha.
  const huerfanos = pendientes
    .filter((p) => p.candidatos.length === 0)
    .map((p) => p.inscrito);

  const grupos = agruparInscritos(huerfanos, umbral).filter(
    // Un grupo de uno no es un grupo: es un nombre suelto, y se cuenta aparte.
    (g) => g.inscritos.length > 1,
  );

  const enGrupo = new Set(grupos.flatMap((g) => g.inscritos.map((i) => i.id)));

  return {
    pendientes,
    grupos,
    unificados: inscritos.length - sinUnificar.length,
    total: inscritos.length,
    sueltos: huerfanos.filter((i) => !enGrupo.has(i.id)).length,
  };
}

/**
 * Cómo se llama una persona en una línea.
 *
 * El apodo entre comillas y no en lugar del nombre: en la pantalla de unificación
 * hace falta ver las dos cosas — el nombre del documento es lo que se parece al
 * del torneo, y el apodo es lo que el encargado reconoce.
 */
export function comoSeLlama(persona: FilaDePersona): string {
  const nombre = [persona.nombre, persona.apellido].filter(Boolean).join(" ");
  return persona.apodo ? `${nombre} «${persona.apodo}»` : nombre;
}

/**
 * El nombre que se le pone a una persona nueva creada de un grupo.
 *
 * El más largo del grupo, que es el que más información tiene: entre "Nacho R." y
 * "Ignacio Rosales", la ficha se crea con el segundo.
 */
export function nombreYApellidoDe(texto: string): {
  nombre: string;
  apellido: string | null;
} {
  const partes = texto.trim().split(/\s+/).filter(Boolean);
  if (partes.length === 0) return { nombre: texto.trim(), apellido: null };
  if (partes.length === 1) return { nombre: partes[0], apellido: null };
  return { nombre: partes[0], apellido: partes.slice(1).join(" ") };
}

export type { Candidato, Grupo, Inscrito, Persona };
