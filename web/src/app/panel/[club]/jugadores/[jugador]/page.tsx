import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { requireClubAccess } from "@/lib/auth";
import { cargarPerfil } from "@/lib/jugador/desde-supabase";
import { ESCALA_UY } from "@/lib/rating/divisiones";
import { Badge, Card, Eyebrow, PageHeader, Vacio } from "@/components/ui";
import { BarraDeProgreso, Evolucion } from "./evolucion";

type Params = { params: Promise<{ club: string; jugador: string }> };

/** El día de hoy en ISO. Se calcula una vez y se pasa, para que el perfil sea puro. */
function hoyISO(): string {
  return new Date().toISOString().slice(0, 10);
}

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { club, jugador } = await params;
  const { club: datos } = await requireClubAccess(club);
  const cargado = await cargarPerfil(datos.id, jugador, hoyISO());
  if (!cargado) return { title: `Jugador · ${datos.name}` };

  const { persona } = cargado;
  return {
    title: `${[persona.nombre, persona.apellido].filter(Boolean).join(" ")} · ${datos.name}`,
  };
}

function conSigno(numero: number): string {
  const redondeado = Math.round(numero);
  return redondeado > 0 ? `+${redondeado}` : String(redondeado);
}

/**
 * El perfil de un jugador visto desde el panel del club.
 *
 * Es la misma información que enseñará la app del jugador, y por eso vive en
 * `lib/jugador/`: cuando exista la app, esta pantalla no se reescribe, se traduce.
 *
 * El orden de arriba abajo es el orden en que se mira: **el número y la división
 * primero**, porque es lo que la persona viene a ver; luego cuánto se ha movido,
 * que es lo que engancha; y el historial al final, que es lo que se consulta.
 */
