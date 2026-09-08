import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { cargarJugadorPublico } from "@/lib/jugador/publico";
import { ETIQUETA_FAMILIA } from "@/lib/logros/catalogo";
import { ESCALA_UY } from "@/lib/rating/divisiones";
import { BarraDeProgreso, Evolucion } from "@/components/evolucion";

type Params = { params: Promise<{ jugador: string }> };

/**
 * Un minuto de caché, igual que la página pública de un torneo.
 *
 * Un rating cambia como mucho una vez al día, y el enlace se abre en ráfagas
 * —alguien lo manda al grupo y lo abren seis personas seguidas— con la cobertura
 * del club. Servir la misma respuesta a todos es lo que hace que cargue.
 */
export const revalidate = 60;

function hoyISO(): string {
  return new Date().toISOString().slice(0, 10);
}

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { jugador } = await params;
  const cargado = await cargarJugadorPublico(jugador, hoyISO());

  // Una ficha apagada y un enlace mal escrito dan el mismo título: desde fuera no
  // se puede averiguar quién tiene ficha probando enlaces.
  if (!cargado) return { title: "Puntazo" };

  const { nombre, perfil, resumenDeLogros } = cargado;

  return {
    title: `${nombre} · ${perfil.rating} · ${perfil.division} · Puntazo`,
    description:
      `${nombre} juega en ${perfil.division} con ${perfil.rating} de rating. ` +
      `${perfil.resumen.actividad.partidos} partidos y ` +
      `${resumenDeLogros.conseguidos} logros en Puntazo.`,
    // El enlace se comparte por WhatsApp, y ahí lo que se ve es esta línea.
    openGraph: {
      title: `${nombre} — ${perfil.division}, ${perfil.rating}`,
      description: `${perfil.resumen.actividad.partidos} partidos · ${resumenDeLogros.conseguidos} logros`,
    },
  };
}

function conSigno(numero: number): string {
  const redondeado = Math.round(numero);
  return redondeado > 0 ? `+${redondeado}` : String(redondeado);
}

/**
 * La página pública de un jugador: el canal de reparto del producto.
 *
 * Alguien manda su enlace al grupo del club y tres personas lo abren. Lo que ven
 * tiene que contestar dos preguntas en dos segundos —**qué es esto** y **cómo
 * consigo el mío**— sin pedirles que se registren para averiguarlo.
 *
 * De ahí lo que hay y lo que no:
 *
 * - **No hay nombres de otras personas.** El historial de alguien lleva dentro con
 *   quién jugó, y esas otras tres personas no han encendido ninguna página. Las
 *   funciones de la 0019 devuelven ids y no nombres, así que esta página no puede
 *   enseñarlos ni por descuido.
 * - **Los logros están arriba, no al final.** El rating impresiona a quien ya juega;
 *   los logros son lo que hace que alguien quiera el suyo. Son la recompensa del
 *   amistoso y aquí son el anzuelo.
 */
