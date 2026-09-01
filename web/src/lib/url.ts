import "server-only";

import { headers } from "next/headers";

/**
 * De dónde cuelga el enlace público que el club copia y pega.
 *
 * Sale de la petición en curso, no de una variable de entorno: así vale igual
 * en local, en una preview de Vercel y en el dominio de verdad, sin que nadie
 * tenga que acordarse de configurar nada el día del torneo. Si algún día hay
 * un dominio propio distinto del que sirve el panel, NEXT_PUBLIC_SITE_URL
 * manda.
 */
export async function origenPublico(): Promise<string> {
  if (process.env.NEXT_PUBLIC_SITE_URL) {
    return process.env.NEXT_PUBLIC_SITE_URL.replace(/\/+$/, "");
  }

  const cabeceras = await headers();
  const host = cabeceras.get("host") ?? "localhost:3000";
  // Detrás del proxy de Vercel la petición llega en http; el esquema real va
  // en x-forwarded-proto.
  const esquema =
    cabeceras.get("x-forwarded-proto") ??
    (host.startsWith("localhost") ? "http" : "https");

  return `${esquema}://${host}`;
}
