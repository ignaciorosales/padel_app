"use server";

/**
 * Encender y apagar la página pública de un jugador.
 *
 * Lo hace el club y no el jugador, y eso es una deuda declarada, no un descuido:
 * la app del jugador no existe todavía, así que la única persona con sesión que
 * tiene relación con él es el club. Puede preguntarle, que es lo que se espera.
 *
 * En cuanto exista la app, esto se estrecha a que lo encienda cada uno para sí
 * mismo (`players.user_id = auth.uid()`), y esta acción se queda sólo para
 * apagarla — que es la dirección en la que un club siempre debe poder actuar.
 */

import { revalidatePath } from "next/cache";
import { requireClubAccess } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

const SUSPENDIDO =
  "La cuenta del club está suspendida: se puede consultar, pero no modificar.";

export type EstadoPublico = { error?: string; hecho?: string };

export async function cambiarPaginaPublica(
  _previo: EstadoPublico,
  formData: FormData,
): Promise<EstadoPublico> {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const { club, canWrite } = await requireClubAccess(clubSlug);
  if (!canWrite) return { error: SUSPENDIDO };

  const personaId = String(formData.get("personaId") ?? "");
  if (!personaId) return { error: "Falta el jugador." };

  const encender = String(formData.get("encender") ?? "") === "si";

  const supabase = await createClient();

  // Que la persona sea de este club: haber jugado un torneo suyo o estar dada de
  // alta. Sin esto, un uuid cualquiera dejaría a un club encender la página de
  // alguien que no ha visto nunca.
  const { data: suya } = await supabase
    .from("club_memberships")
    .select("player_id")
    .eq("club_id", club.id)
    .eq("player_id", personaId)
    .maybeSingle();

  if (!suya) {
    return { error: "Ese jugador no está dado de alta en este club." };
  }

  const { error } = await supabase
    .from("players")
    .update({ publico: encender })
    .eq("id", personaId);

  if (error) return { error: `No se pudo cambiar: ${error.message}` };

  revalidatePath(`/panel/${clubSlug}/jugadores/${personaId}`);
  revalidatePath(`/j/${personaId}`);

  return {
    hecho: encender
      ? "Página pública encendida. El enlace ya se puede compartir."
      : "Página pública apagada. El enlace deja de abrirse.",
  };
}
