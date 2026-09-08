/**
 * "Estos nombres parecen la misma persona".
 *
 * Un club llega con tres torneos ya jugados y una lista de nombres sueltos. Para
 * que la app del jugador tenga historial, alguien tiene que decir que "Nacho R."
 * del torneo de marzo es el mismo "Ignacio Rosales" del de abril.
 *
 * **Ese alguien es el club, no este fichero.** Aquí se ordenan candidatos y se
 * explica por qué, para que el encargado confirme con un toque en vez de leer
 * ciento veinte nombres. Nada de esto une nada solo: una unificación mal hecha
 * mezcla el historial de dos personas, y eso no se deshace bien.
 *
 * La señal más útil no es un parecido de texto, es una regla del propio torneo:
 * **dos inscritos del mismo torneo nunca son la misma persona.** Nadie juega un
 * americano contra sí mismo. Sale gratis y descarta la mitad de los falsos
 * positivos.
 */

import {
  compararApellidos,
  normalizar,
  normalizarTelefono,
  partirNombre,
  pilaCompatible,
} from "./nombres.ts";

/** Un inscrito de un torneo, tal y como lo tecleó el club. */
export type Inscrito = {
  id: string;
  tournamentId: string;
  nombre: string;
  telefono?: string | null;
};

/** Alguien que ya existe como persona. */
export type Persona = {
  id: string;
  nombre: string;
  apellido?: string | null;
  apodo?: string | null;
  telefono?: string | null;
  /** Torneos en los que ya se le ha reconocido. Sirve para la regla de arriba. */
  torneos?: readonly string[];
};

export type Candidato = {
  personaId: string;
  /** 0..1. No es una probabilidad: es un orden con umbral. */
  puntuacion: number;
  /** Por qué. Se enseña tal cual: un número a secas no se confirma con confianza. */
  motivos: string[];
};

// ------------------------------------------------------------------- pesos
//
// Son un punto de partida, no una verdad. Se afinan mirando lo que el club
// confirma y lo que descarta, que es el único dato que vale aquí.

export const PESOS = {
  telefono: 0.6,
  nombreEntero: 0.5,
  apellidoIgual: 0.3,
  apellidoInicial: 0.25,
  pilaIgual: 0.28,
  /**
   * Un pelo por debajo del nombre de pila exacto: la regla del prefijo, que es
   * la que reconoce los diminutivos regulares, también empareja "Ana" con
   * "Anabel". Acierta mucho más de lo que falla, pero no es lo mismo.
   */
  pilaApodo: 0.25,
  /** Dos teléfonos distintos son la señal más fuerte de que no es la misma persona. */
  telefonoDistinto: -0.4,
};

/** Por debajo de esto no se propone: el ruido cansa más que ayuda. */
export const UMBRAL_PROPUESTA = 0.45;

/** Por encima de esto la pantalla puede venir ya marcada, a falta de confirmar. */
export const UMBRAL_CLARO = 0.8;

/**
 * Techo cuando coincide el teléfono pero el apellido no.
 *
 * Es el caso de la pareja o de los dos hermanos que se apuntan con el móvil de
 * casa. Sin este techo, el teléfono solo bastaría para proponer la unión de dos
 * personas distintas, que es el peor error posible aquí.
 */
const TECHO_MISMO_TELEFONO_OTRO_APELLIDO = 0.5;

// ------------------------------------------------------------------ comparar

