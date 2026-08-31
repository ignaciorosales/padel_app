import "server-only";

import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { puedeEscribir, type Club, type ClubRole, type Membership, type Profile } from "@/lib/types";

/**
 * Capa de acceso a datos de sesión.
 *
 * El proxy hace una comprobación optimista para redirigir rápido, pero la
 * autorización de verdad se hace AQUÍ y en las políticas RLS. Toda página
 * privada y toda acción de servidor empieza llamando a uno de estos require*.
 */

export type Viewer = {
  userId: string;
  email: string | null;
  profile: Profile;
  memberships: Membership[];
};

/** `cache` evita repetir la consulta varias veces en el mismo render. */
export const getViewer = cache(async (): Promise<Viewer | null> => {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const [{ data: profile }, { data: memberships }] = await Promise.all([
    supabase.from("profiles").select("*").eq("id", user.id).single(),
    supabase
      .from("club_members")
      .select("role, club:clubs(*)")
      .eq("user_id", user.id)
      .order("created_at", { ascending: true }),
  ]);

  if (!profile) return null;

  return {
    userId: user.id,
    email: user.email ?? null,
    profile: profile as Profile,
    memberships: ((memberships ?? []) as unknown as { role: ClubRole; club: Club }[])
      .filter((m) => m.club)
      .map((m) => ({ role: m.role, club: m.club })),
  };
});

export async function requireViewer(): Promise<Viewer> {
  const viewer = await getViewer();
  if (!viewer) redirect("/login");
  return viewer;
}

export async function requirePlatformAdmin(): Promise<Viewer> {
  const viewer = await requireViewer();
  if (!viewer.profile.is_platform_admin) redirect("/panel");
  return viewer;
}

export type ClubAccess = {
  viewer: Viewer;
  club: Club;
  /** null cuando entra un administrador de plataforma que no es miembro. */
  role: ClubRole | null;
  /** false si el club está suspendido: la interfaz pasa a sólo lectura. */
  canWrite: boolean;
};

/**
 * Resuelve el acceso a un club por su slug. Un administrador de plataforma
 * entra en cualquier club; un usuario normal, sólo en los suyos.
 */
export async function requireClubAccess(slug: string): Promise<ClubAccess> {
  const viewer = await requireViewer();

  const membership = viewer.memberships.find((m) => m.club.slug === slug);

  if (membership) {
    return {
      viewer,
      club: membership.club,
      role: membership.role,
      canWrite: puedeEscribir(membership.club.status),
    };
  }

  if (viewer.profile.is_platform_admin) {
    const supabase = await createClient();
    const { data: club } = await supabase
      .from("clubs")
      .select("*")
      .eq("slug", slug)
      .single();

    if (club) {
      return { viewer, club: club as Club, role: null, canWrite: true };
    }
  }

  redirect("/panel");
}

/** Destino según quién entra: administrador a /admin, club a su panel. */
export function inicioPara(viewer: Viewer): string {
  if (viewer.profile.is_platform_admin) return "/admin";
  if (viewer.memberships.length === 1) {
    return `/panel/${viewer.memberships[0].club.slug}`;
  }
  return "/panel";
}
