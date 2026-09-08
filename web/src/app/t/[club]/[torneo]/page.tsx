import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { BotonImprimir } from "@/components/boton-imprimir";
import { ClasificacionGrupos } from "@/components/clasificacion-grupos";
import { Badge } from "@/components/ui";
import { porcentajeJugado, rondaDestacada } from "@/lib/torneo/directo";
import {
  cargarTorneoPublico,
  descripcionDelTorneo,
  fechaLarga,
} from "@/lib/torneo/publico";
import { ETIQUETA_TORNEO, soloHoraMinuto, tituloDeRonda } from "@/lib/torneo/tipos";

type Params = { params: Promise<{ club: string; torneo: string }> };

/**
 * El día del torneo 24 personas recargan esta página cada pocos minutos.
 * Servirles a todos la misma copia durante un minuto es la diferencia entre
 * una consulta a Postgres y doscientas.
 *
 * `generateStaticParams` vacío es lo que enciende ese caché: sin él la ruta se
 * renderiza entera en cada petición. Devolviendo `[]` no se prerenderiza nada
 * en el build —los torneos aún no existen— y cada página se genera la primera
 * vez que alguien la pide y se guarda a partir de ahí.
 *
 * El minuto de retraso no se nota porque no se espera: al meter un resultado,
 * `guardarResultado` invalida esta ruta y la siguiente visita ya lo ve.
 */
export const revalidate = 60;

export function generateStaticParams() {
  return [];
}

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { club: clubSlug, torneo: torneoSlug } = await params;
  const datos = await cargarTorneoPublico(clubSlug, torneoSlug);

  if (!datos) return { title: "Torneo no encontrado" };

  const titulo = `${datos.torneo.nombre} · ${datos.club.nombre}`;
  const resumen = datos.resumen;

  return {
    title: datos.torneo.nombre,
    description: resumen,
    // Lo que ve WhatsApp al pegar el enlace. `openGraph.title` va sin la
    // plantilla "· Puntazo" del layout: en la tarjeta el que manda es el club,
    // no nosotros.
    openGraph: {
      type: "website",
      title: titulo,
      description: resumen,
      siteName: datos.club.nombre,
      locale: "es_ES",
      url: `/t/${datos.club.slug}/${datos.torneo.slug}`,
    },
    twitter: { card: "summary_large_image", title: titulo, description: resumen },
    // Es una página para compartir por enlace, no para encontrar en Google:
    // lleva nombres de socios.
    robots: { index: false, follow: false },
  };
}

