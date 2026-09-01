/**
 * El cuadro eliminatorio: cuartos, semifinal y final.
 *
 * Es lo único de todo el programa que **no se puede generar de antemano**. Un
 * americano y una fase de grupos salen enteros de una vez porque se sabe quién
 * juega contra quién antes de empezar; aquí la semifinal no existe hasta que
 * acaban los cuartos.
 *
 * Lo que sí se puede hacer —y es lo que se hace— es dibujar el cuadro vacío
 * completo desde el principio, con los huecos sin rellenar, y que los ganadores
 * los vayan ocupando. Así el club ve el cuadro entero desde el primer momento,
 * que es exactamente lo que se dibuja en una pizarra.
 *
 * Regla de propagación, la única que hay que entender: el ganador del partido
 * `n` de una ronda va al partido `floor(n / 2)` de la siguiente, al lado A si
 * `n` es par y al lado B si es impar.
 */

import type { ParejaId } from "./parejas.ts";

export type Fase = string;

/**
 * Cómo se llama una ronda según cuántos partidos tiene.
 *
 * Llega hasta 64 partidos, es decir un cuadro de 128 parejas — 256 personas.
 * No es una cifra elegida por gusto: un torneo de 77 parejas repartidas en
 * grupos, con dos clasificadas por grupo, se planta en 40 y necesita un cuadro
 * de 64. Quedarse en 32 dejaba fuera torneos que un club monta de verdad.
 */
const NOMBRE_DE_FASE: Record<number, string> = {
  1: "final",
  2: "semifinal",
  4: "cuartos",
  8: "octavos",
  16: "dieciseisavos",
  32: "treintaidosavos",
  64: "sesentaicuatroavos",
};

/** Partidos en la primera ronda del cuadro más grande que se admite. */
export const MAX_PARTIDOS_PRIMERA_RONDA = 64;

export type SlotCuadro = {
  fase: Fase;
  /** 0..n-1 dentro de su fase. Es lo que decide a dónde avanza el ganador. */
  orden: number;
  /** `null` mientras no se sepa quién lo ocupa. */
  parejaA: ParejaId | null;
  parejaB: ParejaId | null;
};

export type ResultadoSlot = { juegosA: number; juegosB: number };

/** La llave con la que se identifica un partido del cuadro. */
export function llave(fase: Fase, orden: number): string {
  return `${fase}:${orden}`;
}

export function faseDe(partidos: number): Fase {
  const nombre = NOMBRE_DE_FASE[partidos];
  if (!nombre) {
    throw new Error(
      `Un cuadro de ${partidos * 2} parejas es demasiado grande. ` +
        `El máximo son ${MAX_PARTIDOS_PRIMERA_RONDA * 2} parejas.`,
    );
  }
  return nombre;
}

/**
 * Las fases de un cuadro en orden cronológico, deducidas del propio cuadro.
 *
 * Se cuenta cuántos partidos tiene cada fase y se ordena de más a menos: la
 * ronda con más partidos es siempre la primera y la de uno solo es la final.
 * Deducirlo en vez de leerlo de una lista fija es lo que permite que añadir un
 * tamaño de cuadro nuevo sea una línea en NOMBRE_DE_FASE y nada más.
 */
export function fasesEnOrden(slots: SlotCuadro[]): Fase[] {
  const cuantos = new Map<Fase, number>();
  for (const s of slots) cuantos.set(s.fase, (cuantos.get(s.fase) ?? 0) + 1);

  return [...cuantos.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([fase]) => fase);
}

/**
 * El orden clásico de siembra de un cuadro.
 *
 * Con 4: [0, 3, 1, 2] — el 1º juega contra el 4º y el 2º contra el 3º. Lo
 * importante no es sólo eso: es que el 1º y el 2º caen en mitades opuestas y
 * por tanto no pueden cruzarse antes de la final. Sembrar a boleo permitiría
 * una semifinal entre los dos mejores y una final entre el tercero y el cuarto.
 */
export function ordenSiembra(tamano: number): number[] {
  if (tamano <= 1) return [0];

  const mitad = ordenSiembra(tamano / 2);
  const salida: number[] = [];

  for (const s of mitad) {
    salida.push(s);
    salida.push(tamano - 1 - s);
  }

  return salida;
}

/** La potencia de dos igual o mayor: 6 parejas juegan un cuadro de 8. */
function tamanoDelCuadro(parejas: number): number {
  let n = 1;
  while (n < parejas) n *= 2;
  return n;
}

/**
 * Dibuja el cuadro entero a partir de las parejas clasificadas, ya ordenadas
 * por siembra (las primeras son las mejores).
 *
 * Cuando no son una potencia de dos, los huecos que sobran son **byes**: le
 * tocan a los mejor sembrados y su rival aparece como `null`. Un bye no se
 * juega, así que el que lo tiene ya está en la ronda siguiente desde el minuto
 * cero — y el cuadro lo enseña así, sin obligar a nadie a meter un resultado
 * inventado.
 */
export function generarCuadro(clasificados: ParejaId[]): SlotCuadro[] {
  if (clasificados.length < 2) {
    throw new Error("Hacen falta al menos 2 parejas para un cuadro final.");
  }

  const tamano = tamanoDelCuadro(clasificados.length);
  const siembra = ordenSiembra(tamano);
  const slots: SlotCuadro[] = [];

  // Primera ronda: los sembrados, emparejados de dos en dos.
  const primera = faseDe(tamano / 2);
  for (let i = 0; i < tamano / 2; i++) {
    slots.push({
      fase: primera,
      orden: i,
      parejaA: clasificados[siembra[i * 2]] ?? null,
      parejaB: clasificados[siembra[i * 2 + 1]] ?? null,
    });
  }

  // El resto del cuadro, vacío.
  for (let partidos = tamano / 4; partidos >= 1; partidos /= 2) {
    const fase = faseDe(partidos);
    for (let i = 0; i < partidos; i++) {
      slots.push({ fase, orden: i, parejaA: null, parejaB: null });
    }
  }

  // Los byes avanzan solos: nadie tiene que jugar contra nadie.
  return propagar(slots, new Map());
}

