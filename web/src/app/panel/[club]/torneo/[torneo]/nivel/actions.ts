"use server";

/**
 * Las dos escrituras de la pantalla de nivel: la restricción y la excepción.
 *
 * En su propio fichero por lo mismo que las de unificar: `panel/[club]/actions.ts`
 * pasa de mil líneas y es el que las dos lanes tocan a la vez.
 *
 * Ninguna de las dos comprueba si alguien encaja. Eso lo hace `lib/torneo/admision`
 * y se enseña; aquí sólo se guarda lo que el organizador decidió. Es la misma
 * separación que en la unificación, y por la misma razón: el sistema propone, la
 * persona que conoce a la gente decide.
 */

import { revalidatePath } from "next/cache";
import { requireClubAccess } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ESCALA_UY } from "@/lib/rating/divisiones";

const SUSPENDIDO =
  "La cuenta del club está suspendida: se puede consultar, pero no modificar.";

export type EstadoNivel = { error?: string; hecho?: string };

const DIVISIONES = new Set(ESCALA_UY.divisiones.map((d) => d.nombre));

function entero(valor: FormDataEntryValue | null): number | null {
  const texto = String(valor ?? "").trim();
  if (texto === "") return null;
  const n = Number.parseInt(texto, 10);
  return Number.isFinite(n) ? n : null;
}

async function torneoDelClub(
  supabase: Awaited<ReturnType<typeof createClient>>,
  clubId: string,
  slug: string,
): Promise<string | null> {
  const { data } = await supabase
    .from("tournaments")
    .select("id")
    .eq("club_id", clubId)
    .eq("slug", slug)
    .maybeSingle();

  return (data as { id: string } | null)?.id ?? null;
}

function revalidar(clubSlug: string, torneoSlug: string) {
  revalidatePath(`/panel/${clubSlug}/torneo/${torneoSlug}/nivel`);
  revalidatePath(`/panel/${clubSlug}/torneo/${torneoSlug}`);
  // La página pública enseña el cartel («Sólo 4ª y 5ª»), y se cachea un minuto.
  revalidatePath(`/t/${clubSlug}/${torneoSlug}`);
}

// -------------------------------------------------------- la restricción

export async function guardarRestriccion(
  _previo: EstadoNivel,
  formData: FormData,
): Promise<EstadoNivel> {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const { club, canWrite } = await requireClubAccess(clubSlug);
  if (!canWrite) return { error: SUSPENDIDO };

  const minimo = entero(formData.get("rating_minimo"));
  const maximo = entero(formData.get("rating_maximo"));

  // Se comprueba aquí además de en el CHECK para poder decirlo con palabras. El
  // error de Postgres es correcto y no se entiende.
  if (minimo !== null && maximo !== null && minimo > maximo) {
    return { error: "El mínimo no puede ser mayor que el máximo." };
  }
  if ((minimo !== null && minimo < 0) || (maximo !== null && maximo < 0)) {
    return { error: "Un rating no puede ser negativo." };
  }

  // Sólo nombres de la escala: un "4" o un "cuarta" escritos a mano dejarían un
  // torneo con una restricción que no coincide con la división de nadie.
  const divisiones = formData
    .getAll("division")
    .map(String)
    .filter((d) => DIVISIONES.has(d));

  const supabase = await createClient();
  const torneoId = await torneoDelClub(supabase, club.id, torneoSlug);
  if (!torneoId) return { error: "Ese torneo no es de este club." };

  const { error } = await supabase
    .from("tournaments")
    .update({
      rating_minimo: minimo,
      rating_maximo: maximo,
      divisiones_admitidas: divisiones,
    })
    .eq("id", torneoId);

  if (error) return { error: `No se pudo guardar: ${error.message}` };

  revalidar(clubSlug, torneoSlug);
  return { hecho: "Guardado." };
}

// ---------------------------------------------------------- la excepción

/**
 * El organizador deja entrar a alguien que no encaja, o retira ese permiso.
 *
 * El motivo se guarda con la excepción y se borra al retirarla: un motivo colgando
 * de una excepción que ya no existe es una explicación de algo que no pasó, y la
 * restricción de la 0018 no lo permite.
 */
export async function cambiarExcepcion(
  _previo: EstadoNivel,
  formData: FormData,
): Promise<EstadoNivel> {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const { club, canWrite } = await requireClubAccess(clubSlug);
  if (!canWrite) return { error: SUSPENDIDO };

  const inscritoId = String(formData.get("inscritoId") ?? "");
  if (!inscritoId) return { error: "Falta el inscrito." };

  const aprobar = String(formData.get("aprobar") ?? "") === "si";
  const motivo = String(formData.get("motivo") ?? "").trim();

  const supabase = await createClient();
  const torneoId = await torneoDelClub(supabase, club.id, torneoSlug);
  if (!torneoId) return { error: "Ese torneo no es de este club." };

  const { error } = await supabase
    .from("tournament_players")
    .update({
      excepcion_aprobada: aprobar,
      excepcion_motivo: aprobar ? motivo || null : null,
    })
    .eq("id", inscritoId)
    // Que el inscrito sea de este torneo, no sólo de este club: sin esto, un id
    // de otro torneo del mismo club pasaría.
    .eq("tournament_id", torneoId);

  if (error) return { error: `No se pudo guardar la excepción: ${error.message}` };

  revalidar(clubSlug, torneoSlug);
  return { hecho: aprobar ? "Excepción aprobada." : "Excepción retirada." };
}
