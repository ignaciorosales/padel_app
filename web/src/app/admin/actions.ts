"use server";

import { randomInt } from "node:crypto";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requirePlatformAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";
import type { SubscriptionStatus } from "@/lib/types";

const ESTADOS: SubscriptionStatus[] = ["trial", "active", "past_due", "suspended"];

/** Sin caracteres que se confundan al dictarla por teléfono (0/O, 1/l/I). */
const ALFABETO = "abcdefghijkmnpqrstuvwxyzACDEFGHJKLMNPQRSTUVWXYZ23456789";

function contrasenaTemporal(longitud = 12): string {
  let salida = "";
  for (let i = 0; i < longitud; i++) {
    salida += ALFABETO[randomInt(ALFABETO.length)];
  }
  return salida;
}

function aSlug(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 40);
}

// ---------------------------------------------------------------- crear club

export type EstadoClub = { error?: string; ok?: string };

export async function crearClub(
  _previo: EstadoClub,
  formData: FormData,
): Promise<EstadoClub> {
  await requirePlatformAdmin();

  const name = String(formData.get("name") ?? "").trim();
  const slugPedido = String(formData.get("slug") ?? "").trim();
  const slug = aSlug(slugPedido || name);

  if (!name) return { error: "El club necesita un nombre." };
  if (slug.length < 2) return { error: "El identificador es demasiado corto." };

  const supabase = await createClient();
  const { error } = await supabase.from("clubs").insert({ name, slug });

  if (error) {
    if (error.code === "23505") {
      return { error: `Ya hay un club con el identificador «${slug}».` };
    }
    return { error: error.message };
  }

  revalidatePath("/admin");
  return { ok: `Club «${name}» creado.` };
}

// ------------------------------------------------------- estado del suscripción

export async function cambiarEstadoClub(formData: FormData) {
  await requirePlatformAdmin();

  const clubId = String(formData.get("clubId") ?? "");
  const estado = String(formData.get("status") ?? "") as SubscriptionStatus;

  if (!clubId || !ESTADOS.includes(estado)) return;

  const supabase = await createClient();
  await supabase.from("clubs").update({ status: estado }).eq("id", clubId);

  revalidatePath("/admin");
  revalidatePath("/panel", "layout");
}

// -------------------------------------------------------------- crear usuario

export type EstadoUsuario = {
  error?: string;
  creado?: { email: string; password: string };
};

export async function crearUsuarioDeClub(
  _previo: EstadoUsuario,
  formData: FormData,
): Promise<EstadoUsuario> {
  await requirePlatformAdmin();

  const clubId = String(formData.get("clubId") ?? "");
  const email = String(formData.get("email") ?? "").trim().toLowerCase();
  const fullName = String(formData.get("fullName") ?? "").trim();
  const role = String(formData.get("role") ?? "staff") === "owner" ? "owner" : "staff";

  if (!clubId) return { error: "Falta el club." };
  if (!email.includes("@")) return { error: "Ese correo no parece válido." };

  const admin = createAdminClient();
  const password = contrasenaTemporal();

  const { data: creacion, error: errorAlta } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName || null },
  });

  let userId = creacion?.user?.id;

  if (errorAlta) {
    // Si ya existe el usuario, lo reutilizamos: puede llevar dos clubes.
    const { data: existentes } = await admin.auth.admin.listUsers();
    const encontrado = existentes?.users.find(
      (u) => u.email?.toLowerCase() === email,
    );

    if (!encontrado) return { error: errorAlta.message };
    userId = encontrado.id;

    const supabase = await createClient();
    const { error: errorMiembro } = await supabase
      .from("club_members")
      .upsert({ club_id: clubId, user_id: userId, role });

    if (errorMiembro) return { error: errorMiembro.message };

    revalidatePath("/admin");
    return {
      error:
        "Ese correo ya tenía cuenta. Lo he añadido al club sin cambiar su contraseña.",
    };
  }

  if (!userId) return { error: "No se pudo crear el usuario." };

  const supabase = await createClient();
  const { error: errorMiembro } = await supabase
    .from("club_members")
    .insert({ club_id: clubId, user_id: userId, role });

  if (errorMiembro) return { error: errorMiembro.message };

  revalidatePath("/admin");
  return { creado: { email, password } };
}

// ------------------------------------------------------------- quitar usuario

export async function quitarUsuarioDeClub(formData: FormData) {
  await requirePlatformAdmin();

  const clubId = String(formData.get("clubId") ?? "");
  const userId = String(formData.get("userId") ?? "");
  if (!clubId || !userId) return;

  const supabase = await createClient();
  await supabase
    .from("club_members")
    .delete()
    .eq("club_id", clubId)
    .eq("user_id", userId);

  revalidatePath("/admin");
}

// ---------------------------------------------------------------- borrar club

export type EstadoBorrado = { error?: string };

/**
 * Borrado definitivo. Se lleva por delante los accesos del club y, cuando
 * existan, sus torneos (por `on delete cascade`).
 *
 * Pide escribir el identificador del club a mano: no es paranoia, es que el
 * botón está a dos clics del que suspende, y confundirlos sería caro.
 */
export async function borrarClub(
  _previo: EstadoBorrado,
  formData: FormData,
): Promise<EstadoBorrado> {
  await requirePlatformAdmin();

  const clubId = String(formData.get("clubId") ?? "");
  const confirmacion = String(formData.get("confirmacion") ?? "").trim().toLowerCase();

  if (!clubId) return { error: "Falta el club." };

  const supabase = await createClient();
  const { data: club } = await supabase
    .from("clubs")
    .select("slug, name")
    .eq("id", clubId)
    .single();

  if (!club) return { error: "Ese club ya no existe." };

  if (confirmacion !== club.slug) {
    return {
      error: `Para confirmar hay que escribir «${club.slug}» exactamente.`,
    };
  }

  const { error } = await supabase.from("clubs").delete().eq("id", clubId);
  if (error) return { error: error.message };

  revalidatePath("/admin");
  redirect("/admin");
}
