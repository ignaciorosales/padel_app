import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { requireViewer } from "@/lib/auth";
import { ETIQUETA_ESTADO } from "@/lib/types";
import { Badge, Card, PageHeader, Vacio } from "@/components/ui";

export const metadata: Metadata = { title: "Tus clubes" };

export default async function PanelPage() {
  const viewer = await requireViewer();

  if (viewer.memberships.length === 1) {
    redirect(`/panel/${viewer.memberships[0].club.slug}`);
  }

  return (
    <>
      <PageHeader
        title="Tus clubes"
        description="Elige con cuál quieres trabajar."
      />

      {viewer.memberships.length === 0 ? (
        <Vacio>
          Tu cuenta todavía no está asociada a ningún club.
          <br />
          Avisa a tu contacto en Puntazo para que te dé acceso.
        </Vacio>
      ) : (
        <ul className="grid gap-4 sm:grid-cols-2">
          {viewer.memberships.map(({ club, role }) => (
            <li key={club.id}>
              <Link href={`/panel/${club.slug}`} className="block">
                <Card className="transition-colors hover:border-rule-strong">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="font-semibold text-ink">{club.name}</p>
                      <p className="mt-0.5 font-mono text-xs text-ink-faint">
                        {role === "owner" ? "Dueño" : "Personal"}
                      </p>
                    </div>
                    <Badge tono={ETIQUETA_ESTADO[club.status].tono}>
                      {ETIQUETA_ESTADO[club.status].texto}
                    </Badge>
                  </div>
                </Card>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
