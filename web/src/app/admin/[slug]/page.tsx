import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { ETIQUETA_ESTADO, puedeEscribir, type Club, type ClubRole, type Profile } from "@/lib/types";
import { Badge, Card, Eyebrow, LinkButton, PageHeader, Vacio } from "@/components/ui";
import { quitarUsuarioDeClub } from "../actions";
import { EstadoSelector } from "../estado-selector";
import { UserForm } from "./user-form";
import { BorrarClub } from "./borrar-club";

type Params = { params: Promise<{ slug: string }> };

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { slug } = await params;
  return { title: slug };
}

export default async function ClubAdminPage({ params }: Params) {
  const { slug } = await params;
  const supabase = await createClient();

  const { data: club } = await supabase
    .from("clubs")
    .select("*")
    .eq("slug", slug)
    .single();

  if (!club) notFound();

  const { data: miembros } = await supabase
    .from("club_members")
    .select("role, user_id, profile:profiles(*)")
    .eq("club_id", club.id)
    .order("created_at", { ascending: true });

  const filas = ((miembros ?? []) as unknown as {
    role: ClubRole;
    user_id: string;
    profile: Profile | null;
  }[]);

  const c = club as Club;
  const etiqueta = ETIQUETA_ESTADO[c.status];
  const escribe = puedeEscribir(c.status);

  return (
    <>
      <PageHeader
        eyebrow={
          <Link href="/admin" className="hover:underline">
            Clubes
          </Link>
        }
        title={c.name}
        description={
          <>
            Identificador <code className="font-mono text-ink">/{c.slug}</code>. Alta:{" "}
            {new Date(c.created_at).toLocaleDateString("es-ES")}.
          </>
        }
        actions={
          <LinkButton href={`/panel/${c.slug}`}>Ver su panel</LinkButton>
        }
      />

      <div className="grid gap-8 lg:grid-cols-[minmax(0,1fr)_320px]">
        <section className="flex flex-col gap-8">
          <Card>
            <div className="flex flex-wrap items-center justify-between gap-4">
              <div>
                <Eyebrow>Suscripción</Eyebrow>
                <div className="flex items-center gap-3">
                  <Badge tono={etiqueta.tono}>{etiqueta.texto}</Badge>
                  <span className="text-sm text-ink-soft">{etiqueta.ayuda}</span>
                </div>
              </div>
              <EstadoSelector clubId={c.id} estado={c.status} />
            </div>

            {!escribe ? (
              <p className="mt-4 border-t border-rule pt-4 text-sm text-danger">
                Ahora mismo este club no puede crear ni modificar nada. Sus datos
                siguen intactos y vuelven en cuanto lo reactives.
              </p>
            ) : null}
          </Card>

          <section>
            <Eyebrow>Usuarios con acceso</Eyebrow>
            {filas.length === 0 ? (
              <Vacio>Nadie del club puede entrar todavía.</Vacio>
            ) : (
              <ul className="divide-y divide-rule border-y border-rule">
                {filas.map((m) => (
                  <li
                    key={m.user_id}
                    className="flex flex-wrap items-center justify-between gap-3 py-3"
                  >
                    <div className="min-w-0">
                      <p className="font-semibold text-ink">
                        {m.profile?.full_name ?? "Sin nombre"}
                      </p>
                      <p className="font-mono text-xs break-all text-ink-faint">
                        {m.profile?.email ?? m.user_id}
                      </p>
                    </div>
                    <div className="flex items-center gap-3">
                      <Badge tono={m.role === "owner" ? "acento" : "neutro"}>
                        {m.role === "owner" ? "Dueño" : "Personal"}
                      </Badge>
                      <form action={quitarUsuarioDeClub}>
                        <input type="hidden" name="clubId" value={c.id} />
                        <input type="hidden" name="userId" value={m.user_id} />
                        <button
                          type="submit"
                          className="text-sm text-ink-faint underline-offset-4 hover:text-danger hover:underline"
                        >
                          Quitar
                        </button>
                      </form>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </section>

          <BorrarClub clubId={c.id} slug={c.slug} usuarios={filas.length} />
        </section>

        <aside>
          <Card>
            <Eyebrow>Dar acceso a alguien</Eyebrow>
            <p className="mb-4 text-sm text-ink-soft">
              Se crea la cuenta con una contraseña temporal que se muestra una sola
              vez. No se envía ningún correo.
            </p>
            <UserForm clubId={c.id} />
          </Card>
        </aside>
      </div>
    </>
  );
}
