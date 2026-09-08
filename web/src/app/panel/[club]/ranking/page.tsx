import type { Metadata } from "next";
import Link from "next/link";
import { requireClubAccess } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import {
  esAmbito,
  ETIQUETA_AMBITO,
  tablaDelAmbito,
  type Ambito,
  type FilaDeCoincidencia,
  type FilaDelAmbito,
} from "@/lib/jugador/ambitos";
import { Aviso, Badge, Card, Eyebrow, PageHeader, Vacio } from "@/components/ui";

type Params = {
  params: Promise<{ club: string }>;
  searchParams: Promise<{ ambito?: string; division?: string; ciudad?: string }>;
};

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { club } = await params;
  const { club: datos } = await requireClubAccess(club);
  return { title: `Ranking · ${datos.name}` };
}

type ClubConSitio = {
  id: string;
  slug: string;
  ciudad: string | null;
  pais: string;
};

/**
 * El ranking, en los cuatro ámbitos.
 *
 * Lo que hay que entender de esta pantalla no es la tabla: es **el aviso**. Un
 * ranking de club es un ranking de verdad, porque todos han jugado americanos
 * juntos y el rating los ha comparado de verdad. Un ranking de ciudad, hasta que
 * haya torneos abiertos, son doce tablas apiladas que parecen una — y eso no se
 * ve mirándola. Dos clubes separados por trescientos puntos reales que nunca se
 * cruzan acaban los dos en el mismo número.
 *
 * Por eso el ámbito por defecto es el club y por eso el aviso de "estimado" es
 * tan visible como la tabla. Enseñar un ranking de país sin decirlo sería la
 * forma más rápida de que el número deje de creerse.
 */