export default async function PerfilPage({ params }: Params) {
  const { club: slug, jugador } = await params;
  const { club } = await requireClubAccess(slug);

  const cargado = await cargarPerfil(club.id, jugador, hoyISO());
  if (!cargado) notFound();

  const { persona, perfil, nombrePor, torneoPor } = cargado;
  const nombre = [persona.nombre, persona.apellido].filter(Boolean).join(" ");
  const nombreDe = (id: string) => nombrePor.get(id) ?? "—";

  return (
    <>
      <PageHeader
        eyebrow={
          <Link href={`/panel/${club.slug}/jugadores`} className="hover:underline">
            ← Jugadores
          </Link>
        }
        title={persona.apodo ? `${nombre} «${persona.apodo}»` : nombre}
        description={
          perfil.provisional
            ? "Rating provisional: con menos de quince partidos puntuados no sale en los rankings."
            : "Rating de toda la red Puntazo, no sólo de este club."
        }
        actions={
          <>
            <Badge tono="acento">{perfil.division}</Badge>
            {perfil.provisional ? <Badge tono="warn">Provisional</Badge> : null}
          </>
        }
      />

      {/* ------------------------------------------------- el número y dónde */}
      <div className="mb-6 grid gap-4 sm:grid-cols-3">
        <Card>
          <p className="font-mono text-3xl font-semibold text-ink">{perfil.rating}</p>
          <p className="mt-1 text-xs text-ink-faint">
            Confianza {Math.round(perfil.confianza * 100)} % ·{" "}
            {perfil.partidosPuntuados}{" "}
            {perfil.partidosPuntuados === 1 ? "partido puntuado" : "partidos puntuados"}
          </p>
        </Card>

        <Card className="sm:col-span-2">
          <BarraDeProgreso
            fraccion={perfil.progreso.fraccion}
            division={perfil.progreso.division.nombre}
            siguiente={perfil.progreso.siguiente?.nombre ?? null}
            faltan={perfil.progreso.faltan}
            partidosParaConfirmar={perfil.progreso.partidosParaConfirmar}
          />
        </Card>
      </div>

      {/* ------------------------------------------------------ el movimiento */}
      <Eyebrow>Cómo se ha movido</Eyebrow>
      <div className="mb-6 grid gap-4 sm:grid-cols-4">
        {perfil.movimientos.map((movimiento) => (
          <Card key={movimiento.dias}>
            <p className="text-xs text-ink-faint">{movimiento.dias} días</p>
            <p
              className={`mt-0.5 font-mono text-xl font-semibold ${
                movimiento.cambio > 0
                  ? "text-ok"
                  : movimiento.cambio < 0
                    ? "text-danger"
                    : "text-ink-faint"
              }`}
            >
              {conSigno(movimiento.cambio)}
            </p>
            <p className="mt-0.5 text-xs text-ink-faint">
              {movimiento.partidos}{" "}
              {movimiento.partidos === 1 ? "partido" : "partidos"}
            </p>
          </Card>
        ))}

        <Card>
          <p className="text-xs text-ink-faint">Techo histórico</p>
          <p className="mt-0.5 font-mono text-xl font-semibold text-ink">
            {perfil.pico ? Math.round(perfil.pico.rating) : "—"}
          </p>
          <p className="mt-0.5 text-xs text-ink-faint">{perfil.pico?.fecha ?? "sin historia"}</p>
        </Card>
      </div>

      {/* -------------------------------------------------------- la evolución */}
      <Eyebrow>Evolución</Eyebrow>
      <Card className="mb-6">
        <Evolucion puntos={perfil.evolucion} escala={ESCALA_UY} />
      </Card>

      {/* ------------------------------------------------- subidas y bajadas */}
      {perfil.cambiosDeDivision.length > 0 ? (
        <>
          <Eyebrow>Divisiones</Eyebrow>
          <div className="mb-6 flex flex-wrap gap-2">
            {perfil.cambiosDeDivision.map((cambio) => (
              <Badge
                key={`${cambio.fecha}-${cambio.nueva}`}
                tono={cambio.tipo === "ascenso" ? "ok" : "danger"}
              >
                {cambio.fecha} · {cambio.anterior} → {cambio.nueva}
              </Badge>
            ))}
          </div>
        </>
      ) : null}

      {/* --------------------------------------------------- mejores victorias */}
      {perfil.mejoresVictorias.length > 0 ? (
        <>
          <Eyebrow>Mejores victorias</Eyebrow>
          <p className="mb-3 text-sm text-ink-soft">
            Ordenadas por la fuerza de la pareja a la que ganó, que es lo que hace
            grande una victoria.
          </p>
          <div className="mb-6 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-rule text-left text-xs text-ink-faint">
                  <th className="py-2 pr-4 font-medium">Fecha</th>
                  <th className="py-2 pr-4 font-medium">Rivales</th>
                  <th className="py-2 pr-4 font-medium">Se le daba</th>
                  <th className="py-2 font-medium">Ganó</th>
                </tr>
              </thead>
              <tbody>
                {perfil.mejoresVictorias.map((victoria) => (
                  <tr key={victoria.partidoId} className="border-b border-rule/60">
                    <td className="py-2 pr-4 text-ink-faint">{victoria.fecha}</td>
                    <td className="py-2 pr-4 font-mono text-ink">
                      {Math.round(victoria.ratingRivales)}
                    </td>
                    <td className="py-2 pr-4 text-ink-soft">
                      {Math.round(victoria.probabilidadEsperada * 100)} %
                    </td>
                    <td className="py-2 font-mono text-ok">{conSigno(victoria.delta)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      ) : null}

      {/* ------------------------------------------------------------ el récord */}
      <Eyebrow>Récord</Eyebrow>
      <div className="mb-6 grid gap-4 sm:grid-cols-2">
        <Card>
          <p className="text-xs text-ink-faint">
            Oficial · torneos y marcador. Es lo que rankea.
          </p>
          <p className="mt-1 font-mono text-xl font-semibold text-ink">
            {perfil.resumen.oficial.ganados}–{perfil.resumen.oficial.perdidos}
            {perfil.resumen.oficial.empatados > 0
              ? `–${perfil.resumen.oficial.empatados}`
              : ""}
          </p>
          <p className="mt-0.5 text-xs text-ink-faint">
            {perfil.resumen.oficial.porcentaje} % de {perfil.resumen.oficial.partidos}
            {perfil.resumen.oficial.racha.largo > 0
              ? ` · racha de ${perfil.resumen.oficial.racha.largo} ${
                  perfil.resumen.oficial.racha.tipo === "ganando" ? "ganando" : "perdiendo"
                }`
              : ""}
          </p>
        </Card>

        <Card>
          <p className="text-xs text-ink-faint">
            Actividad · todo, amistosos incluidos. Es «cuánto juega».
          </p>
          <p className="mt-1 font-mono text-xl font-semibold text-ink">
            {perfil.resumen.actividad.partidos}
          </p>
          <p className="mt-0.5 text-xs text-ink-faint">
            partidos en este club{perfil.ultimoPartido ? ` · último ${perfil.ultimoPartido}` : ""}
          </p>
        </Card>
      </div>

      {/* ------------------------------------------------------------- la gente */}
      {perfil.companeros.length > 0 || perfil.rivales.length > 0 ? (
        <>
          <Eyebrow>Con quién juega</Eyebrow>

          {/* Las dos tarjetas sólo salen cuando alguien llega al mínimo de
              partidos. Una ficha nueva no tiene némesis, y decir que sí la tiene
              es peor que dejar el hueco. */}
          {perfil.destacados.mejorCompanero || perfil.destacados.nemesis ? (
            <div className="mb-4 grid gap-4 sm:grid-cols-2">
              {perfil.destacados.mejorCompanero ? (
                <Card>
                  <p className="text-xs text-ink-faint">Mejor compañero</p>
                  <p className="mt-0.5 font-semibold text-ink">
                    {nombreDe(perfil.destacados.mejorCompanero.jugadorId)}
                  </p>
                  <p className="mt-0.5 font-mono text-xs text-ok">
                    {perfil.destacados.mejorCompanero.totales.ganados}–
                    {perfil.destacados.mejorCompanero.totales.perdidos} juntos
                  </p>
                </Card>
              ) : null}

              {perfil.destacados.nemesis ? (
                <Card>
                  <p className="text-xs text-ink-faint">Némesis</p>
                  <p className="mt-0.5 font-semibold text-ink">
                    {nombreDe(perfil.destacados.nemesis.jugadorId)}
                  </p>
                  <p className="mt-0.5 font-mono text-xs text-danger">
                    {perfil.destacados.nemesis.totales.ganados}–
                    {perfil.destacados.nemesis.totales.perdidos} en contra
                  </p>
                </Card>
              ) : null}
            </div>
          ) : null}

          <div className="mb-6 grid gap-4 sm:grid-cols-2">
            <Card>
              <p className="mb-2 text-xs text-ink-faint">Compañeros</p>
              <ul className="flex flex-col gap-1 text-sm">
                {perfil.companeros.map((fila) => (
                  <li key={fila.jugadorId} className="flex justify-between">
                    <span className="text-ink">{nombreDe(fila.jugadorId)}</span>
                    <span className="font-mono text-ink-faint">
                      {fila.totales.ganados}–{fila.totales.perdidos}
                    </span>
                  </li>
                ))}
              </ul>
            </Card>

            <Card>
              <p className="mb-2 text-xs text-ink-faint">Rivales</p>
              <ul className="flex flex-col gap-1 text-sm">
                {perfil.rivales.map((fila) => (
                  <li key={fila.jugadorId} className="flex justify-between">
                    <span className="text-ink">{nombreDe(fila.jugadorId)}</span>
                    <span className="font-mono text-ink-faint">
                      {fila.totales.ganados}–{fila.totales.perdidos}
                    </span>
                  </li>
                ))}
              </ul>
            </Card>
          </div>
        </>
      ) : null}

      {/* ---------------------------------------------------------- historial */}
      <Eyebrow>Historial</Eyebrow>
      {perfil.eventos.length === 0 ? (
        <Vacio>Todavía no ha jugado ningún partido en este club.</Vacio>
      ) : (
        <div className="flex flex-col gap-3">
          {perfil.eventos.map((evento) => (
            <Card key={evento.id}>
              <div className="flex flex-wrap items-baseline justify-between gap-2">
                <p className="font-semibold text-ink">
                  {evento.eventoId
                    ? (torneoPor.get(evento.eventoId) ?? "Torneo")
                    : "Amistoso"}
                </p>
                <p className="font-mono text-xs text-ink-faint">
                  {evento.fecha} · {evento.totales.ganados}–{evento.totales.perdidos}
                </p>
              </div>

              <ul className="mt-2 flex flex-col gap-1 text-sm">
                {evento.partidos.map((vista) => (
                  <li key={vista.partido.id} className="flex flex-wrap gap-x-2 text-ink-soft">
                    <span
                      className={
                        vista.resultado === "ganado"
                          ? "font-semibold text-ok"
                          : vista.resultado === "perdido"
                            ? "text-danger"
                            : "text-ink-faint"
                      }
                    >
                      {vista.propio}–{vista.contrario}
                    </span>
                    <span>
                      con {nombreDe(vista.companero)} · contra {nombreDe(vista.rivales[0])} y{" "}
                      {nombreDe(vista.rivales[1])}
                    </span>
                  </li>
                ))}
              </ul>
            </Card>
          ))}
        </div>
      )}
    </>
  );
}
