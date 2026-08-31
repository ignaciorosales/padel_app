import "server-only";

import { createClient } from "@supabase/supabase-js";

/**
 * Cliente con la clave de servicio: SE SALTA RLS POR COMPLETO.
 *
 * Sólo para dos cosas que la clave anónima no puede hacer:
 *   - crear usuarios (auth.admin.createUser)
 *   - listar correos de auth.users
 *
 * Reglas de uso, sin excepciones:
 *   1. Nunca se importa desde un componente de cliente ("server-only" lo impide).
 *   2. Toda acción que lo use comprueba antes `requirePlatformAdmin()`.
 */
export function createAdminClient() {
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!serviceKey) {
    throw new Error(
      "Falta SUPABASE_SERVICE_ROLE_KEY. Sin ella no se pueden crear usuarios desde /admin.",
    );
  }

  return createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
