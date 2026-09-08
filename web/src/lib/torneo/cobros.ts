/**
 * El dinero de un torneo, que en la fase 1 es deliberadamente poco.
 *
 * El plan de producto lo deja escrito: cobros fuera, pero con sitio. Ni caja,
 * ni bonos, ni recibos — un importe por inscripción y si está cobrado. Lo que
 * el club quiere saber el sábado por la mañana es una sola frase: quién falta
 * por pagar y cuánto queda por recoger.
 *
 * TypeScript puro, sin base de datos, como el resto de `lib/torneo`.
 */

export type InscripcionCobrable = {
  id: string;
  nombre: string;
  /** Nulo: este torneo no cobra a esta persona. 0: no paga (invitado, bono). */
  importe: number | null;
  pagado: boolean;
};

export type ResumenCobros = {
  /** Si el torneo cobra algo a alguien. Con `false` no se enseña nada de esto. */
  hayImportes: boolean;
  cobrado: number;
  pendiente: number;
  total: number;
  /** Personas con importe > 0 sin cobrar. Las de 0 € no deben nada. */
  pendientes: string[];
};

/**
 * Suma en céntimos y divide al final.
 *
 * Sumar 12,10 + 12,10 + 12,10 en coma flotante da 36,299999999999997, y un
 * total con catorce decimales en la pantalla de un club es un producto que no
 * inspira confianza. Los importes vienen de `numeric(8,2)`, así que dos
 * decimales es todo lo que hay que respetar.
 */
function sumarCentimos(importes: number[]): number {
  const centimos = importes.reduce((suma, i) => suma + Math.round(i * 100), 0);
  return centimos / 100;
}

export function resumirCobros(inscripciones: InscripcionCobrable[]): ResumenCobros {
  // `typeof` y no `!== null` a propósito: entre desplegar el código y aplicar
  // la 0013, la fila que llega de Postgres no trae la columna y el importe es
  // `undefined`, que no es nulo. Con la comparación estricta, ese hueco se
  // colaba como si fuera un importe y salía «NaN €» en la pantalla del club.
  const conImporte = inscripciones.filter((i) => typeof i.importe === "number");

  if (conImporte.length === 0) {
    return { hayImportes: false, cobrado: 0, pendiente: 0, total: 0, pendientes: [] };
  }

  const cobrado = sumarCentimos(
    conImporte.filter((i) => i.pagado).map((i) => i.importe!),
  );
  const pendiente = sumarCentimos(
    conImporte.filter((i) => !i.pagado).map((i) => i.importe!),
  );

  return {
    hayImportes: true,
    cobrado,
    pendiente,
    total: sumarCentimos(conImporte.map((i) => i.importe!)),
    // Quien tiene 0 € no está pendiente de pago, está invitado. Meterlo en la
    // lista de morosos haría que el club dejara de mirarla.
    pendientes: conImporte
      .filter((i) => !i.pagado && i.importe! > 0)
      .map((i) => i.nombre),
  };
}

/**
 * "12,50 €" — como se escribe en España, no como lo guarda Postgres.
 *
 * El espacio antes del € es duro (U+00A0), que es lo correcto y lo que pone
 * `Intl`: la cantidad y su moneda no se parten en dos líneas. Se deja tal cual,
 * y por eso los tests lo comparan con ` ` en vez de con un espacio normal.
 */
export function euros(cantidad: number): string {
  return new Intl.NumberFormat("es-ES", {
    style: "currency",
    currency: "EUR",
  }).format(cantidad);
}

/**
 * Lo que se lee de un tirón en la cabecera de los inscritos.
 *
 * Sin importes no dice nada: un torneo gratis no necesita una línea explicando
 * que ha recaudado cero euros.
 */
export function fraseCobros(resumen: ResumenCobros): string | null {
  if (!resumen.hayImportes) return null;

  if (resumen.pendientes.length === 0) {
    return `Todo cobrado: ${euros(resumen.cobrado)}.`;
  }

  const cuantos = resumen.pendientes.length;
  return (
    `${euros(resumen.cobrado)} cobrados · ` +
    `${euros(resumen.pendiente)} de ${cuantos} ` +
    `${cuantos === 1 ? "persona" : "personas"} sin cobrar.`
  );
}

/**
 * El importe que más se repite, para volver a ofrecerlo.
 *
 * Si hay veinte inscripciones a 12 € y una a 0 € porque el organizador no paga,
 * el precio del torneo es 12. Empatados, gana el mayor: es más fácil bajarle el
 * precio a alguien que acordarse de subírselo.
 */
export function masRepetido(importes: number[]): number | null {
  if (importes.length === 0) return null;

  const cuenta = new Map<number, number>();
  for (const i of importes) cuenta.set(i, (cuenta.get(i) ?? 0) + 1);

  let ganador = importes[0];
  let veces = 0;
  for (const [importe, n] of cuenta) {
    if (n > veces || (n === veces && importe > ganador)) {
      ganador = importe;
      veces = n;
    }
  }

  return ganador;
}

/**
 * Un importe escrito a mano, a número. Acepta la coma decimal.
 *
 * "12,50" y "12.50" son la misma cantidad; en un teclado español sale la coma
 * y nadie va a corregirla. Devuelve `null` para el campo vacío, que significa
 * «este torneo no cobra», y `undefined` para lo que no es un importe.
 */
export function leerImporte(texto: string): number | null | undefined {
  const limpio = texto.trim().replace(",", ".").replace(/\s|€/g, "");
  if (limpio === "") return null;

  const numero = Number(limpio);
  if (!Number.isFinite(numero) || numero < 0 || numero > 999999.99) return undefined;

  return Math.round(numero * 100) / 100;
}
