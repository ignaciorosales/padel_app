import type { Metadata } from "next";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { ETIQUETA_ESTADO, type Club } from "@/lib/types";
import { Badge, Card, Eyebrow, PageHeader, Vacio } from "@/components/ui";
import { ClubForm } from "./club-form";
import { EstadoSelector } from "./estado-selector";

export const metadata: Metadata = { title: "Clubes" };

export default async function AdminPage() {
  const supabase = await createClient();

  const [{ data: clubes }, { data: miembros }] = await Promise.all([
    supabase.from("clubs").select("*").order("created_at", { ascending: false }),
    supabase.from("club_members").select("club_id"),
  ]);

  const porClub = new Map<string, number>();
  for (const m of miembros ?? []) {
    porClub.set(m.club_id, (porClub.get(m.club_id) ?? 0) + 1);
  }

  const lista = (clubes ?? []) as Club[];
  const suspendidos = lista.filter((c) => c.status === "suspended").length;
  const pendientes = lista.filter((c) => c.status === "past_due").length;

  return (
    <>
      <PageHeader
        eyebrow="Plataforma"
        title="Clubes"
        description="Alta de clientes y control de la suscripción. Suspender un club lo deja en sólo lectura al instante, sin tocar sus datos."
      />

      <div className="grid gap-8 lg:grid-cols-[minmax(0,1fr)_320px]">
        <section>
          {lista.length === 0 ? (
            <Vacio>Todavía no hay ningún club. Crea el primero aquí al lado.</Vacio>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[560px] border-collapse text-sm">
                <thead>
                  <tr className="border-b border-rule-strong text-left">
                    <th className="pb-2 pr-4 font-mono text-[0.67rem] tracking-[0.13em] text-ink-faint uppercase">
                      Club
                    </th>
                    <th className="pb-2 pr-4 font-mono text-[0.67rem] tracking-[0.13em] text-ink-faint uppercase">
                      Usuarios
                    </th>
                    <th className="pb-2 pr-4 font-mono text-[0.67rem] tracking-[0.13em] text-ink-faint uppercase">
                      Estado
                    </th>
                    <th className="pb-2 font-mono text-[0.67rem] tracking-[0.13em] text-ink-faint uppercase">
                      Cambiar a
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {lista.map((club) => {
                    const etiqueta = ETIQUETA_ESTADO[club.status];
                    return (
                      <tr key={club.id} className="border-b border-rule align-middle">
                        <td className="py-3 pr-4">
                          <Link
                            href={`/admin/${club.slug}`}
                            className="font-semibold text-ink underline-offset-4 hover:underline"
                          >
                            {club.name}
                          </Link>
                          <span className="mt-0.5 block font-mono text-xs text-ink-faint">
                            /{club.slug}
                          </span>
                        </td>
                        <td className="py-3 pr-4 tabular text-ink-soft">
                          {porClub.get(club.id) ?? 0}
                        </td>
                        <td className="py-3 pr-4">
                          <Badge
                            tono={
                              etiqueta.tono === "neutro" ? "neutro" : etiqueta.tono
                            }
                          >
                            {etiqueta.texto}
                          </Badge>
                        </td>
                        <td className="py-3">
                          <EstadoSelector clubId={club.id} estado={club.status} />
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}

          {suspendidos > 0 || pendientes > 0 ? (
            <p className="mt-4 text-sm text-ink-faint">
              {pendientes > 0 ? `${pendientes} con pago pendiente. ` : ""}
              {suspendidos > 0 ? `${suspendidos} suspendido(s).` : ""}
            </p>
          ) : null}
        </section>

        <aside className="flex flex-col gap-6">
          <Card>
            <Eyebrow>Nuevo club</Eyebrow>
            <ClubForm />
          </Card>

          <Card className="bg-surface-alt">
            <Eyebrow>Qué significa cada estado</Eyebrow>
            <dl className="flex flex-col gap-3 text-sm">
              {Object.entries(ETIQUETA_ESTADO).map(([clave, meta]) => (
                <div key={clave}>
                  <dt className="font-semibold text-ink">{meta.texto}</dt>
                  <dd className="text-ink-soft">{meta.ayuda}</dd>
                </div>
              ))}
            </dl>
          </Card>
        </aside>
      </div>
    </>
  );
}