export default async function TorneoPublicoPage({ params }: Params) {
  const { club: clubSlug, torneo: torneoSlug } = await params;
  const datos = await cargarTorneoPublico(clubSlug, torneoSlug);

  if (!datos) notFound();

  const {
    club,
    torneo,
    inscritos,
    rondas,
    partidosPorRonda,
    clasificacion,
    jugados,
    total,
    nombrePor,
    esParejas,
    tablasGrupo,
    nombreDePareja,
    clasificanPorGrupo,
  } = datos;

  // Un hueco del cuadro sin ocupante todavía: la ronda anterior no ha acabado.
  const nombre = (id: string | null) =>
    id ? (nombrePor.get(id) ?? "—") : "Por decidir";
  const hora = soloHoraMinuto(torneo.hora_inicio);
  const etiqueta = ETIQUETA_TORNEO[torneo.estado];

  // La ronda que toca. Con seis rondas pintadas todas igual, «¿voy yo ahora?»
  // se contesta leyendo la página entera.
  const destacada = rondaDestacada(
    rondas.map((r) => {
      const suyos = partidosPorRonda.get(r.id) ?? [];
      return {
        id: r.id,
        jugados: suyos.filter((p) => p.juegos_a !== null && p.juegos_b !== null).length,
        total: suyos.length,
      };
    }),
  );
  const porcentaje = porcentajeJugado(jugados, total);
  const rondaActual = destacada
    ? (rondas.find((r) => r.id === destacada.id) ?? null)
    : null;

  return (
    <main className="mx-auto w-full max-w-3xl px-5 py-8 sm:px-6 sm:py-12 print:max-w-none print:py-0">
      {/* ------------------------------------------------------ cabecera */}
      <header className="border-b border-rule pb-6">
        <p className="font-mono text-[0.69rem] font-medium tracking-[0.17em] text-accent uppercase">
          {club.nombre}
        </p>
        <h1 className="mt-2 text-3xl font-extrabold tracking-[-0.028em] text-balance sm:text-4xl">
          {torneo.nombre}
        </h1>
        <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-2 text-sm text-ink-soft">
          <span className="first-letter:uppercase">{fechaLarga(torneo.fecha)}</span>
          {hora ? <span className="tabular">· {hora}</span> : null}
          <span>· {inscritos.length} jugadores</span>
          <span className="print:hidden">
            <Badge tono={etiqueta.tono}>{etiqueta.texto}</Badge>
          </span>
        </div>
        {/* El progreso como línea y no como número suelto: saber por dónde va
            el torneo es media razón para volver a abrir el enlace. Se imprime
            también — en papel es el único sitio donde queda dicho hasta dónde
            llegaba la copia que alguien lleva en la mano. */}
        {total > 0 ? (
          <div className="mt-3 flex flex-col gap-1.5">
            <div className="flex items-baseline justify-between gap-3">
              <p className="font-mono text-xs text-ink-faint tabular">
                {jugados} de {total} partidos jugados
              </p>
              {torneo.estado !== "terminado" && porcentaje > 0 ? (
                <p className="font-mono text-xs text-accent tabular">{porcentaje}%</p>
              ) : null}
            </div>
            <div
              className="h-1 w-full overflow-hidden rounded-full bg-surface-alt print:border print:border-rule"
              role="img"
              aria-label={`${jugados} de ${total} partidos jugados`}
            >
              <div
                className={`h-full rounded-full ${
                  torneo.estado === "terminado" ? "bg-ok" : "bg-accent"
                }`}
                style={{ width: `${porcentaje}%` }}
              />
            </div>
          </div>
        ) : null}

        {/* El atajo a la ronda que toca.
            Sin esto, contestar «¿voy yo ahora?» en un móvil obliga a pasar la
            clasificación entera —doce filas— antes de ver el primer cruce. La
            tabla sigue arriba porque al terminar el torneo es lo que se viene a
            ver; mientras se juega, este enlace se salta el viaje. */}
        {destacada && rondaActual ? (
          <a
            href="#ahora"
            className="mt-4 flex items-center gap-2.5 rounded-sm border border-accent/30 bg-accent-soft px-3 py-2 text-sm text-accent-ink transition-colors hover:border-accent focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent print:hidden"
          >
            {/* «Ahora», no «en juego»: la insignia del torneo justo encima ya
                dice «en juego», y dos veces la misma palabra en cuatro
                centímetros se lee como un error. Aquí lo que importa es que
                esto es un atajo, no un estado. */}
            <span className="font-mono text-[0.6rem] font-medium tracking-[0.1em] uppercase">
              {destacada.marca === "en juego" ? "Ahora" : "Siguiente"}
            </span>
            <span className="font-semibold">
              {tituloDeRonda(rondaActual, torneo.formato)}
            </span>
            {soloHoraMinuto(rondaActual.hora) ? (
              <span className="ml-auto font-mono text-xs tabular">
                {soloHoraMinuto(rondaActual.hora)}
              </span>
            ) : null}
            <span aria-hidden="true" className="font-mono text-xs">
              ↓
            </span>
          </a>
        ) : null}
      </header>

      {/* ------------------------------------------------------- grupos */}
      {jugados > 0 && esParejas ? (
        <section className="mt-10">
          <h2 className="mb-3 font-mono text-[0.69rem] font-medium tracking-[0.17em] text-accent uppercase">
            Grupos
          </h2>
          <ClasificacionGrupos
            tablas={tablasGrupo}
            nombre={nombreDePareja}
            clasificanPorGrupo={clasificanPorGrupo}
            unidad={torneo.unidad_marcador ?? "juegos"}
          />
        </section>
      ) : null}

      {/* -------------------------------------------------- clasificación */}
      {jugados > 0 && !esParejas ? (
        <section className="mt-10 print:break-inside-avoid">
          <h2 className="mb-3 font-mono text-[0.69rem] font-medium tracking-[0.17em] text-accent uppercase">
            Clasificación
          </h2>

          <table className="w-full border-collapse text-sm">
            <thead>
              <tr className="border-b border-rule-strong text-left">
                <th className="pb-2 pr-2" />
                <th className="pb-2 pr-3 font-mono text-[0.67rem] tracking-[0.13em] text-ink-faint uppercase">
                  Jugador
                </th>
                <th className="pb-2 pr-3 text-right font-mono text-[0.67rem] tracking-[0.13em] text-ink-faint uppercase">
                  PJ
                </th>
                {/* En un móvil de 360 px no caben nueve columnas. Fuera las que
                    sólo miran los que discuten el desempate. */}
                <th className="hidden pb-2 pr-3 text-right font-mono text-[0.67rem] tracking-[0.13em] text-ink-faint uppercase sm:table-cell print:table-cell">
                  G
                </th>
                <th className="hidden pb-2 pr-3 text-right font-mono text-[0.67rem] tracking-[0.13em] text-ink-faint uppercase sm:table-cell print:table-cell">
                  E
                </th>
                <th className="hidden pb-2 pr-3 text-right font-mono text-[0.67rem] tracking-[0.13em] text-ink-faint uppercase sm:table-cell print:table-cell">
                  P
                </th>
                <th className="pb-2 pr-3 text-right font-mono text-[0.67rem] tracking-[0.13em] text-ink-faint uppercase">
                  JF
                </th>
                <th className="hidden pb-2 pr-3 text-right font-mono text-[0.67rem] tracking-[0.13em] text-ink-faint uppercase sm:table-cell print:table-cell">
                  JC
                </th>
                <th className="pb-2 text-right font-mono text-[0.67rem] tracking-[0.13em] text-ink-faint uppercase">
                  Dif
                </th>
              </tr>
            </thead>
            <tbody>
              {clasificacion.map((fila) => (
                <tr
                  key={fila.jugadorId}
                  className={`border-b border-rule ${
                    fila.puesto === 1 && torneo.estado === "terminado"
                      ? "bg-accent-soft"
                      : ""
                  }`}
                >
                  {/* Quien va primero se ve mientras se juega, no sólo al
                      acabar: es el dato que más se mira y el que hace que el
                      enlace se vuelva a abrir. Al terminar, la fila entera se
                      tiñe; antes basta con el número. */}
                  <td
                    className={`py-2.5 pr-2 font-mono text-xs tabular ${
                      fila.puesto === 1
                        ? "font-semibold text-accent"
                        : "text-ink-faint"
                    }`}
                  >
                    {fila.puesto}
                  </td>
                  <td className="py-2.5 pr-3 font-semibold text-ink">
                    {nombre(fila.jugadorId)}
                  </td>
                  <td className="py-2.5 pr-3 text-right tabular text-ink-soft">
                    {fila.partidos}
                  </td>
                  <td className="hidden py-2.5 pr-3 text-right tabular text-ink-soft sm:table-cell print:table-cell">
                    {fila.ganados}
                  </td>
                  <td className="hidden py-2.5 pr-3 text-right tabular text-ink-soft sm:table-cell print:table-cell">
                    {fila.empatados}
                  </td>
                  <td className="hidden py-2.5 pr-3 text-right tabular text-ink-soft sm:table-cell print:table-cell">
                    {fila.perdidos}
                  </td>
                  <td className="py-2.5 pr-3 text-right tabular text-ink-soft">
                    {fila.juegosFavor}
                  </td>
                  <td className="hidden py-2.5 pr-3 text-right tabular text-ink-soft sm:table-cell print:table-cell">
                    {fila.juegosContra}
                  </td>
                  <td className="py-2.5 text-right font-semibold tabular text-ink">
                    {fila.diferencia > 0 ? `+${fila.diferencia}` : fila.diferencia}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          <p className="mt-3 font-mono text-[0.67rem] leading-relaxed text-ink-faint">
            PJ jugados · JF juegos a favor · Dif diferencia
            <span className="hidden sm:inline print:inline">
              {" "}
              · G ganados · E empatados · P perdidos · JC juegos en contra
            </span>
          </p>
        </section>
      ) : null}

      {/* --------------------------------------------------------- rondas */}
      <section className="mt-10">
        <h2 className="mb-3 font-mono text-[0.69rem] font-medium tracking-[0.17em] text-accent uppercase">
          {jugados > 0 ? "Resultados" : "Cruces"}
        </h2>

        {rondas.length === 0 ? (
          <div className="rounded border border-dashed border-rule-strong px-6 py-10 text-center text-ink-faint">
            Los cruces todavía no están publicados.
          </div>
        ) : (
          <div className="flex flex-col gap-7">
            {rondas.map((ronda) => {
              const suyos = partidosPorRonda.get(ronda.id) ?? [];
              const jugando = new Set(
                suyos.flatMap((p) => [p.a1, p.a2, p.b1, p.b2]),
              );
              const descansan = inscritos.filter((j) => !jugando.has(j.id));
              const horaRonda = soloHoraMinuto(ronda.hora);

              const esLaQueToca = destacada?.id === ronda.id;

              return (
                <div
                  key={ronda.id}
                  id={esLaQueToca ? "ahora" : undefined}
                  className={`scroll-mt-4 print:break-inside-avoid ${
                    esLaQueToca
                      ? "-mx-3 rounded-sm border-l-2 border-accent bg-accent-soft/40 px-3 py-3 print:mx-0 print:border-l print:bg-transparent print:px-0 print:py-0"
                      : ""
                  }`}
                >
                  <div
                    className={`mb-2 flex flex-wrap items-baseline gap-x-3 gap-y-1 border-b pb-1 ${
                      esLaQueToca ? "border-accent/30" : "border-rule"
                    }`}
                  >
                    <h3 className="font-semibold text-ink">
                      {tituloDeRonda(ronda, torneo.formato)}
                    </h3>
                    {esLaQueToca ? (
                      <span className="rounded-sm bg-accent px-1.5 py-0.5 font-mono text-[0.6rem] font-medium tracking-[0.1em] text-surface uppercase print:hidden">
                        {destacada.marca}
                      </span>
                    ) : null}
                    {horaRonda ? (
                      <span className="ml-auto font-mono text-xs text-ink-faint tabular">
                        {horaRonda}
                      </span>
                    ) : null}
                  </div>

                  <ul className="flex flex-col gap-1.5">
                    {suyos.map((p) => {
                      const hayResultado =
                        p.juegos_a !== null && p.juegos_b !== null;
                      const ganaA = hayResultado && p.juegos_a! > p.juegos_b!;
                      const ganaB = hayResultado && p.juegos_b! > p.juegos_a!;

                      return (
                        <li
                          key={p.id}
                          className="flex items-center gap-3 rounded-sm bg-surface px-3 py-2.5"
                        >
                          <span className="shrink-0 font-mono text-xs text-ink-faint">
                            P{p.pista}
                          </span>

                          <div className="min-w-0 flex-1 text-sm leading-snug">
                            <div className={ganaA ? "font-semibold text-ink" : "text-ink-soft"}>
                              {nombre(p.a1)} / {nombre(p.a2)}
                            </div>
                            <div className={ganaB ? "font-semibold text-ink" : "text-ink-soft"}>
                              {nombre(p.b1)} / {nombre(p.b2)}
                            </div>
                          </div>

                          {hayResultado ? (
                            <div className="shrink-0 text-right font-mono text-base tabular">
                              <div className={ganaA ? "font-semibold text-ink" : "text-ink-faint"}>
                                {p.juegos_a}
                              </div>
                              <div className={ganaB ? "font-semibold text-ink" : "text-ink-faint"}>
                                {p.juegos_b}
                              </div>
                            </div>
                          ) : (
                            <span className="shrink-0 font-mono text-xs text-ink-faint">
                              —
                            </span>
                          )}
                        </li>
                      );
                    })}
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

      <footer className="mt-12 border-t border-rule pt-5 text-xs text-ink-faint print:mt-6">
        <p>
          {club.nombre} · {descripcionDelTorneo(torneo)}
        </p>
        <div className="mt-1 flex flex-wrap items-baseline justify-between gap-3 print:hidden">
          <p>Esta página se actualiza sola conforme se meten los resultados.</p>
          {rondas.length > 0 ? <BotonImprimir /> : null}
        </div>
      </footer>
    </main>
  );
}
