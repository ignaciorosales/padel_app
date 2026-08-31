import type { ReactNode } from "react";
import { requirePlatformAdmin } from "@/lib/auth";
import { Shell } from "@/components/shell";

export default async function AdminLayout({ children }: { children: ReactNode }) {
  const viewer = await requirePlatformAdmin();

  return (
    <Shell email={viewer.email} esAdminPlataforma>
      {children}
    </Shell>
  );
}
