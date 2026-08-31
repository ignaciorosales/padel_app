import type { Metadata } from "next";
import Link from "next/link";
import { requireClubAccess } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ETIQUETA_ESTADO } from "@/lib/types";
import { ETIQUETA_TORNEO, soloHoraMinuto, type Torneo } from "@/lib/torneo/tipos";
import { Aviso, Badge, Eyebrow, LinkButton, PageHeader, Vacio } from "@/components/ui";

type Params = { params: Promise<{ club: string }> };

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { club } = await params;
  const { club: datos } = await requireClubAccess(club);
  return { title: datos.name };
}

export default async function ClubPanelPage({ params }: Params) {
  const { club: slug } = await params;
  const { club, role, canWrite, viewer } = await requireClubAccess(slug);

  const supabase = await createClient();
  const { data: torneos } = await supabase
    .from("tournaments")
    .select("*")
    .eq("club_id", club.id)
    .order("fecha", { ascending: false });

  const lista = (torneos ?? []) as Torneo[];
  const etiqueta = ETIQUETA_ESTADO[club.status];
  const esVisitaDePlataforma = role === null && viewer.profile.is_platform_admin;

  return (
    <>
      <PageHeader
        eyebrow="Panel del club"
        title={club.name}
        description="Monta los torneos, reparte las rondas y lleva los resultados."
        actions={
          <>
            <Badge tono={etiqueta.tono}>{etiqueta.texto}</Badge>
            {canWrite ? (
              <LinkButton href={`/panel/${club.slug}/torneo/nuevo`} variante="primario">
                Crear torneo
              </LinkButton>
            ) : null}
          </>
        }
      />

      {esVisitaDePlataforma ? (
        <Aviso tono="ok" titulo="Estás viendo este panel como administrador de Puntazo">
          No eres miembro de este club.
        </Aviso>
      ) : null}

      {club.status === "suspended" ? (
        <Aviso tono="danger" titulo="Cuenta suspendida">
          Puedes consultar los torneos que ya había, pero no crear ni modificar nada
          hasta regularizar la suscripción. Los datos siguen intactos.
        </Aviso>
      ) : null}

      {club.status === "past_due" ? (
        <Aviso tono="warn" titulo="Hay un pago pendiente">
          Todo sigue funcionando. Si no se regulariza, la cuenta pasará a sólo lectura.
        </Aviso>
      ) : null}

      <Eyebrow>Torneos</Eyebrow>

      {lista.length === 0 ? (
        <Vacio>
          Todavía no hay ningún torneo.
          {canWrite ? (
            <>
              <br />
              <Link
                href={`/panel/${club.slug}/torneo/nuevo`}
                className="text-accent-ink underline underline-offset-4"
              >
                Crea el primero
              </Link>
            </>
          ) : null}
        </Vacio>
      ) : (
        <ul className="divide-y divide-rule border-y border-rule">
          {lista.map((t) => (
            <li key={t.id}>
              <Link
                href={`/panel/${club.slug}/torneo/${t.slug}`}
                className="flex flex-wrap items-center justify-between gap-3 py-4 hover:bg-surface-alt/60"
              >
                <div className="min-w-0">
                  <p className="font-semibold text-ink">{t.nombre}</p>
                  <p className="mt-0.5 font-mono text-xs text-ink-faint">
                    {new Date(`${t.fecha}T00:00:00`).toLocaleDateString("es-ES", {
                      weekday: "long",
                      day: "numeric",
                      month: "long",
                    })}
                    {soloHoraMinuto(t.hora_inicio) ? ` · ${soloHoraMinuto(t.hora_inicio)}` : ""}
                    {` · ${t.pistas} pista${t.pistas === 1 ? "" : "s"} · ${t.rondas} rondas`}
                  </p>
                </div>
                <Badge tono={ETIQUETA_TORNEO[t.estado].tono}>
                  {ETIQUETA_TORNEO[t.estado].texto}
                </Badge>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
