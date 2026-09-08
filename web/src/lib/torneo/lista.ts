/**
 * Parseo de la lista de inscritos que el organizador pega desde WhatsApp.
 *
 * El club ya tiene los nombres escritos en algún sitio; obligarle a teclearlos
 * otra vez uno a uno es la diferencia entre que use el panel y que vuelva al
 * cuaderno. Así que aquí se acepta lo que salga de un grupo: listas numeradas,
 * viñetas, teléfonos pegados al nombre y líneas de conversación exportada.
 */

export type JugadorPegado = {
  nombre: string;
  telefono: string | null;
};

/** "1. ", "12) ", "- ", "• ", "* " al principio de la línea. */
const MARCA_DE_LISTA = /^\s*(?:\d{1,3}\s*[.)\-–—]?\s+|\d{1,3}[.)]\s*|[-•*·▪]\s*)/;

/** "[12/03/2026, 10:04] Juan Pérez: me apunto" → "Juan Pérez" */
const LINEA_DE_CHAT =
  /^\[?\s*\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}[,\s]*\d{1,2}:\d{2}(?::\d{2})?\s*(?:[ap]\.?\s?m\.?)?\s*\]?\s*-?\s*([^:]{2,60}):/i;

/** Teléfono al final: "Juan 600 12 34 56", "Ana +34 600123456". */
const TELEFONO_FINAL = /[\s(]*(\+?\d[\d\s().\-]{6,})\s*$/;

function limpiarNombre(bruto: string): string {
  return bruto
    .replace(/\s+/g, " ")
    .replace(/^[\s"'“”‘’]+|[\s"'“”‘’,;:.\-–—]+$/g, "")
    .trim();
}

function normalizar(nombre: string): string {
  return nombre
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "");
}

export type ParejaPegada = { uno: string; dos: string };

export type ProblemaPareja = { linea: string; motivo: string };

export type ListaDeParejas = {
  parejas: ParejaPegada[];
  /** Líneas que no se pudieron leer. Se enseñan: nadie debe desaparecer en silencio. */
  problemas: ProblemaPareja[];
};

/**
 * Cómo separa la gente los dos nombres de una pareja, en orden de preferencia.
 *
 * La barra va primero porque es la que no falla nunca. La coma va la última a
 * propósito: en una lista de jugadores sueltos "Apellido, Nombre" es una
 * persona, y sólo cuando ningún separador más claro ha funcionado tiene
 * sentido apostar a que separa dos.
 */
const SEPARADORES_DE_PAREJA: RegExp[] = [
  /\s*[/|]\s*/,
  /\s+[yYeE]\s+/,
  /\s*[&+]\s*/,
  /\s+[-–—]\s+/,
  /\s*,\s*/,
];

/**
 * Lee una lista de parejas pegada, una por línea: "Ana / Luis", "Ana y Luis",
 * "Ana - Luis"…
 *
 * A diferencia de la lista de jugadores, aquí una línea mal escrita **no se
 * descarta en silencio**. Si alguien pega 16 líneas y salen 15 parejas, sin
 * decir cuál se cayó el organizador se entera el sábado, cuando falta una
 * pareja en el cuadro.
 */
export function parsearParejas(texto: string): ListaDeParejas {
  const parejas: ParejaPegada[] = [];
  const problemas: ProblemaPareja[] = [];
  const vistos = new Map<string, string>();

  for (const bruta of texto.split(/\r?\n/)) {
    let resto = bruta.trim();
    if (!resto) continue;

    // Al revés que en la lista de jugadores: allí quien escribe "me apunto" ES
    // el inscrito, así que vale el remitente. Aquí la pareja va en el cuerpo
    // del mensaje ("Recepción: Ana / Luis"), así que se tira el encabezado y
    // se queda lo de después.
    const chat = resto.match(LINEA_DE_CHAT);
    if (chat) {
      const cuerpo = resto.slice(chat[0].length).trim();
      resto = cuerpo || chat[1];
    }

    resto = resto.replace(MARCA_DE_LISTA, "").trim();
    if (!resto) continue;

    let trozos: string[] | null = null;
    for (const separador of SEPARADORES_DE_PAREJA) {
      const partes = resto
        .split(separador)
        .map(limpiarNombre)
        .filter((n) => n && /\p{L}/u.test(n));

      if (partes.length >= 2) {
        trozos = partes;
        break;
      }
    }

    if (!trozos) {
      problemas.push({ linea: bruta.trim(), motivo: "falta el compañero" });
      continue;
    }

    if (trozos.length > 2) {
      problemas.push({
        linea: bruta.trim(),
        motivo: `${trozos.length} nombres en una línea; una pareja son dos`,
      });
      continue;
    }

    const [uno, dos] = trozos;

    if (normalizar(uno) === normalizar(dos)) {
      problemas.push({ linea: bruta.trim(), motivo: "el mismo nombre dos veces" });
      continue;
    }

    const repetido = [uno, dos].find((n) => vistos.has(normalizar(n)));
    if (repetido) {
      problemas.push({
        linea: bruta.trim(),
        motivo: `${repetido} ya juega en otra pareja`,
      });
      continue;
    }

    vistos.set(normalizar(uno), uno);
    vistos.set(normalizar(dos), dos);
    parejas.push({ uno, dos });
  }

  return { parejas, problemas };
}

export function parsearLista(texto: string): JugadorPegado[] {
  if (!texto.trim()) return [];

  let lineas = texto.split(/\r?\n/);

  // Todo en una sola línea separado por comas: "Juan, Ana, Luis".
  // Sólo se parte por comas en ese caso, para no romper un "Apellido, Nombre"
  // dentro de una lista de varias líneas.
  const unaSolaLinea = lineas.filter((l) => l.trim()).length === 1;
  if (unaSolaLinea && texto.includes(",") && !LINEA_DE_CHAT.test(texto.trim())) {
    lineas = texto.split(",");
  }

  const salida: JugadorPegado[] = [];
  const vistos = new Set<string>();

  for (const linea of lineas) {
    let resto = linea.trim();
    if (!resto) continue;

    const chat = resto.match(LINEA_DE_CHAT);
    if (chat) resto = chat[1];

    resto = resto.replace(MARCA_DE_LISTA, "");

    let telefono: string | null = null;
    const conTelefono = resto.match(TELEFONO_FINAL);
    if (conTelefono) {
      const soloDigitos = conTelefono[1].replace(/[^\d+]/g, "");
      // Un número corto suele ser parte del nombre ("Pista 3"), no un teléfono.
      if (soloDigitos.replace(/\D/g, "").length >= 7) {
        telefono = soloDigitos;
        resto = resto.slice(0, conTelefono.index).trim();
      }
    }

    const nombre = limpiarNombre(resto);
    if (!nombre) continue;
    if (!/\p{L}/u.test(nombre)) continue; // números sueltos, emojis solos

    const clave = normalizar(nombre);
    if (vistos.has(clave)) continue;
    vistos.add(clave);

    salida.push({ nombre, telefono });
  }

  return salida;
}