export default async function RankingPage({ params, searchParams }: Params) {
  const { club: slug } = await params;
  const { ambito: ambitoBruto, division: divisionBruta } = await searchParams;
  const { club } = await requireClubAccess(slug);

  const ambito: Ambito =
    ambitoBruto !== undefined && esAmbito(ambitoBruto) ? ambitoBruto : "club";
  const division = divisionBruta && divisionBruta !== "todas" ? divisionBruta : null;

  const supabase = await createClient();

  // Dónde está el club: es lo que convierte "ciudad" y "país" en un valor
  // concreto. Si el club no tiene ciudad puesta, ese ámbito no se puede pedir y
  // la pantalla lo dice en vez de devolver una tabla vacía sin explicación.
  const { data: sitioBruto } = await supabase
    .from("clubs")
    .select("id, slug, ciudad, pais")
    .eq("id", club.id)
    .maybeSingle();

  const sitio = (sitioBruto ?? null) as ClubConSitio | null;

  const valor: string | null =
    ambito === "club"
      ? club.id
      : ambito === "ciudad"
        ? (sitio?.ciudad ?? null)
        : ambito === "pais"
          ? (sitio?.pais ?? null)
          : null;

  const faltaCiudad = ambito === "ciudad" && valor === null;

  let jugadores: FilaDelAmbito[] = [];
  let coincidencias: FilaDeCoincidencia[] = [];

  if (!faltaCiudad) {
    const [{ data: jugadoresBrutos }, { data: coincidenciasBrutas }] = await Promise.all([
      supabase.rpc("jugadores_del_ambito", { p_ambito: ambito, p_valor: valor }),
      supabase.rpc("coincidencias_del_ambito", { p_ambito: ambito, p_valor: valor }),
    ]);

    jugadores = (jugadoresBrutos ?? []) as FilaDelAmbito[];
    coincidencias = (coincidenciasBrutas ?? []) as FilaDeCoincidencia[];
  }

  const tabla = tablaDelAmbito(jugadores, coincidencias, { division });

  const enlace = (cambios: { ambito?: Ambito; division?: string }) => {
    const busca = new URLSearchParams();
    busca.set("ambito", cambios.ambito ?? ambito);
    const d = cambios.division ?? division ?? "todas";
    if (d !== "todas") busca.set("division", d);
    return `/panel/${club.slug}/ranking?${busca.toString()}`;
  };

  const nombreDelAmbito =
    ambito === "club"
      ? club.name
      : ambito === "ciudad"
        ? (sitio?.ciudad ?? "sin ciudad")
        : ambito === "pais"
          ? (sitio?.pais ?? "—")
          : "toda la red";

  return (
    <>
      <PageHeader
        eyebrow="Panel del club"
        title="Ranking"
        description={`Por rating de toda la red Puntazo. Ámbito: ${nombreDelAmbito}.`}
        actions={
          tabla.fiabilidad.comparable ? (
            <Badge tono="ok">Comparable</Badge>
          ) : (
            <Badge tono="warn">Estimado</Badge>
          )
        }
      />

      {/* -------------------------------------------------------- los filtros */}
      <div className="mb-4 flex flex-wrap gap-2">
        {(["club", "ciudad", "pais", "red"] as const).map((cual) => (
          <Link
            key={cual}
            href={enlace({ ambito: cual })}
            className={`rounded-sm px-3 py-1.5 text-sm ${
              cual === ambito
                ? "bg-accent text-white"
                : "border border-rule-strong bg-surface text-ink hover:bg-surface-alt"
            }`}
          >
            {ETIQUETA_AMBITO[cual]}
          </Link>
        ))}
      </div>

      {tabla.divisiones.length > 1 ? (
        <div className="mb-6 flex flex-wrap gap-2">
          <Link
            href={enlace({ division: "todas" })}
            className={`rounded-sm px-2.5 py-1 font-mono text-xs ${
              division === null
                ? "bg-ink text-white"
                : "border border-rule bg-surface text-ink-soft hover:bg-surface-alt"
            }`}
          >
            Todas
          </Link>
          {tabla.divisiones.map((cual) => (
            <Link
              key={cual}
              href={enlace({ division: cual })}
              className={`rounded-sm px-2.5 py-1 font-mono text-xs ${
                cual === division
                  ? "bg-ink text-white"
                  : "border border-rule bg-surface text-ink-soft hover:bg-surface-alt"
              }`}
            >
              {cual}
            </Link>
          ))}
        </div>
      ) : null}

      {/* ---------------------------------------------------------- los avisos */}
      {faltaCiudad ? (
        <Aviso tono="warn" titulo="Este club no tiene ciudad puesta">
          Sin ciudad no hay ranking de ciudad. Es una columna de la ficha del club
          (<code>clubs.ciudad</code>) y la rellena la plataforma.
        </Aviso>
      ) : null}

      {!tabla.fiabilidad.comparable && tabla.fiabilidad.aviso ? (
        <Aviso tono="warn" titulo="Esta tabla es una estimación, no un ranking">
          {tabla.fiabilidad.aviso}
          <br />
          Cada partido entre gente de grupos distintos —un torneo abierto, alguien
          que juega en dos clubes— vale por diez de los demás para arreglarlo.
        </Aviso>
      ) : null}

      {/* ------------------------------------------------------------ la tabla */}
      {tabla.filas.length === 0 ? (
        <Vacio>
          {jugadores.length === 0 ? (
            <>
              Todavía no hay nadie con rating en este ámbito.
              <br />
              Identifica a los jugadores en{" "}
              <Link
                href={`/panel/${club.slug}/jugadores`}
                className="text-accent-ink underline underline-offset-4"
              >
                Jugadores
              </Link>{" "}
              y el ranking se llena en el siguiente recuento.
            </>
          ) : (
            <>
              Hay {jugadores.length}{" "}
              {jugadores.length === 1 ? "jugador" : "jugadores"}, pero{" "}
              {tabla.provisionales === 1 ? "es provisional" : "todos son provisionales"}:
              con menos de quince partidos puntuados no se entra en el ranking.
            </>
          )}
        </Vacio>
      ) : (
        <Card>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-rule text-left text-xs text-ink-faint">
                  <th className="py-2 pr-3 font-medium">#</th>
                  <th className="py-2 pr-4 font-medium">Jugador</th>
                  <th className="py-2 pr-4 font-medium">División</th>
                  <th className="py-2 pr-4 text-right font-medium">Rating</th>
                  <th className="py-2 pr-4 text-right font-medium">Partidos</th>
                  <th className="py-2 text-right font-medium" />
                </tr>
              </thead>
              <tbody>
                {tabla.filas.map((fila) => (
                  <tr key={fila.jugadorId} className="border-b border-rule/60">
                    <td className="py-2 pr-3 font-mono text-ink-faint">{fila.puesto}</td>
                    <td className="py-2 pr-4">
                      <Link
                        href={`/panel/${club.slug}/jugadores/${fila.jugadorId}`}
                        className="font-semibold text-accent-ink underline underline-offset-4"
                      >
                        {tabla.nombrePor.get(fila.jugadorId) ?? "—"}
                      </Link>
                    </td>
                    <td className="py-2 pr-4 font-mono text-xs text-ink-soft">
                      {fila.division}
                    </td>
                    <td className="py-2 pr-4 text-right font-mono font-semibold text-ink">
                      {Math.round(fila.rating)}
                    </td>
                    <td className="py-2 pr-4 text-right font-mono text-ink-faint">
                      {fila.partidos}
                    </td>
                    <td className="py-2 text-right font-mono text-xs">
                      {fila.movimiento === null ? (
                        <span className="text-ink-faint">nuevo</span>
                      ) : fila.movimiento > 0 ? (
                        <span className="text-ok">▲ {fila.movimiento}</span>
                      ) : fila.movimiento < 0 ? (
                        <span className="text-danger">▼ {-fila.movimiento}</span>
                      ) : (
                        <span className="text-ink-faint">—</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {tabla.provisionales > 0 ? (
            <p className="mt-3 text-xs text-ink-faint">
              Hay {tabla.provisionales} más con menos de quince partidos puntuados. No
              salen todavía: un rating sin base no merece un puesto.
            </p>
          ) : null}
        </Card>
      )}

      <Eyebrow>
        <span className="mt-8 block">Por qué el ámbito importa</span>
      </Eyebrow>
      <p className="text-sm text-ink-soft">
        El rating compara de verdad a quienes están unidos por partidos. Dentro de un
        club todos han jugado americanos juntos, así que su tabla es un ranking. Al
        juntar clubes que nunca se han cruzado, la tabla no queda imprecisa: dice que
        son iguales cuando no lo son. Es por eso que aparece el aviso, y no por el
        número de jugadores.
      </p>
    </>
  );
}
