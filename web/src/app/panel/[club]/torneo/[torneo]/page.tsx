import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { requireClubAccess } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { calcularClasificacion } from "@/lib/torneo/clasificacion";
import {
  ETIQUETA_TORNEO,
  soloHoraMinuto,
  type Inscrito,
  type PartidoFila,
  type RondaFila,
  type Torneo,
} from "@/lib/torneo/tipos";
import { Aviso, Badge, Card, Eyebrow, PageHeader, Vacio } from "@/components/ui";
import { quitarInscrito } from "../../actions";
import { AccionesTorneo } from "./acciones-torneo";
import { AjustesCuadro } from "./ajustes-cuadro";
import { GenerarRondas } from "./generar-rondas";
import { InscritosForm } from "./inscritos-form";
import { ResultadoForm } from "./resultado-form";

type Params = { params: Promise<{ club: string; torneo: string }> };

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { torneo } = await params;
  return { title: torneo };
}

export default async function TorneoPage({ params }: Params) {
  const { club: clubSlug, torneo: torneoSlug } = await params;
  const { club, canWrite } = await requireClubAccess(clubSlug);

  const supabase = await createClient();

  const { data: torneoBruto } = await supabase
    .from("tournaments")
    .select("*")
    .eq("club_id", club.id)
    .eq("slug", torneoSlug)
    .maybeSingle();

  if (!torneoBruto) notFound();
  const torneo = torneoBruto as Torneo;

  const [{ data: inscritosBrutos }, { data: rondasBrutas }] = await Promise.all([
    supabase
      .from("tournament_players")
      .select("*")
      .eq("tournament_id", torneo.id)
      .order("orden", { ascending: true }),
    supabase
      .from("rounds")
      .select("*")
      .eq("tournament_id", torneo.id)
      .order("numero", { ascending: true }),
  ]);

  const inscritos = (inscritosBrutos ?? []) as Inscrito[];
  const rondas = (rondasBrutas ?? []) as RondaFila[];

  let partidos: PartidoFila[] = [];
  if (rondas.length > 0) {
    const { data } = await supabase
      .from("matches")
      .select("*")
      .in("round_id", rondas.map((r) => r.id))
      .order("pista", { ascending: true });
    partidos = (data ?? []) as PartidoFila[];
  }

  const nombrePor = new Map(inscritos.map((j) => [j.id, j.nombre]));
  const nombre = (id: string) => nombrePor.get(id) ?? "—";

  const partidosPorRonda = new Map<string, PartidoFila[]>();
  for (const p of partidos) {
    const lista = partidosPorRonda.get(p.round_id) ?? [];
    lista.push(p);
    partidosPorRonda.set(p.round_id, lista);
  }

  const jugados = partidos.filter(
    (p) => p.juegos_a !== null && p.juegos_b !== null,
  );

  const clasificacion = calcularClasificacion(
    inscritos.map((j) => j.id),
    jugados.map((p) => ({
      a1: p.a1,
      a2: p.a2,
      b1: p.b1,
      b2: p.b2,
      juegosA: p.juegos_a!,
      juegosB: p.juegos_b!,
    })),
  );

  const fecha = new Date(`${torneo.fecha}T00:00:00`).toLocaleDateString("es-ES", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  });

  return (
    <>
      <PageHeader
        eyebrow={
          <Link href={`/panel/${club.slug}`} className="hover:underline">
            {club.name}
          </Link>
        }
        title={torneo.nombre}
        description={
          <>
            {fecha}
            {soloHoraMinuto(torneo.hora_inicio) ? ` · ${soloHoraMinuto(torneo.hora_inicio)}` : ""}
            {` · ${torneo.pistas} pista${torneo.pistas === 1 ? "" : "s"} · ${torneo.rondas} rondas de ${torneo.minutos_por_ronda} min`}
          </>
        }
        actions={
          <div className="flex flex-col items-end gap-2">
            <Badge tono={ETIQUETA_TORNEO[torneo.estado].tono}>
              {ETIQUETA_TORNEO[torneo.estado].texto}
            </Badge>
            {canWrite ? (
              <AccionesTorneo
                clubSlug={club.slug}
                torneoSlug={torneo.slug}
                estado={torneo.estado}
                nombre={torneo.nombre}
              />
            ) : null}
          </div>
        }
      />

      {!canWrite ? (
        <Aviso tono="danger" titulo="Cuenta suspendida">
          Este torneo se puede consultar, pero no modificar.
        </Aviso>
      ) : null}

      <div className="grid gap-8 lg:grid-cols-[minmax(0,1fr)_340px]">
        {/* ------------------------------------------------------- rondas */}
        <section>
          <Eyebrow>Rondas</Eyebrow>

          {rondas.length === 0 ? (
            <Vacio>
              Todavía no hay rondas.
              <br />
              <span className="text-sm">
                Añade los inscritos y pulsa «Generar rondas».
              </span>
            </Vacio>
          ) : (
            <div className="flex flex-col gap-6">
              {rondas.map((ronda) => {
                const suyos = partidosPorRonda.get(ronda.id) ?? [];
                const jugando = new Set(
                  suyos.flatMap((p) => [p.a1, p.a2, p.b1, p.b2]),
                );
                const descansan = inscritos.filter((j) => !jugando.has(j.id));

                return (
                  <div key={ronda.id}>
                    <div className="mb-2 flex items-baseline justify-between gap-3 border-b border-rule pb-1">
                      <h3 className="font-semibold text-ink">Ronda {ronda.numero}</h3>
                      {soloHoraMinuto(ronda.hora) ? (
                        <span className="font-mono text-xs text-ink-faint tabular">
                          {soloHoraMinuto(ronda.hora)}
                        </span>
                      ) : null}
                    </div>

                    <ul className="flex flex-col gap-2">
                      {suyos.map((p) => (
                        <li
                          key={p.id}
                          className="flex flex-wrap items-center justify-between gap-3 rounded-sm bg-surface px-3 py-2"
                        >
                          <div className="min-w-0 text-sm">
                            <span className="font-mono text-xs text-ink-faint">
                              P{p.pista}
                            </span>{" "}
                            <span className="text-ink">
                              {nombre(p.a1)} / {nombre(p.a2)}
                            </span>
                            <span className="text-ink-faint"> vs </span>
                            <span className="text-ink">
                              {nombre(p.b1)} / {nombre(p.b2)}
                            </span>
                          </div>
                          <ResultadoForm
                            clubSlug={club.slug}
                            torneoSlug={torneo.slug}
                            partidoId={p.id}
                            juegosA={p.juegos_a}
                            juegosB={p.juegos_b}
                            bloqueado={!canWrite}
                          />
                        </li>
                      ))}
                    </ul>

                    {descansan.length > 0 ? (
                      <p className="mt-2 text-xs text-ink-faint">
                        Descansan: {descansan.map((j) => j.nombre).join(", ")}
                      </p>
                    ) : null}
                  </div>
                );
              })}
            </div>
          )}
        </section>

        {/* ---------------------------------------------------- inscritos */}
        <aside className="flex flex-col gap-6">
          <Card>
            <Eyebrow>Inscritos · {inscritos.length}</Eyebrow>

            {inscritos.length === 0 ? (
              <p className="text-sm text-ink-faint">Todavía no hay nadie apuntado.</p>
            ) : (
              <ol className="mb-4 flex flex-col gap-1 text-sm">
                {inscritos.map((j, i) => (
                  <li key={j.id} className="flex items-center justify-between gap-2">
                    <span className="min-w-0 truncate text-ink">
                      <span className="font-mono text-xs text-ink-faint tabular">
                        {String(i + 1).padStart(2, "0")}
                      </span>{" "}
                      {j.nombre}
                    </span>
                    {canWrite ? (
                      <form action={quitarInscrito}>
                        <input type="hidden" name="clubSlug" value={club.slug} />
                        <input type="hidden" name="torneoSlug" value={torneo.slug} />
                        <input type="hidden" name="jugadorId" value={j.id} />
                        <button
                          type="submit"
                          aria-label={`Quitar a ${j.nombre}`}
                          className="text-ink-faint hover:text-danger"
                        >
                          ×
                        </button>
                      </form>
                    ) : null}
                  </li>
                ))}
              </ol>
            )}

            {canWrite ? (
              rondas.length === 0 ? (
                <InscritosForm clubSlug={club.slug} torneoSlug={torneo.slug} />
              ) : (
                <details className="group">
                  <summary className="cursor-pointer list-none text-sm text-accent-ink [&::-webkit-details-marker]:hidden">
                    <span className="inline-block transition-transform group-open:rotate-90">
                      ▸
                    </span>{" "}
                    Añadir más inscritos
                  </summary>
                  <div className="mt-3">
                    <p className="mb-3 text-xs text-warn">
                      Si añades gente ahora, habrá que regenerar las rondas para que
                      entre en el reparto.
                    </p>
                    <InscritosForm clubSlug={club.slug} torneoSlug={torneo.slug} />
                  </div>
                </details>
              )
            ) : null}
          </Card>

          <Card>
            <Eyebrow>Cuadro</Eyebrow>
            <AjustesCuadro
              clubSlug={club.slug}
              torneoSlug={torneo.slug}
              inscritos={inscritos.length}
              pistas={torneo.pistas}
              rondas={torneo.rondas}
              minutosPorRonda={torneo.minutos_por_ronda}
              horaInicio={torneo.hora_inicio}
              editable={canWrite}
            />
            {canWrite ? (
              <div className="mt-4 border-t border-rule pt-4">
                <GenerarRondas
                  clubSlug={club.slug}
                  torneoSlug={torneo.slug}
                  inscritos={inscritos.length}
                  yaHayRondas={rondas.length > 0}
                  hayResultados={jugados.length > 0}
                />
              </div>
            ) : null}
          </Card>
        </aside>
      </div>

      {/* ------------------------------------------------- clasificación */}
      {rondas.length > 0 ? (
        <section className="mt-10">
          <Eyebrow>Clasificación</Eyebrow>
          {jugados.length === 0 ? (
            <Vacio>Aún no hay ningún resultado.</Vacio>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[520px] border-collapse text-sm">
                <thead>
                  <tr className="border-b border-rule-strong text-left">
                    {["", "Jugador", "PJ", "G", "E", "P", "JF", "JC", "Dif"].map(
                      (h, i) => (
                        <th
                          key={i}
                          className={`pb-2 pr-4 font-mono text-[0.67rem] tracking-[0.13em] text-ink-faint uppercase ${
                            i >= 2 ? "text-right" : ""
                          }`}
                        >
                          {h}
                        </th>
                      ),
                    )}
                  </tr>
                </thead>
                <tbody>
                  {clasificacion.map((fila) => (
                    <tr key={fila.jugadorId} className="border-b border-rule">
                      <td className="py-2 pr-4 font-mono text-xs text-ink-faint tabular">
                        {fila.puesto}
                      </td>
                      <td className="py-2 pr-4 font-semibold text-ink">
                        {nombre(fila.jugadorId)}
                      </td>
                      {[
                        fila.partidos,
                        fila.ganados,
                        fila.empatados,
                        fila.perdidos,
                        fila.juegosFavor,
                        fila.juegosContra,
                      ].map((v, i) => (
                        <td key={i} className="py-2 pr-4 text-right tabular text-ink-soft">
                          {v}
                        </td>
                      ))}
                      <td className="py-2 pr-4 text-right tabular font-semibold text-ink">
                        {fila.diferencia > 0 ? `+${fila.diferencia}` : fila.diferencia}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <p className="mt-3 font-mono text-xs text-ink-faint">
                PJ jugados · G ganados · E empatados · P perdidos · JF juegos a favor ·
                JC juegos en contra
              </p>
            </div>
          )}
        </section>
      ) : null}
    </>
  );
}
