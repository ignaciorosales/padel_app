import type { Metadata } from "next";
import Link from "next/link";
import { requireClubAccess } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import {
  comoSeLlama,
  estadoDeUnificacion,
  type FilaDeInscrito,
  type FilaDePersona,
} from "@/lib/identidad/panel";
import { Aviso, Badge, Card, Eyebrow, PageHeader, Vacio } from "@/components/ui";
import { BotonCandidato, CrearPersona, Separar } from "./unificar-cliente";

type Params = { params: Promise<{ club: string }> };

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { club } = await params;
  const { club: datos } = await requireClubAccess(club);
  return { title: `Jugadores · ${datos.name}` };
}

/**
 * "Estos nombres parecen la misma persona".
 *
 * El club lleva tres torneos jugados y tiene ciento veinte nombres sueltos. Para
 * que exista el historial de nadie, alguien tiene que decir que el "Nacho R." de
 * marzo es el "Ignacio Rosales" de abril — y ese alguien es el club, porque una
 * unificación mal hecha mezcla dos historiales y no se deshace bien.
 *
 * Lo que hace esta pantalla es reducir esas ciento veinte decisiones a un puñado
 * de confirmaciones con el motivo delante. El orden no es alfabético a propósito:
 * **primero lo dudoso**, que es lo que necesita a una persona mirándolo. Los
 * claros son un repaso y los que no se parecen a nadie se resuelven creando ficha.
 */
