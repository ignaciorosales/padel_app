/**
 * Comparar nombres de pádel escritos a mano.
 *
 * Los inscritos de un torneo son texto libre: los teclea el encargado el sábado
 * por la mañana, con prisa, desde el móvil. Salen cosas como "Nacho R.",
 * "IGNACIO ROSALES", "Rosales, Ignacio" o "ignacio  rosalés", y las cuatro son
 * la misma persona.
 *
 * Aquí sólo están las piezas de comparar. Quién es quién se decide en
 * `unificar.ts`, y la última palabra la tiene el club: esto propone, no une.
 */

// ------------------------------------------------------------- normalizar

/**
 * Minúsculas, sin tildes, sin puntuación y con un solo espacio.
 *
 * Descomponer y quitar los diacríticos también convierte la eñe en ene, y eso
 * es justo lo que hace falta: "Muñoz" y "Munoz" se teclean indistintamente.
 */
export function normalizar(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[.,_-]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export type NombrePartido = {
  /** Nombre de pila, ya normalizado. */
  pila: string;
  /** Apellidos, ya normalizados. Puede estar vacío: mucha gente se apunta sólo con el nombre. */
  apellidos: string[];
};

/**
 * Parte "Ignacio Rosales Pérez" en pila y apellidos.
 *
 * Con coma se entiende al revés ("Rosales, Ignacio"), que es como sale de
 * algunas listas. Sin coma, la primera palabra es el nombre: un nombre compuesto
 * ("Juan Manuel Rosales") se parte mal, y se acepta — quien decide es el club, y
 * el apellido, que es la señal fuerte, se mantiene intacto.
 */
export function partirNombre(texto: string): NombrePartido {
  const conComa = texto.includes(",");
  const limpio = normalizar(texto);
  if (limpio === "") return { pila: "", apellidos: [] };

  const trozos = limpio.split(" ");
  if (conComa) {
    // "Rosales, Ignacio" → los apellidos van delante.
    const corte = normalizar(texto.slice(0, texto.indexOf(","))).split(" ");
    const resto = trozos.slice(corte.length);
    return { pila: resto[0] ?? "", apellidos: corte };
  }
  return { pila: trozos[0], apellidos: trozos.slice(1) };
}

// --------------------------------------------------------------- teléfono

/**
 * Un teléfono comparable: sólo los dígitos, y sólo los últimos ocho.
 *
 * "+598 99 123 456", "099123456" y "099 123 456" son el mismo número escrito de
 * tres formas. Quedarse con la cola evita tener que saber de prefijos de país,
 * que es un pozo sin fondo y no aporta nada aquí.
 */
export function normalizarTelefono(telefono: string | null): string | null {
  if (!telefono) return null;
  const digitos = telefono.replace(/\D/g, "");
  if (digitos.length < 6) return null;
  return digitos.slice(-8);
}

// ------------------------------------------------------------ diminutivos

/**
 * Diminutivos que no se pueden deducir del nombre.
 *
 * La mayoría sí se deducen —Santi de Santiago, Fede de Federico— y de eso se
 * encarga la regla del prefijo. Aquí sólo están los irregulares, que son los
 * que se usan de verdad en la pista. Es una lista para ampliar, no un algoritmo.
 */
export const DIMINUTIVOS: Record<string, string[]> = {
  ignacio: ["nacho"],
  jose: ["pepe", "pepo"],
  francisco: ["paco", "pancho", "fran"],
  luis: ["lucho"],
  martin: ["tincho"],
  enrique: ["quique", "kike"],
  eduardo: ["lalo"],
  jesus: ["chus"],
  alejandro: ["ale", "jano"],
  antonio: ["tono", "toni"],
  guillermo: ["guille", "memo"],
  roberto: ["beto", "tito"],
  ricardo: ["richi"],
  mercedes: ["meche"],
  dolores: ["lola"],
  concepcion: ["concha"],
  rosario: ["charo"],
  soledad: ["sole"],
};

const PREFIJO_MINIMO = 3;

/** ¿`corto` puede ser el diminutivo de `largo`? La relación no es simétrica. */
export function esDiminutivo(corto: string, largo: string): boolean {
  if (corto === "" || largo === "") return false;
  if (DIMINUTIVOS[largo]?.includes(corto)) return true;

  // Santi → Santiago, Javi → Javier, Sebas → Sebastián. Con al menos tres
  // letras: "a" no es el diminutivo de "Andrés".
  return (
    corto.length >= PREFIJO_MINIMO &&
    corto.length < largo.length &&
    largo.startsWith(corto)
  );
}

/** ¿Son el mismo nombre de pila, admitiendo apodos por cualquiera de los dos lados? */
export function pilaCompatible(a: string, b: string): boolean {
  if (a === "" || b === "") return false;
  return a === b || esDiminutivo(a, b) || esDiminutivo(b, a);
}

/** "r" contra "rosales": una inicial suelta, que es como se apunta media pista. */
export function esInicialDe(inicial: string, palabra: string): boolean {
  return inicial.length === 1 && palabra.length > 1 && palabra.startsWith(inicial);
}

/**
 * Cómo de bien encajan dos juegos de apellidos.
 *
 * Devuelve "igual" cuando comparten un apellido entero, "inicial" cuando uno es
 * la inicial del otro ("R." contra "Rosales"), "ninguno" cuando alguno de los
 * dos no tiene apellido —no es un desacuerdo, es una falta de datos— y
 * "distinto" cuando los dos tienen y no se parecen en nada.
 */
export function compararApellidos(
  a: string[],
  b: string[],
): "igual" | "inicial" | "ninguno" | "distinto" {
  if (a.length === 0 || b.length === 0) return "ninguno";
  for (const x of a) {
    for (const y of b) {
      if (x === y) return "igual";
    }
  }
  for (const x of a) {
    for (const y of b) {
      if (esInicialDe(x, y) || esInicialDe(y, x)) return "inicial";
    }
  }
  return "distinto";
}