/**
 * Quién gana un partido del cuadro. `null` si aún no se puede saber.
 *
 * `esPrimeraRonda` no es un detalle: un lado vacío significa dos cosas
 * distintas según dónde esté. En la primera ronda es un **bye** —no hay rival,
 * se pasa sin jugar—, pero en semifinales es **un hueco por decidir**, porque
 * los cuartos todavía no han acabado. Tratarlos igual metería a alguien en la
 * final por un partido que nadie ha jugado.
 *
 * Un empate no decide: en una eliminatoria alguien tiene que pasar, y eso lo
 * arregla el club corrigiendo el resultado.
 */
export function ganadorDe(
  slot: SlotCuadro,
  resultado: ResultadoSlot | undefined,
  esPrimeraRonda = false,
): ParejaId | null {
  const { parejaA, parejaB } = slot;

  if (esPrimeraRonda) {
    if (parejaA && !parejaB) return parejaA;
    if (parejaB && !parejaA) return parejaB;
  }

  if (!parejaA || !parejaB || !resultado) return null;

  if (resultado.juegosA > resultado.juegosB) return parejaA;
  if (resultado.juegosB > resultado.juegosA) return parejaB;
  return null;
}

/**
 * Rellena el cuadro con los ganadores que ya se conocen.
 *
 * Se recalcula entero cada vez a partir de los resultados en vez de ir
 * escribiendo el avance a mano. Así corregir un resultado de cuartos arrastra
 * la corrección hasta la final sola, que es justo donde un cuadro llevado a
 * mano se desincroniza y acaba con dos parejas creyendo que juegan la final.
 */
export function propagar(
  slots: SlotCuadro[],
  resultados: Map<string, ResultadoSlot>,
): SlotCuadro[] {
  const cuadro = slots.map((s) => ({ ...s }));
  const fases = fasesEnOrden(cuadro);

  for (let i = 0; i < fases.length - 1; i++) {
    const actual = cuadro.filter((s) => s.fase === fases[i]);
    const siguiente = fases[i + 1];

    for (const slot of actual) {
      const gana = ganadorDe(
        slot,
        resultados.get(llave(slot.fase, slot.orden)),
        i === 0,
      );

      const destino = cuadro.find(
        (s) => s.fase === siguiente && s.orden === Math.floor(slot.orden / 2),
      );
      if (!destino) continue;

      if (slot.orden % 2 === 0) destino.parejaA = gana;
      else destino.parejaB = gana;
    }
  }

  return cuadro;
}

/**
 * Recalcula el cuadro **y tira los resultados que han dejado de valer**.
 *
 * Propagar una sola vez no basta, y el motivo no es evidente: si al corregir
 * unos cuartos cambia quién juega la semifinal, el resultado que esa semifinal
 * ya tenía era de otras parejas y no sirve — pero propagar lo habría usado ya
 * para decidir quién llega a la final. Borrarlo invalida lo que viene detrás,
 * así que hay que volver a propagar, y otra vez, hasta que nada cambie.
 *
 * Termina siempre: cada vuelta descarta al menos un resultado y son finitos.
 *
 * @param guardados Lo que hay en la base de datos, con sus ocupantes actuales.
 *                  La primera ronda es la siembra y no se toca nunca.
 * @returns El cuadro ya propagado y los resultados que siguen siendo válidos.
 */
export function recalcularCuadro(
  guardados: SlotCuadro[],
  resultados: Map<string, ResultadoSlot>,
): { cuadro: SlotCuadro[]; resultados: Map<string, ResultadoSlot> } {
  const fases = fasesEnOrden(guardados);
  const primera = fases[0];

  const base: SlotCuadro[] = guardados.map((s) => ({
    ...s,
    parejaA: s.fase === primera ? s.parejaA : null,
    parejaB: s.fase === primera ? s.parejaB : null,
  }));

  const vivos = new Map(resultados);
  let cuadro = propagar(base, vivos);

  // Cota de seguridad: nunca hacen falta más vueltas que resultados hay.
  for (let vuelta = 0; vuelta <= resultados.size; vuelta++) {
    let cambiado = false;

    for (const slot of cuadro) {
      if (slot.fase === primera) continue;

      const guardado = guardados.find(
        (g) => g.fase === slot.fase && g.orden === slot.orden,
      );
      if (!guardado) continue;

      const cambiaronLosOcupantes =
        guardado.parejaA !== slot.parejaA || guardado.parejaB !== slot.parejaB;

      const clave = llave(slot.fase, slot.orden);
      if (cambiaronLosOcupantes && vivos.has(clave)) {
        vivos.delete(clave);
        cambiado = true;
      }
    }

    if (!cambiado) break;
    cuadro = propagar(base, vivos);
  }

  return { cuadro, resultados: vivos };
}

/** La pareja campeona, cuando la final ya tiene resultado. */
export function campeon(
  slots: SlotCuadro[],
  resultados: Map<string, ResultadoSlot>,
): ParejaId | null {
  const final = slots.find((s) => s.fase === "final");
  if (!final) return null;
  return ganadorDe(final, resultados.get(llave("final", final.orden)));
}