export default async function JugadoresPage({ params }: Params) {
  const { club: slug } = await params;
  const { club, canWrite } = await requireClubAccess(slug);

  const supabase = await createClient();

  // Los torneos del club primero: los inscritos se filtran por ellos, y así la
  // consulta no depende de que la política de RLS esté bien escrita para siempre.
  const { data: torneos } = await supabase
    .from("tournaments")
    .select("id, nombre")
    .eq("club_id", club.id);

  const susTorneos = (torneos ?? []) as { id: string; nombre: string }[];
  const nombreDeTorneo = new Map(susTorneos.map((t) => [t.id, t.nombre]));

  let inscritos: FilaDeInscrito[] = [];
  if (susTorneos.length > 0) {
    const { data } = await supabase
      .from("tournament_players")
      .select("id, tournament_id, nombre, telefono, player_id")
      .in(
        "tournament_id",
        susTorneos.map((t) => t.id),
      )
      .order("nombre", { ascending: true });
    inscritos = (data ?? []) as FilaDeInscrito[];
  }

  // Las personas que ya tienen alguna fila en un torneo de este club. Las de
  // otros clubes no se enseñan aquí: unir un inscrito con alguien que nunca ha
  // pisado el club es un caso raro y una fuga de datos entre clubes.
  const idsDePersonas = [
    ...new Set(inscritos.map((i) => i.player_id).filter((id): id is string => id !== null)),
  ];

  let personas: FilaDePersona[] = [];
  if (idsDePersonas.length > 0) {
    const { data } = await supabase
      .from("players")
      .select("id, nombre, apellido, apodo, telefono")
      .in("id", idsDePersonas);
    personas = (data ?? []) as FilaDePersona[];
  }

  const estado = estadoDeUnificacion(inscritos, personas);
  const nombrePor: Record<string, string> = Object.fromEntries(
    personas.map((p) => [p.id, comoSeLlama(p)]),
  );

  const yaUnificados = inscritos.filter((i) => i.player_id !== null);
  const porcentaje =
    estado.total === 0 ? 0 : Math.round((estado.unificados / estado.total) * 100);

  return (
    <>
      <PageHeader
        eyebrow="Panel del club"
        title="Jugadores"
        description="Di quién es quién una vez y el historial se acumula solo, torneo a torneo."
        actions={
          estado.total > 0 ? (
            <Badge tono={porcentaje === 100 ? "ok" : "neutro"}>
              {estado.unificados} de {estado.total} identificados
            </Badge>
          ) : null
        }
      />

      {!canWrite ? (
        <Aviso tono="warn" titulo="Sólo lectura">
          La cuenta del club está suspendida: puedes ver quién falta, pero no
          identificar a nadie.
        </Aviso>
      ) : null}

      {estado.total === 0 ? (
        <Vacio>
          Todavía no hay ningún inscrito en ningún torneo.
          <br />
          Esta pantalla se llena sola en cuanto montes el primero.
        </Vacio>
      ) : null}

      {/* ---------------------------------------------------- lo que falta */}
      {estado.pendientes.length > 0 ? (
        <>
          <Eyebrow>Sin identificar · {estado.pendientes.length}</Eyebrow>
          <p className="mb-4 text-sm text-ink-soft">
            Primero los dudosos, que son los que hay que mirar. El motivo está al
            lado del botón: nadie se une solo, ni con un parecido del 99 %.
          </p>

          <div className="mb-8 flex flex-col gap-3">
            {estado.pendientes.map((pendiente) => (
              <Card key={pendiente.inscrito.id}>
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <p className="font-semibold text-ink">{pendiente.inscrito.nombre}</p>
                    <p className="mt-0.5 text-xs text-ink-faint">
                      {nombreDeTorneo.get(pendiente.inscrito.tournamentId) ??
                        "Torneo desconocido"}
                      {pendiente.inscrito.telefono
                        ? ` · ${pendiente.inscrito.telefono}`
                        : ""}
                    </p>
                  </div>

                  {canWrite ? (
                    <div className="flex flex-wrap items-start gap-3">
                      {pendiente.candidatos.map((candidato, i) => (
                        <BotonCandidato
                          key={candidato.personaId}
                          clubSlug={club.slug}
                          inscritoId={pendiente.inscrito.id}
                          candidato={candidato}
                          nombre={nombrePor[candidato.personaId] ?? "esta persona"}
                          // Destacado sólo si está claro. Con dos candidatos
                          // parecidos ninguno lleva ventaja visual: elegir por
                          // costumbre es justo lo que hay que impedir.
                          destacado={pendiente.claro && i === 0}
                        />
                      ))}

                      <CrearPersona
                        clubSlug={club.slug}
                        inscritoIds={[pendiente.inscrito.id]}
                        nombrePropuesto={pendiente.inscrito.nombre}
                        etiqueta={
                          pendiente.candidatos.length > 0
                            ? "No es ninguno"
                            : "Crear persona"
                        }
                      />
                    </div>
                  ) : null}
                </div>
              </Card>
            ))}
          </div>
        </>
      ) : null}

      {/* ------------------------------------------------- grupos a crear */}
      {estado.grupos.length > 0 ? (
        <>
          <Eyebrow>Parecen la misma persona · {estado.grupos.length}</Eyebrow>
          <p className="mb-4 text-sm text-ink-soft">
            Estos nombres están en torneos distintos y encajan entre sí, pero
            todavía no existen como persona. Créala una vez y quedan los dos
            enlazados.
          </p>

          <div className="mb-8 flex flex-col gap-3">
            {estado.grupos.map((grupo) => (
              <Card key={grupo.inscritos[0].id}>
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <p className="font-semibold text-ink">
                      {grupo.inscritos.map((i) => i.nombre).join("  ·  ")}
                    </p>
                    <p className="mt-0.5 text-xs text-ink-faint">
                      {grupo.inscritos
                        .map((i) => nombreDeTorneo.get(i.tournamentId) ?? "—")
                        .join(" · ")}
                    </p>
                  </div>

                  {canWrite ? (
                    <CrearPersona
                      clubSlug={club.slug}
                      inscritoIds={grupo.inscritos.map((i) => i.id)}
                      nombrePropuesto={grupo.nombrePropuesto}
                      etiqueta={`Crear ${grupo.nombrePropuesto}`}
                    />
                  ) : null}
                </div>
              </Card>
            ))}
          </div>
        </>
      ) : null}

      {/* --------------------------------------------------- ya resueltos */}
      {yaUnificados.length > 0 ? (
        <>
          <Eyebrow>Identificados · {yaUnificados.length}</Eyebrow>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-rule text-left text-xs text-ink-faint">
                  <th className="py-2 pr-4 font-medium">Nombre en el torneo</th>
                  <th className="py-2 pr-4 font-medium">Es</th>
                  <th className="py-2 pr-4 font-medium">Torneo</th>
                  <th className="py-2 font-medium" />
                </tr>
              </thead>
              <tbody>
                {yaUnificados.map((fila) => (
                  <tr key={fila.id} className="border-b border-rule/60">
                    <td className="py-2 pr-4 text-ink">{fila.nombre}</td>
                    <td className="py-2 pr-4 font-semibold">
                      <Link
                        href={`/panel/${club.slug}/jugadores/${fila.player_id}`}
                        className="text-accent-ink underline underline-offset-4"
                      >
                        {nombrePor[fila.player_id!] ?? "—"}
                      </Link>
                    </td>
                    <td className="py-2 pr-4 text-ink-faint">
                      {nombreDeTorneo.get(fila.tournament_id) ?? "—"}
                    </td>
                    <td className="py-2 text-right">
                      {canWrite ? (
                        <Separar clubSlug={club.slug} inscritoId={fila.id} />
                      ) : null}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      ) : null}
    </>
  );
}
