/**
 * Comprobación de que Supabase quedó bien montado.
 *
 *   npm run comprobar
 *
 * Lee las claves de .env.local y no imprime ninguna. Verifica que existen las
 * tablas, que existen las funciones de permisos, que RLS está bloqueando de
 * verdad y si ya hay un administrador de plataforma.
 */

import { createClient } from "@supabase/supabase-js";

const URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const ANON = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const SERVICIO = process.env.SUPABASE_SERVICE_ROLE_KEY;

let fallos = 0;

function ok(texto: string, detalle = "") {
  console.log(`  \x1b[32m✓\x1b[0m ${texto}${detalle ? `  \x1b[2m${detalle}\x1b[0m` : ""}`);
}

function mal(texto: string, arreglo: string) {
  fallos++;
  console.log(`  \x1b[31m✗\x1b[0m ${texto}`);
  console.log(`      \x1b[2m→ ${arreglo}\x1b[0m`);
}

function aviso(texto: string) {
  console.log(`  \x1b[33m·\x1b[0m ${texto}`);
}

function titulo(texto: string) {
  console.log(`\n\x1b[1m${texto}\x1b[0m`);
}

// --------------------------------------------------------------- variables
titulo("Variables de entorno");

if (!URL) {
  mal("Falta NEXT_PUBLIC_SUPABASE_URL", "Copia .env.example a .env.local y rellénalo.");
} else if (!/^https:\/\/.+\.supabase\.co\/?$/.test(URL)) {
  mal(`NEXT_PUBLIC_SUPABASE_URL no parece una URL de Supabase`, "Debe ser https://xxxx.supabase.co");
} else {
  ok("NEXT_PUBLIC_SUPABASE_URL", new globalThis.URL(URL).host);
}

if (!ANON) mal("Falta NEXT_PUBLIC_SUPABASE_ANON_KEY", "Project Settings ▸ API ▸ anon public");
else ok("NEXT_PUBLIC_SUPABASE_ANON_KEY", `${ANON.length} caracteres`);

if (!SERVICIO) mal("Falta SUPABASE_SERVICE_ROLE_KEY", "Project Settings ▸ API ▸ service_role");
else if (SERVICIO === ANON) mal("SUPABASE_SERVICE_ROLE_KEY es igual que la anónima", "Copia la clave service_role, no la anon.");
else ok("SUPABASE_SERVICE_ROLE_KEY", `${SERVICIO.length} caracteres`);

if (fallos > 0 || !URL || !ANON || !SERVICIO) {
  console.log("\n\x1b[31mFaltan datos para seguir comprobando.\x1b[0m\n");
  process.exit(1);
}

const admin = createClient(URL, SERVICIO, {
  auth: { autoRefreshToken: false, persistSession: false },
});
const anonimo = createClient(URL, ANON, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// ------------------------------------------------------------------ tablas
titulo("Esquema");

for (const tabla of [
  "profiles",
  "clubs",
  "club_members",
  "tournaments",
  "tournament_players",
  "rounds",
  "matches",
  "tournament_pairs",
  "courts",
  "tournament_courts",
  "court_occupancies",
]) {
  const { error } = await admin.from(tabla).select("*").limit(1);
  if (!error) ok(`Tabla ${tabla}`);
  else if (error.code === "42P01" || /does not exist/i.test(error.message)) {
    mal(`No existe la tabla ${tabla}`, "Ejecuta en el editor SQL las migraciones de backend/migrations/ que falten, en orden de número.");
  } else {
    mal(`Tabla ${tabla}: ${error.message}`, "Revisa la migración.");
  }
}

// --------------------------------------------------------------- funciones
titulo("Funciones de permisos");

{
  const { error } = await admin.rpc("is_platform_admin");
  if (!error) ok("is_platform_admin()");
  else mal(`is_platform_admin(): ${error.message}`, "La migración no se aplicó entera.");
}

{
  const { error } = await admin.rpc("can_write_club", {
    p_club: "00000000-0000-0000-0000-000000000000",
  });
  if (!error) ok("can_write_club()", "es la puerta del corte por impago");
  else mal(`can_write_club(): ${error.message}`, "La migración no se aplicó entera.");
}

for (const fn of ["club_de_torneo", "torneo_es_publico", "torneo_de_ronda", "club_de_pista"]) {
  const parametro =
    fn === "torneo_de_ronda" ? "p_ronda" : fn === "club_de_pista" ? "p_pista" : "p_torneo";
  const { error } = await admin.rpc(fn, {
    [parametro]: "00000000-0000-0000-0000-000000000000",
  });
  if (!error) ok(`${fn}()`);
  else mal(`${fn}(): ${error.message}`, "Falta una migración por aplicar.");
}

// --------------------------------------------------------------------- RLS
titulo("Row Level Security");

const { data: clubesTotales } = await admin.from("clubs").select("id, name, status");
const { data: clubesAnonimo, error: errorAnonimo } = await anonimo.from("clubs").select("id");

if (errorAnonimo) {
  ok("Sin sesión no se puede leer clubs", errorAnonimo.message);
} else if ((clubesTotales?.length ?? 0) === 0) {
  aviso("Todavía no hay clubes: no se puede confirmar que RLS bloquea. Crea uno y repite.");
} else if ((clubesAnonimo?.length ?? 0) === 0) {
  ok("RLS bloquea la lectura sin sesión", `${clubesTotales!.length} club(es) invisibles para el anónimo`);
} else {
  mal(
    `¡RLS NO está protegiendo clubs! Un anónimo ve ${clubesAnonimo!.length} fila(s)`,
    "Comprueba que se ejecutó la parte 'alter table ... enable row level security'.",
  );
}

// Una tabla con RLS y ninguna política no la puede usar nadie —ni el club— y no
// avisa: no falla al migrar, ni al arrancar, ni en los tests. Así se coló
// `tournament_pairs` desde la 0006 hasta la 0017, y el fallo apareció el día que
// alguien intentó apuntar una pareja a mano.
{
  const { data: mudas, error } = await admin.rpc("tablas_sin_politicas");

  if (error) {
    aviso(`No se pudo comprobar si hay tablas sin políticas: ${error.message}`);
  } else if ((mudas as { tabla: string }[] | null)?.length) {
    const nombres = (mudas as { tabla: string }[]).map((t) => t.tabla).join(", ");
    mal(
      `Tablas con RLS y sin ninguna política: ${nombres}`,
      "Nadie puede leerlas ni escribirlas. Escribe sus políticas, como en 0017_politicas_de_tournament_pairs.sql.",
    );
  } else {
    ok("Ninguna tabla con RLS se quedó sin políticas");
  }
}

// ------------------------------------------------------------------ cuentas
titulo("Cuentas");

const { data: usuarios, error: errorUsuarios } = await admin.auth.admin.listUsers();

if (errorUsuarios) {
  mal(`No se pudieron listar los usuarios: ${errorUsuarios.message}`, "¿Es correcta la clave service_role?");
} else {
  const total = usuarios.users.length;
  if (total === 0) {
    mal("No hay ningún usuario", "Créate uno en Authentication ▸ Users (marca Auto Confirm User).");
  } else {
    ok(`${total} usuario(s) en el proyecto`);

    const { data: admins } = await admin
      .from("profiles")
      .select("email")
      .eq("is_platform_admin", true);

    if (!admins || admins.length === 0) {
      mal(
        "Ningún usuario es administrador de plataforma",
        "En el editor SQL:  update public.profiles set is_platform_admin = true " +
          "where id = (select id from auth.users where email = 'tu@correo.com');",
      );
    } else {
      ok(`Administrador de plataforma: ${admins.map((a) => a.email ?? "(sin correo)").join(", ")}`);
    }

    const { count } = await admin
      .from("profiles")
      .select("id", { count: "exact", head: true });

    if ((count ?? 0) < total) {
      mal(
        `Hay ${total} usuarios pero sólo ${count} perfiles`,
        "El trigger on_auth_user_created no llegó a ejecutarse para los usuarios anteriores a la migración.",
      );
    }
  }
}

// ------------------------------------------------------------------- clubes
if ((clubesTotales?.length ?? 0) > 0) {
  titulo("Clubes");
  for (const c of clubesTotales!) {
    ok(c.name, c.status);
  }
}

// -------------------------------------------------------------------- final
console.log();
if (fallos === 0) {
  console.log("\x1b[32m\x1b[1mTodo en orden. Arranca con: npm run dev\x1b[0m\n");
} else {
  console.log(`\x1b[31m\x1b[1m${fallos} cosa(s) por arreglar.\x1b[0m\n`);
  process.exit(1);
}
