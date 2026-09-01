import "server-only";

import { createClient } from "@supabase/supabase-js";

/**
 * Cliente para la página pública: clave anónima y **sin cookies**.
 *
 * El de `server.ts` lee las cookies para saber quién eres, y eso obliga a
 * renderizar cada petición por separado. La página pública no necesita saber
 * quién mira —la ven jugadores sin cuenta— así que sin cookies puede cachearse
 * y servirse igual a todo el mundo, que es justo lo que hace falta cuando 24
 * personas abren el mismo enlace a la vez con mala cobertura.
 *
 * Sigue pasando por RLS: sólo ve lo que las políticas dejan ver a un anónimo,
 * es decir, torneos con `publico = true`.
 */
export function createPublicClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
}
