import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { requireClubAccess } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { origenPublico } from "@/lib/url";
import {
  calcularClasificacion,
  normalizarDesempates,
} from "@/lib/torneo/clasificacion";
import { clasificacionPorGrupo } from "@/lib/torneo/parejas";
import {
  ETIQUETA_TORNEO,
  esDelCuadro,
  soloHoraMinuto,
  tituloDeRonda,
  type Inscrito,
  type PartidoFila,
  type RondaFila,
  type Torneo,
} from "@/lib/torneo/tipos";
import { Aviso, Badge, Card, Eyebrow, PageHeader, Vacio } from "@/components/ui";
import { BotonImprimir } from "@/components/boton-imprimir";
import { CopiarTexto } from "@/components/copiar-texto";
import { textoClasificacion, textoRonda } from "@/lib/torneo/texto";
import { quitarInscrito, quitarPareja } from "../../actions";
import { fraseCobros, masRepetido, resumirCobros } from "@/lib/torneo/cobros";
import { AccionesTorneo } from "./acciones-torneo";
import { BotonPago, PrecioInscripcion } from "./cobros";
import { AjustesCuadro } from "./ajustes-cuadro";
import { CorregirHora, CorregirPartido } from "./corregir";
import { Desempates } from "./desempates";
import { EnlacePublico } from "./enlace-publico";
import { ClasificacionGrupos } from "@/components/clasificacion-grupos";
import { GenerarCuadroFinal } from "./generar-cuadro-final";
import { GenerarGrupos } from "./generar-grupos";
import { GenerarRondas } from "./generar-rondas";
import { InscritosForm } from "./inscritos-form";
import { ParejasForm } from "./parejas-form";
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

  // Las dos columnas de dinero son de la 0013, y el código puede estar
  // desplegado antes de que la migración se aplique: en esa ventana la fila no
  // las trae. Se normalizan aquí, una vez, en vez de defenderse en cada sitio
  // que las usa.
  const inscritos = ((inscritosBrutos ?? []) as Inscrito[]).map((j) => ({
    ...j,
    importe: typeof j.importe === "number" ? j.importe : null,
    pagado: j.pagado === true,
  }));
  const rondas = (rondasBrutas ?? []) as RondaFila[];

  // El precio que se ofrece al abrir el desplegable es el que más se repite: si
  // hay veinte a 12 € y uno a 0 €, lo que el club quiere volver a escribir es 12.
  const cobros = resumirCobros(inscritos);
  const precioMasComun = masRepetido(
    inscritos.map((j) => j.importe).filter((i): i is number => i !== null),
  );

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
  // Un hueco del cuadro sin ocupante no es un error: es que aún no ha acabado
  // la ronda anterior, y decirlo así es más útil que un guion.
  const nombre = (id: string | null) =>
    id ? (nombrePor.get(id) ?? "—") : "Por decidir";

  // ----------------------------------------------------- torneo de parejas
  const esParejas = torneo.formato === "parejas";

  type FilaPareja = {
    id: string;
    jugador1: string;
    jugador2: string;
    grupo: number;
    orden: number;
  };

  let parejas: FilaPareja[] = [];
  if (esParejas) {
    const { data } = await supabase
      .from("tournament_pairs")
      .select("id, jugador1, jugador2, grupo, orden")
      .eq("tournament_id", torneo.id)
      .order("grupo", { ascending: true })
      .order("orden", { ascending: true });
    parejas = (data ?? []) as FilaPareja[];
  }

  const nombrePareja = (id: string) => {
    const p = parejas.find((x) => x.id === id);
    return p ? `${nombre(p.jugador1)} / ${nombre(p.jugador2)}` : "—";
  };

  const partidosPorRonda = new Map<string, PartidoFila[]>();
  for (const p of partidos) {
    const lista = partidosPorRonda.get(p.round_id) ?? [];
    lista.push(p);
    partidosPorRonda.set(p.round_id, lista);
  }

  const jugados = partidos.filter(
    (p) => p.juegos_a !== null && p.juegos_b !== null,
  );

  const desempates = normalizarDesempates(torneo.desempates);

  // Un partido con resultado siempre tiene sus cuatro jugadores; el filtro está
  // para que el tipo lo sepa, no porque se espere ninguno a medias.
  const conJugadores = jugados.filter((p) => p.a1 && p.a2 && p.b1 && p.b2);

  const clasificacion = calcularClasificacion(
    inscritos.map((j) => j.id),
    conJugadores.map((p) => ({
      a1: p.a1!,
      a2: p.a2!,
      b1: p.b1!,
      b2: p.b2!,
      juegosA: p.juegos_a!,
      juegosB: p.juegos_b!,
    })),
    desempates,
  );

  // En un torneo de parejas la tabla que importa es una por grupo. La
  // individual se sigue calculando —no molesta— pero no se enseña: ahí no
  // compite nadie a título personal.
  const gruposDeParejas: string[][] = [];
  for (const p of parejas) {
    const indice = Math.max(1, p.grupo) - 1;
    (gruposDeParejas[indice] ??= []).push(p.id);
  }

  const tablasGrupo = esParejas
    ? clasificacionPorGrupo(
        gruposDeParejas.filter(Boolean),
        jugados
          .filter((p) => p.pareja_a && p.pareja_b)
          .map((p) => ({
            parejaA: p.pareja_a!,
            parejaB: p.pareja_b!,
            juegosA: p.juegos_a!,
            juegosB: p.juegos_b!,
          })),
        desempates,
      )
    : [];

  const rondasDeGrupo = rondas.filter((r) => !esDelCuadro(r));
  const rondasDeCuadro = rondas.filter((r) => esDelCuadro(r));

  // Cuántas pasan al cuadro con los ajustes actuales, sin pasarse de las que hay.
  const cuantosPasan = gruposDeParejas
    .filter(Boolean)
    .reduce(
      (n, g) => n + Math.min(g.length, torneo.clasifican_por_grupo ?? 2),
      0,
    );

  const partidosDeGrupo = partidos.filter((p) =>
    rondasDeGrupo.some((r) => r.id === p.round_id),
  );
  const gruposCompletos =
    partidosDeGrupo.length > 0 &&
    partidosDeGrupo.every((p) => p.juegos_a !== null && p.juegos_b !== null);

  // Se usa en tres sitios: el enlace de la barra lateral y los textos de ronda
  // y clasificación que se pegan en WhatsApp.
  const urlPublica = `${await origenPublico()}/t/${club.slug}/${torneo.slug}`;

  // Las pistas que se pueden elegir al corregir. Incluye las que ya se están
  // usando aunque pasen del número configurado: si alguien bajó `pistas`
  // después de generar, esas pistas siguen ocupadas y hay que poder moverlas.
  const pistasDisponibles = Array.from(
    { length: Math.max(torneo.pistas, ...partidos.map((p) => p.pista), 1) },
    (_, i) => i + 1,
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
            <Link
              href={`/panel/${club.slug}/torneo/${torneo.slug}/nivel`}
              className="text-sm text-accent-ink underline underline-offset-4 print:hidden"
            >
              Nivel y admisión
            </Link>
            {canWrite ? (
              <div className="print:hidden">
                <AccionesTorneo
                  clubSlug={club.slug}
                  torneoSlug={torneo.slug}
                  estado={torneo.estado}
                  nombre={torneo.nombre}
                />
              </div>
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
          <div className="flex flex-wrap items-baseline justify-between gap-3">
            <Eyebrow>Rondas</Eyebrow>
            {rondas.length > 0 ? (
              <BotonImprimir>Imprimir rondas y clasificación</BotonImprimir>
            ) : null}
          </div>

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
                      <h3 className="font-semibold text-ink">
                        {tituloDeRonda(ronda, torneo.formato)}
                      </h3>
                      <div className="flex items-baseline gap-3">
                        <CopiarTexto
                          etiqueta="Copiar ronda"
                          whatsapp
                          texto={textoRonda({
                            torneo: torneo.nombre,
                            numero: ronda.numero,
                            hora: soloHoraMinuto(ronda.hora),
                            partidos: suyos.map((p) => ({
                              pista: p.pista,
                              a: [nombre(p.a1), nombre(p.a2)],
                              b: [nombre(p.b1), nombre(p.b2)],
                              juegosA: p.juegos_a,
                              juegosB: p.juegos_b,
                            })),
                            descansan: descansan.map((j) => j.nombre),
                            url: torneo.publico ? urlPublica : undefined,
                          })}
                        />
                        {canWrite ? (
                          <CorregirHora
                            clubSlug={club.slug}
                            torneoSlug={torneo.slug}
                            rondaId={ronda.id}
                            hora={soloHoraMinuto(ronda.hora)}
                          />
                        ) : null}
                        {soloHoraMinuto(ronda.hora) ? (
                          <span
                            className={`font-mono text-xs text-ink-faint tabular ${
                              canWrite ? "hidden print:inline" : ""
                            }`}
                          >
                            {soloHoraMinuto(ronda.hora)}
                          </span>
                        ) : null}
                      </div>
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

                            {/* En el cuadro no se corrigen jugadores a mano:
                                quién juega cada hueco lo decide el resultado
                                anterior, y tocarlo aquí lo desincronizaría a
                                la primera. Ahí se corrige el marcador. */}
                            {canWrite && p.a1 && p.a2 && p.b1 && p.b2 && !esDelCuadro(ronda) ? (
                              <CorregirPartido
                                clubSlug={club.slug}
                                torneoSlug={torneo.slug}
                                partidoId={p.id}
                                pista={p.pista}
                                pistasDisponibles={pistasDisponibles}
                                jugadores={{ a1: p.a1, a2: p.a2, b1: p.b1, b2: p.b2 }}
                                inscritos={inscritos}
                              />
                            ) : null}
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
        {/* Inscritos, ajustes del cuadro y enlace público: todo son controles,
            nada que consultar en papel. Lo que se imprime son las rondas y la
            clasificación. */}
        <aside className="flex flex-col gap-6 print:hidden">
          {esParejas ? (
            <Card>
              <Eyebrow>Parejas · {parejas.length}</Eyebrow>

              {parejas.length === 0 ? (
                <p className="text-sm text-ink-faint">
                  Todavía no hay ninguna pareja apuntada.
                </p>
              ) : (
                <ol className="mb-4 flex flex-col gap-1 text-sm">
                  {parejas.map((p, i) => (
                    <li key={p.id} className="flex items-center justify-between gap-2">
                      <span className="min-w-0 truncate text-ink">
                        <span className="font-mono text-xs text-ink-faint tabular">
                          {String(i + 1).padStart(2, "0")}
                        </span>{" "}
                        {nombrePareja(p.id)}
                      </span>
                      {canWrite ? (
                        <form action={quitarPareja}>
                          <input type="hidden" name="clubSlug" value={club.slug} />
                          <input type="hidden" name="torneoSlug" value={torneo.slug} />
                          <input type="hidden" name="parejaId" value={p.id} />
                          <button
                            type="submit"
                            aria-label={`Quitar a ${nombrePareja(p.id)}`}
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
                  <ParejasForm clubSlug={club.slug} torneoSlug={torneo.slug} />
                ) : (
                  <details className="group">
                    <summary className="cursor-pointer list-none text-sm text-accent-ink [&::-webkit-details-marker]:hidden">
                      <span className="inline-block transition-transform group-open:rotate-90">
                        ▸
                      </span>{" "}
                      Añadir más parejas
                    </summary>
                    <div className="mt-3">
                      <p className="mb-3 text-xs text-warn">
                        Si añades parejas ahora, habrá que regenerar la fase de
                        grupos para que entren en el reparto.
                      </p>
                      <ParejasForm clubSlug={club.slug} torneoSlug={torneo.slug} />
                    </div>
                  </details>
                )
              ) : null}
            </Card>
          ) : (
          <Card>
            <Eyebrow>Inscritos · {inscritos.length}</Eyebrow>

            {cobros.hayImportes ? (
              <p className="mb-3 text-xs font-medium text-ink-soft">
                {fraseCobros(cobros)}
              </p>
            ) : null}

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
                    <span className="flex shrink-0 items-center gap-2">
                      {j.importe !== null && canWrite ? (
                        <BotonPago
                          clubSlug={club.slug}
                          torneoSlug={torneo.slug}
                          jugadorId={j.id}
                          nombre={j.nombre}
                          importe={j.importe}
                          pagado={j.pagado}
                        />
                      ) : null}
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
                    </span>
                  </li>
                ))}
              </ol>
            )}

            {canWrite && inscritos.length > 0 ? (
              <details className="group mb-4">
                <summary className="cursor-pointer list-none text-sm text-accent-ink [&::-webkit-details-marker]:hidden">
                  <span className="inline-block transition-transform group-open:rotate-90">
                    ▸
                  </span>{" "}
                  {cobros.hayImportes ? "Cambiar el precio" : "Cobrar la inscripción"}
                </summary>
                <div className="mt-3">
                  <PrecioInscripcion
                    clubSlug={club.slug}
                    torneoSlug={torneo.slug}
                    actual={precioMasComun}
                  />
                </div>
              </details>
            ) : null}

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
          )}

          {esParejas ? (
            <>
              <Card>
                <Eyebrow>Fase de grupos</Eyebrow>
                {canWrite ? (
                  <GenerarGrupos
                    clubSlug={club.slug}
                    torneoSlug={torneo.slug}
                    parejas={parejas.length}
                    grupos={torneo.grupos ?? 1}
                    yaHayJornadas={rondasDeGrupo.length > 0}
                    hayResultados={jugados.length > 0}
                  />
                ) : (
                  <p className="text-sm text-ink-soft">
                    {parejas.length} parejas en {torneo.grupos ?? 1} grupo
                    {(torneo.grupos ?? 1) === 1 ? "" : "s"}.
                  </p>
                )}
              </Card>

              {rondasDeGrupo.length > 0 && canWrite ? (
                <Card>
                  <Eyebrow>Cuadro final</Eyebrow>
                  <GenerarCuadroFinal
                    clubSlug={club.slug}
                    torneoSlug={torneo.slug}
                    clasificados={cuantosPasan}
                    gruposCompletos={gruposCompletos}
                    yaHayCuadro={rondasDeCuadro.length > 0}
                  />
                </Card>
              ) : null}
            </>
          ) : (
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
          )}

          <Card>
            <Eyebrow>Página pública</Eyebrow>
            <EnlacePublico
              clubSlug={club.slug}
              torneoSlug={torneo.slug}
              nombre={torneo.nombre}
              url={urlPublica}
              publico={torneo.publico}
              editable={canWrite}
            />
          </Card>
        </aside>
      </div>

      {/* ------------------------------------------------- clasificación */}
      {rondas.length > 0 ? (
        <section className="mt-10">
          <div className="flex flex-wrap items-baseline justify-between gap-3">
            <Eyebrow>{esParejas ? "Grupos" : "Clasificación"}</Eyebrow>
            {jugados.length > 0 ? (
              <CopiarTexto
                etiqueta="Copiar clasificación"
                whatsapp
                texto={textoClasificacion(
                  torneo.nombre,
                  (esParejas ? tablasGrupo.flat() : clasificacion).map((f) => ({
                    puesto: f.puesto,
                    nombre: esParejas ? nombrePareja(f.jugadorId) : nombre(f.jugadorId),
                    juegosFavor: f.juegosFavor,
                    diferencia: f.diferencia,
                  })),
                  torneo.publico ? urlPublica : undefined,
                )}
              />
            ) : null}
          </div>
          {jugados.length === 0 ? (
            <Vacio>Aún no hay ningún resultado.</Vacio>
          ) : esParejas ? (
            <ClasificacionGrupos
              tablas={tablasGrupo}
              nombre={nombrePareja}
              clasificanPorGrupo={torneo.clasifican_por_grupo ?? 2}
              unidad={torneo.unidad_marcador ?? "juegos"}
            />
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

          <details className="group mt-4 print:hidden">
            <summary className="cursor-pointer list-none text-xs text-ink-faint hover:text-accent-ink [&::-webkit-details-marker]:hidden">
              <span className="inline-block transition-transform group-open:rotate-90">
                ▸
              </span>{" "}
              Criterios de desempate
            </summary>
            <div className="mt-3 max-w-sm">
              <p className="mb-3 text-xs text-ink-faint">
                Se puede cambiar con el torneo empezado: sólo reordena la tabla,
                no toca ningún resultado.
              </p>
              <Desempates
                clubSlug={club.slug}
                torneoSlug={torneo.slug}
                actuales={desempates}
                editable={canWrite}
              />
            </div>
          </details>
        </section>
      ) : null}
    </>
  );
}
