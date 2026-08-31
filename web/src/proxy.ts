import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

/**
 * En Next.js 16 esto es `proxy.ts` — lo que antes se llamaba middleware.
 *
 * Hace dos cosas y ninguna más:
 *   1. Refresca la sesión de Supabase en cada petición (si no, caduca sola).
 *   2. Redirige de forma optimista para no pintar páginas privadas a nadie.
 *
 * NO es la capa de autorización. Eso son las políticas RLS y los `require*`
 * de src/lib/auth.ts, que se ejecutan en cada página y en cada acción.
 */
export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value),
          );
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { pathname } = request.nextUrl;
  const esPrivada = pathname.startsWith("/admin") || pathname.startsWith("/panel");

  if (!user && esPrivada) {
    const login = request.nextUrl.clone();
    login.pathname = "/login";
    login.searchParams.set("volver", pathname);
    return NextResponse.redirect(login);
  }

  if (user && pathname === "/login") {
    const inicio = request.nextUrl.clone();
    inicio.pathname = "/";
    inicio.search = "";
    return NextResponse.redirect(inicio);
  }

  return response;
}

export const config = {
  matcher: [
    // Todo menos ficheros estáticos e imágenes.
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
  ],
};
