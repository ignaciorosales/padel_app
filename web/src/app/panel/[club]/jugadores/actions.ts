"use server";

/**
 * Unificar inscritos: las tres únicas escrituras de la pantalla.
 *
 * Van en su propio fichero y no en `panel/[club]/actions.ts` por dos razones:
 * ese fichero pasa de mil líneas y es el que las dos lanes tocan a la vez, y
 * estas tres acciones no comparten nada con las de torneos salvo el club.
 *
 * La regla que las gobierna: **el club decide, esto sólo escribe.** Ninguna de
 * las tres calcula parecidos ni elige por nadie — llegan con un id de inscrito y
 * un id de persona ya decididos en la pantalla. Unir mal mezcla el historial de
 * dos personas, así que quien lo hace tiene que ser quien mira.
 */

import { revalidatePath } from "next/cache";
import { requireClubAccess } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { nombreYApellidoDe } from "@/lib/identidad/panel";

const SUSPENDIDO =
  "La cuenta del club está suspendida: se puede consultar, pero no modificar.";

export type EstadoUnificar = { error?: string; hecho?: string };

/**
 * Los inscritos de este club, y sólo de este club.
 *
 * RLS ya lo impediría, pero un `update` que no filtra por club se apoya en que la
 * política esté bien escrita para siempre. Comprobarlo aquí además cuesta una
 * consulta y convierte un agujero en un error.
 */
async function inscritosDelClub(
  supabase: Awaited<ReturnType<typeof createClient>>,
  clubId: string,
  ids: readonly string[],
): Promise<string[]> {
  if (ids.length === 0) return [];

  const { data } = await supabase
    .from("tournament_players")
    .select("id, tournaments!inner(club_id)")
    .in("id", ids)
    .eq("tournaments.club_id", clubId);

  return ((data ?? []) as { id: string }[]).map((f) => f.id);
}

function revalidar(clubSlug: string) {
  revalidatePath(`/panel/${clubSlug}/jugadores`);
}

// ------------------------------------------------------- «es esta persona»

export async function unificarInscrito(
  _previo: EstadoUnificar,
  formData: FormData,
): Promise<EstadoUnificar> {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const { club, canWrite } = await requireClubAccess(clubSlug);
  if (!canWrite) return { error: SUSPENDIDO };

  const inscritoId = String(formData.get("inscritoId") ?? "");
  const personaId = String(formData.get("personaId") ?? "");
  if (!inscritoId || !personaId) return { error: "Falta el inscrito o la persona." };

  const supabase = await createClient();
  const permitidos = await inscritosDelClub(supabase, club.id, [inscritoId]);
  if (permitidos.length === 0) return { error: "Ese inscrito no es de este club." };

  const { error } = await supabase
    .from("tournament_players")
    .update({ player_id: personaId })
    .eq("id", inscritoId);

  if (error) {
    // El caso real: esa persona ya está inscrita en ese mismo torneo. Lo impide
    // un índice único, y es un aviso, no un fallo — significa que la unificación
    // que se está intentando es imposible por la regla del torneo.
    return {
      error: error.message.includes("tournament_players_persona_unica_idx")
        ? "Esa persona ya está inscrita en ese torneo, así que este nombre es otra."
        : `No se pudo unificar: ${error.message}`,
    };
  }

  revalidar(clubSlug);
  return { hecho: "Unificado." };
}

// ------------------------------------------------------ «crea esta persona»

/**
 * Crea una persona nueva y le cuelga los inscritos del grupo.
 *
 * Dos escrituras que no son atómicas: si la segunda falla queda una persona sin
 * inscritos. Se acepta a propósito en vez de montar una función de Postgres —una
 * persona huérfana no rompe nada, no sale en ninguna pantalla y se recoge sola en
 * cuanto alguien la unifique. Lo que no se puede aceptar es lo contrario: un
 * inscrito apuntando a una persona que no existe, y eso lo impide la clave ajena.
 */
export async function crearPersonaConInscritos(
  _previo: EstadoUnificar,
  formData: FormData,
): Promise<EstadoUnificar> {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const { club, canWrite } = await requireClubAccess(clubSlug);
  if (!canWrite) return { error: SUSPENDIDO };

  const texto = String(formData.get("nombre") ?? "").trim();
  if (!texto) return { error: "Hace falta un nombre." };

  const ids = formData.getAll("inscritoId").map(String).filter(Boolean);

  const supabase = await createClient();
  const permitidos = await inscritosDelClub(supabase, club.id, ids);
  if (permitidos.length !== ids.length) {
    return { error: "Alguno de esos inscritos no es de este club." };
  }

  const { nombre, apellido } = nombreYApellidoDe(texto);
  const apodo = String(formData.get("apodo") ?? "").trim() || null;
  const telefono = String(formData.get("telefono") ?? "").trim() || null;

  const { data: persona, error: errorPersona } = await supabase
    .from("players")
    .insert({ nombre, apellido, apodo, telefono })
    .select("id")
    .single();

  if (errorPersona || !persona) {
    return { error: `No se pudo crear la persona: ${errorPersona?.message ?? ""}` };
  }

  if (permitidos.length > 0) {
    const { error } = await supabase
      .from("tournament_players")
      .update({ player_id: (persona as { id: string }).id })
      .in("id", permitidos);

    if (error) {
      return {
        error: `La persona se creó, pero no se pudo enlazar: ${error.message}`,
      };
    }
  }

  revalidar(clubSlug);
  return {
    hecho: `${texto} creada con ${permitidos.length} ${
      permitidos.length === 1 ? "nombre" : "nombres"
    }.`,
  };
}

// ------------------------------------------------------------- deshacer

/**
 * Desenlaza un inscrito de su persona.
 *
 * Es la única forma de arreglar una unificación mal hecha, y por eso está aunque
 * casi no se use: sin deshacer, un encargado con dudas no toca nada — y una
 * pantalla que da miedo no se usa.
 */
export async function separarInscrito(
  _previo: EstadoUnificar,
  formData: FormData,
): Promise<EstadoUnificar> {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const { club, canWrite } = await requireClubAccess(clubSlug);
  if (!canWrite) return { error: SUSPENDIDO };

  const inscritoId = String(formData.get("inscritoId") ?? "");
  if (!inscritoId) return { error: "Falta el inscrito." };

  const supabase = await createClient();
  const permitidos = await inscritosDelClub(supabase, club.id, [inscritoId]);
  if (permitidos.length === 0) return { error: "Ese inscrito no es de este club." };

  const { error } = await supabase
    .from("tournament_players")
    .update({ player_id: null })
    .eq("id", inscritoId);

  if (error) return { error: `No se pudo separar: ${error.message}` };

  revalidar(clubSlug);
  return { hecho: "Separado." };
}
