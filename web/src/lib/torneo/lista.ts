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
