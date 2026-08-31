import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { requireClubAccess } from "@/lib/auth";
import { Card, PageHeader } from "@/components/ui";
import { TorneoForm } from "./torneo-form";

export const metadata: Metadata = { title: "Nuevo torneo" };

export default async function NuevoTorneoPage({
  params,
}: {
  params: Promise<{ club: string }>;
}) {
  const { club: slug } = await params;
  const { club, canWrite } = await requireClubAccess(slug);

  // Con la cuenta suspendida no hay nada que hacer en esta pantalla.
  if (!canWrite) redirect(`/panel/${club.slug}`);

  return (
    <div className="max-w-2xl">
      <PageHeader
        eyebrow={
          <Link href={`/panel/${club.slug}`} className="hover:underline">
            {club.name}
          </Link>
        }
        title="Nuevo torneo"
      />
      <Card>
        <TorneoForm clubSlug={club.slug} />
      </Card>
    </div>
  );
}
