"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export type EstadoLogin = { error?: string };

export async function iniciarSesion(
  _previo: EstadoLogin,
  formData: FormData,
): Promise<EstadoLogin> {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  const volver = String(formData.get("volver") ?? "");

  if (!email || !password) {
    return { error: "Escribe el correo y la contraseña." };
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    // No distinguimos "no existe" de "contraseña mal" a propósito: si no,
    // cualquiera puede averiguar qué correos tienen cuenta.
    return { error: "Correo o contraseña incorrectos." };
  }

  redirect(volver.startsWith("/") ? volver : "/");
}
