import type { ReactNode } from "react";
import { requireViewer } from "@/lib/auth";
import { Shell } from "@/components/shell";

export default async function PanelLayout({ children }: { children: ReactNode }) {
  const viewer = await requireViewer();

  return (
    <Shell
      email={viewer.email}
      esAdminPlataforma={viewer.profile.is_platform_admin}
    >
      {children}
    </Shell>
  );
}