export default async function JugadorPublicoPage({ params }: Params) {
  const { jugador } = await params;
  const cargado = await cargarJugadorPublico(jugador, hoyISO());
  if (!cargado) notFound();

  const { nombre, apodo, perfil, logros, resumenDeLogros } = cargado;
  const conseguidos = logros.filter((l) => l.conseguido);
  const treinta = perfil.movimientos.find((m) => m.dias === 30);

  return (
    <main className="mx-auto max-w-2xl px-5 py-10">
      {/* ------------------------------------------------------- la cabecera */}
      <p className="font-mono text-[0.69rem] font-medium tracking-[0.17em] text-accent uppercase">
        Puntazo
      </p>
      <h1 className="mt-1 text-3xl font-semibold text-ink">
        {nombre}
        {apodo ? <span className="text-ink-faint"> «{apodo}»</span> : null}
      </h1>

      <div className="mt-6 flex flex-wrap items-end gap-6">
        <div>
          <p className="font-mono text-5xl font-semibold text-ink">{perfil.rating}</p>
          <p className="mt-1 text-xs text-ink-faint">
            rating
            {perfil.provisional ? " · provisional" : ""}
          </p>
        </div>
        <div>
          <p className="font-mono text-3xl font-semibold text-accent-ink">{perfil.division}</p>
          <p className="mt-1 text-xs text-ink-faint">división</p>
        </div>
        {treinta && treinta.partidos > 0 ? (
          <div>
            <p
              className={`font-mono text-3xl font-semibold ${
                treinta.cambio > 0 ? "text-ok" : treinta.cambio < 0 ? "text-danger" : "text-ink"
              }`}
            >
              {conSigno(treinta.cambio)}
            </p>
            <p className="mt-1 text-xs text-ink-faint">últimos 30 días</p>
          </div>
        ) : null}
      </div>

      {perfil.provisional ? (
        <p className="mt-4 rounded-r border-l-[3px] border-l-warn bg-warn-soft px-4 py-3 text-sm text-warn">
          Rating provisional: con menos de quince partidos puntuados todavía no
          aparece en los rankings.
        </p>
      ) : null}

      {/* ------------------------------------------------------ el progreso */}
      <div className="mt-8 rounded border border-rule bg-surface p-5">
        <BarraDeProgreso
          fraccion={perfil.progreso.fraccion}
          division={perfil.progreso.division.nombre}
          siguiente={perfil.progreso.siguiente?.nombre ?? null}
          faltan={perfil.progreso.faltan}
          partidosParaConfirmar={perfil.progreso.partidosParaConfirmar}
        />
      </div>

      {/* --------------------------------------------------------- los logros */}
      <h2 className="mt-10 font-mono text-[0.69rem] font-medium tracking-[0.17em] text-accent uppercase">
        Logros · {resumenDeLogros.conseguidos} de {resumenDeLogros.total}
      </h2>

      {conseguidos.length === 0 ? (
        <p className="mt-2 text-sm text-ink-soft">
          Todavía ninguno. Se sacan jugando y apuntando los resultados, no sólo
          ganando.
        </p>
      ) : (
        <div className="mt-3 flex flex-col gap-2">
          {conseguidos.map(({ logro }) => (
            <div
              key={logro.id}
              className="flex flex-wrap items-baseline gap-x-3 rounded border border-rule bg-surface px-4 py-3"
            >
              <span className="font-semibold text-ink">{logro.nombre}</span>
              <span className="font-mono text-[0.67rem] tracking-wide text-accent uppercase">
                {ETIQUETA_FAMILIA[logro.familia]}
              </span>
              <span className="w-full text-sm text-ink-soft">{logro.descripcion}</span>
            </div>
          ))}
        </div>
      )}

      {resumenDeLogros.siguiente ? (
        <div className="mt-3 rounded border border-dashed border-rule-strong px-4 py-3">
          <p className="text-xs text-ink-faint">El siguiente</p>
          <p className="mt-0.5 font-semibold text-ink">
            {resumenDeLogros.siguiente.logro.nombre}
          </p>
          <p className="mt-0.5 text-sm text-ink-soft">
            {resumenDeLogros.siguiente.logro.descripcion} Le{" "}
            {resumenDeLogros.siguiente.falta === 1 ? "falta" : "faltan"}{" "}
            <strong className="text-ink">{resumenDeLogros.siguiente.falta}</strong>.
          </p>
        </div>
      ) : null}

      {/* ------------------------------------------------------ la evolución */}
      {perfil.evolucion.length > 0 ? (
        <>
          <h2 className="mt-10 font-mono text-[0.69rem] font-medium tracking-[0.17em] text-accent uppercase">
            Evolución
          </h2>
          <div className="mt-3 rounded border border-rule bg-surface p-5">
            <Evolucion puntos={perfil.evolucion} escala={ESCALA_UY} />
          </div>
        </>
      ) : null}

      {/* --------------------------------------------------------- el récord */}
      <h2 className="mt-10 font-mono text-[0.69rem] font-medium tracking-[0.17em] text-accent uppercase">
        Récord
      </h2>
      <div className="mt-3 grid gap-3 sm:grid-cols-3">
        <div className="rounded border border-rule bg-surface p-4">
          <p className="font-mono text-2xl font-semibold text-ink">
            {perfil.resumen.oficial.ganados}–{perfil.resumen.oficial.perdidos}
          </p>
          <p className="mt-0.5 text-xs text-ink-faint">
            en torneos · {perfil.resumen.oficial.porcentaje} %
          </p>
        </div>
        <div className="rounded border border-rule bg-surface p-4">
          <p className="font-mono text-2xl font-semibold text-ink">
            {perfil.resumen.actividad.partidos}
          </p>
          <p className="mt-0.5 text-xs text-ink-faint">partidos jugados</p>
        </div>
        <div className="rounded border border-rule bg-surface p-4">
          <p className="font-mono text-2xl font-semibold text-ink">
            {perfil.pico ? Math.round(perfil.pico.rating) : perfil.rating}
          </p>
          <p className="mt-0.5 text-xs text-ink-faint">techo histórico</p>
        </div>
      </div>

      {/* -------------------------------------------------- subidas y bajadas */}
      {perfil.cambiosDeDivision.length > 0 ? (
        <>
          <h2 className="mt-10 font-mono text-[0.69rem] font-medium tracking-[0.17em] text-accent uppercase">
            Divisiones
          </h2>
          <ul className="mt-3 flex flex-col gap-1 text-sm">
            {perfil.cambiosDeDivision.map((cambio) => (
              <li key={`${cambio.fecha}-${cambio.nueva}`} className="flex gap-3">
                <span className="font-mono text-ink-faint">{cambio.fecha}</span>
                <span className={cambio.tipo === "ascenso" ? "text-ok" : "text-danger"}>
                  {cambio.anterior} → {cambio.nueva}
                </span>
              </li>
            ))}
          </ul>
        </>
      ) : null}

      <p className="mt-12 border-t border-rule pt-6 text-sm text-ink-faint">
        Este rating es de toda la red Puntazo, no de un club: quien tiene 1650 lo
        tiene juegue donde juegue. Se calcula con los resultados de torneos y con los
        amistosos que confirman los cuatro jugadores.
      </p>
    </main>
  );
}