/** Cuánto se parecen un inscrito y una persona, y por qué. */
export function comparar(inscrito: Inscrito, persona: Persona): Candidato {
  const motivos: string[] = [];
  let puntuacion = 0;

  const delInscrito = partirNombre(inscrito.nombre);
  const dePersona = partirNombre(
    [persona.nombre, persona.apellido ?? ""].join(" ").trim(),
  );

  const telA = normalizarTelefono(inscrito.telefono ?? null);
  const telB = normalizarTelefono(persona.telefono ?? null);
  const mismoTelefono = telA !== null && telA === telB;

  if (mismoTelefono) {
    puntuacion += PESOS.telefono;
    motivos.push("mismo teléfono");
  } else if (telA !== null && telB !== null) {
    puntuacion += PESOS.telefonoDistinto;
    motivos.push("teléfonos distintos");
  }

  if (
    normalizar(inscrito.nombre) ===
    normalizar([persona.nombre, persona.apellido ?? ""].join(" "))
  ) {
    puntuacion += PESOS.nombreEntero;
    motivos.push("mismo nombre completo");
  }

  const apellidos = compararApellidos(delInscrito.apellidos, dePersona.apellidos);
  if (apellidos === "igual") {
    puntuacion += PESOS.apellidoIgual;
    motivos.push("mismo apellido");
  } else if (apellidos === "inicial") {
    puntuacion += PESOS.apellidoInicial;
    motivos.push("el apellido encaja con la inicial");
  }

  const apodo = persona.apodo ? normalizar(persona.apodo) : "";
  if (delInscrito.pila !== "" && delInscrito.pila === dePersona.pila) {
    puntuacion += PESOS.pilaIgual;
    motivos.push("mismo nombre de pila");
  } else if (apodo !== "" && pilaCompatible(delInscrito.pila, apodo)) {
    puntuacion += PESOS.pilaApodo;
    motivos.push(`se le conoce como ${persona.apodo}`);
  } else if (pilaCompatible(delInscrito.pila, dePersona.pila)) {
    puntuacion += PESOS.pilaApodo;
    motivos.push("el nombre encaja como apodo");
  }

  if (mismoTelefono && apellidos === "distinto") {
    puntuacion = Math.min(puntuacion, TECHO_MISMO_TELEFONO_OTRO_APELLIDO);
    motivos.push("ojo: mismo teléfono pero otro apellido, puede ser un familiar");
  }

  return {
    personaId: persona.id,
    puntuacion: Math.max(0, Math.min(1, puntuacion)),
    motivos,
  };
}

/**
 * A quién se parece este inscrito, de mejor a peor.
 *
 * Descarta a quien ya está en ese mismo torneo: si esa persona ya tiene una fila
 * en este torneo, este inscrito es otra.
 */
export function proponerPersonas(
  inscrito: Inscrito,
  personas: readonly Persona[],
  umbral: number = UMBRAL_PROPUESTA,
): Candidato[] {
  return personas
    .filter((p) => !(p.torneos ?? []).includes(inscrito.tournamentId))
    .map((p) => comparar(inscrito, p))
    .filter((c) => c.puntuacion >= umbral)
    .sort((a, b) => b.puntuacion - a.puntuacion || a.personaId.localeCompare(b.personaId));
}

// ------------------------------------------------------------------ agrupar

export type Grupo = {
  /** Inscritos que parecen la misma persona, en el orden en que llegaron. */
  inscritos: Inscrito[];
  /** El nombre más largo del grupo: el que más información tiene. */
  nombrePropuesto: string;
  /** La puntuación más floja que sostiene el grupo. Cuanto más baja, más mirarlo. */
  confianza: number;
};

/**
 * El primer día no hay ninguna persona creada todavía: sólo nombres sueltos
 * repartidos por varios torneos. Esto los junta para que el club cree una
 * persona por grupo en vez de ciento veinte a mano.
 *
 * Enlace simple y voraz: un inscrito entra en el primer grupo con el que encaja.
 * No es un agrupamiento óptimo y no hace falta que lo sea — el club ve los
 * grupos y los parte con un toque. Lo que sí se respeta siempre es la regla del
 * torneo: nadie se agrupa con alguien de su mismo torneo.
 */
export function agruparInscritos(
  inscritos: readonly Inscrito[],
  umbral: number = UMBRAL_PROPUESTA,
): Grupo[] {
  const grupos: Grupo[] = [];

  for (const inscrito of inscritos) {
    let encajado = false;

    for (const grupo of grupos) {
      if (grupo.inscritos.some((x) => x.tournamentId === inscrito.tournamentId)) {
        continue;
      }

      // Contra todos los del grupo: basta con que encaje con el peor para que
      // el grupo siga siendo coherente.
      const puntuaciones = grupo.inscritos.map(
        (x) => comparar(inscrito, comoPersona(x)).puntuacion,
      );
      const peor = Math.min(...puntuaciones);
      if (peor < umbral) continue;

      grupo.inscritos.push(inscrito);
      grupo.confianza = Math.min(grupo.confianza, peor);
      if (inscrito.nombre.length > grupo.nombrePropuesto.length) {
        grupo.nombrePropuesto = inscrito.nombre;
      }
      encajado = true;
      break;
    }

    if (!encajado) {
      grupos.push({
        inscritos: [inscrito],
        nombrePropuesto: inscrito.nombre,
        confianza: 1,
      });
    }
  }

  return grupos;
}

/** Un inscrito visto como persona, para poder compararlo con otro inscrito. */
function comoPersona(inscrito: Inscrito): Persona {
  const partido = partirNombre(inscrito.nombre);
  return {
    id: inscrito.id,
    nombre: partido.pila,
    apellido: partido.apellidos.join(" "),
    telefono: inscrito.telefono ?? null,
  };
}
