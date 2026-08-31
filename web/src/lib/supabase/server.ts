import "server-only";

import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

/**
 * Cliente de Supabase para componentes y acciones de servidor.
 * Usa la clave anónima, así que TODO lo que haga pasa por las políticas RLS:
 * un club suspendido no podrá escribir aunque el código se lo pida.
 */
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // Llamado desde un Server Component, donde no se pueden escribir
            // cookies. El proxy ya refresca la sesión en cada petición.
          }
        },
      },
    },
  );
}
