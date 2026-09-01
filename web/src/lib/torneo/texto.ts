/**
 * El torneo en texto plano, para pegar en el grupo de WhatsApp del club.
 *
 * El grupo ya existe y es donde la gente mira: pelear contra eso es perder. La
 * página pública es para enseñarla; esto es para el que va con el móvil en la
 * mano y quiere que los 24 sepan a qué pista van sin abrir nada.
 *
 * Reglas de formato, todas por el mismo motivo (que se lea bien en un móvil):
 *   · `*negrita*` es el único marcado que entiende WhatsApp. Nada más.
 *   · Una línea por partido. Dos líneas por partido son 12 líneas por ronda y
 *     nadie las lee.
 *   · Sin emojis: el club decide su propio tono, no nosotros.
 */

export type PartidoTexto = {
  pista: number;
  a: [string, string];
  b: [string, string];
  juegosA: number | null;
  juegosB: number | null;
};

export type RondaTexto = {
  torneo: string;
  numero: number;
  hora: string | null;
  partidos: PartidoTexto[];
  descansan: string[];
  /** El enlace a la página pública. Va al final, que es donde WhatsApp saca la vista previa. */
  url?: string;
};

/** "Ana / Luis" */
function pareja([uno, dos]: [string, string]): string {
  return `${uno} / ${dos}`;
}

export function textoRonda(r: RondaTexto): string {
  const cabecera = r.hora
    ? `*${r.torneo} — Ronda ${r.numero}* (${r.hora})`
    : `*${r.torneo} — Ronda ${r.numero}*`;

  const lineas = r.partidos.map((p) => {
    const marcador =
      p.juegosA !== null && p.juegosB !== null
        ? `  ${p.juegosA}-${p.juegosB}  `
        : "  vs  ";
    return `P${p.pista}  ${pareja(p.a)}${marcador}${pareja(p.b)}`;
  });

  const bloques = [cabecera, "", ...lineas];

  if (r.descansan.length > 0) {
    bloques.push("", `Descansan: ${r.descansan.join(", ")}`);
  }

  if (r.url) bloques.push("", r.url);

  return bloques.join("\n");
}

export type FilaTexto = {
  puesto: number;
  nombre: string;
  juegosFavor: number;
  diferencia: number;
};

/**
 * La clasificación en texto. Sólo puesto, nombre, juegos a favor y diferencia:
 * las nueve columnas de la tabla no caben en un móvil y las otras cinco sólo
 * las mira quien discute un desempate, que para eso tiene la página.
 */
export function textoClasificacion(
  torneo: string,
  filas: FilaTexto[],
  url?: string,
): string {
  const bloques = [`*Clasificación — ${torneo}*`, ""];

  if (filas.length === 0) {
    bloques.push("Todavía no hay resultados.");
  } else {
    for (const f of filas) {
      const dif = f.diferencia > 0 ? `+${f.diferencia}` : `${f.diferencia}`;
      bloques.push(`${f.puesto}. ${f.nombre}  ${f.juegosFavor} (${dif})`);
    }
    bloques.push("", "Juegos a favor y diferencia.");
  }

  if (url) bloques.push("", url);

  return bloques.join("\n");
}
