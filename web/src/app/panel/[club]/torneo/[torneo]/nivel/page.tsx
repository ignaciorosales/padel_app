import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { requireClubAccess } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ESCALA_UY } from "@/lib/rating/divisiones";
import {
  admision,
  describirRestriccion,
  recontar,
  restringe,
  restriccionDeLaFila,
  type Admision,
} from "@/lib/torneo/admision";
import { Aviso, Badge, Card, Eyebrow, PageHeader, Vacio } from "@/components/ui";
import { ExcepcionForm, RestriccionForm } from "./formularios";

type Params = { params: Promise<{ club: string; torneo: string }> };

type FilaDeTorneo = {
  id: string;
  slug: string;
  nombre: string;
  rating_minimo: number | null;
  rating_maximo: number | null;
  divisiones_admitidas: (string | null)[] | null;
};

type FilaDeInscrito = {
  id: string;
  nombre: string;
  player_id: string | null;
  excepcion_aprobada: boolean;
  excepcion_motivo: string | null;
};

type FilaDeRating = {
  player_id: string;
  rating: number;
  desviacion: number;
  confianza: number;
  partidos_puntuados: number;
  ultimo_partido: string | null;
  division: string;
};

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { club, torneo } = await params;
  const { club: datos } = await requireClubAccess(club);
  return { title: `Nivel · ${torneo} · ${datos.name}` };
}

const TONO: Record<Admision["veredicto"], "ok" | "danger" | "warn" | "neutro"> = {
  encaja: "ok",
  fuera: "danger",
  excepcion: "warn",
  sin_datos: "neutro",
};

const ETIQUETA: Record<Admision["veredicto"], string> = {
  encaja: "Encaja",
  fuera: "No encaja",
  excepcion: "Excepción",
  sin_datos: "Sin datos",
};

/**
 * El nivel de un torneo: a quién está abierto y quién no encaja.
 *
 * Lo que hay que entender de esta pantalla es que **no cierra ninguna puerta.** El
 * sábado a las nueve el encargado pega veinticuatro nombres del grupo de WhatsApp
 * y de esos veinticuatro puede que cinco estén identificados; de los otros
 * diecinueve no se sabe el rating porque no se sabe quién son. Un portero que sólo
 * puede juzgar a cinco de veinticuatro no es un portero.
 *
 * Así que esto marca lo que puede marcar, deja claro qué no sabe, y le da al
 * organizador un botón para dejar entrar a quien quiera dejar entrar. Es él quien
 * conoce a la gente.
 */
export default async function NivelPage({ params }: Params) {
  const { club: slug, torneo: torneoSlug } = await params;
  const { club, canWrite } = await requireClubAccess(slug);

  const supabase = await createClient();

  const { data: torneoBruto } = await supabase
    .from("tournaments")
    .select("id, slug, nombre, rating_minimo, rating_maximo, divisiones_admitidas")
    .eq("club_id", club.id)
    .eq("slug", torneoSlug)
    .maybeSingle();

  if (!torneoBruto) notFound();
  const torneo = torneoBruto as FilaDeTorneo;
  const restriccion = restriccionDeLaFila(torneo);

  const { data: inscritosBrutos } = await supabase
    .from("tournament_players")
    .select("id, nombre, player_id, excepcion_aprobada, excepcion_motivo")
    .eq("tournament_id", torneo.id)
    .order("orden", { ascending: true });

  const inscritos = (inscritosBrutos ?? []) as FilaDeInscrito[];

  const idsDePersonas = [
    ...new Set(inscritos.map((i) => i.player_id).filter((id): id is string => id !== null)),
  ];

  let ratings: FilaDeRating[] = [];
  if (idsDePersonas.length > 0) {
    const { data } = await supabase
      .from("player_ratings")
      .select(
        "player_id, rating, desviacion, confianza, partidos_puntuados, ultimo_partido, division",
      )
      .in("player_id", idsDePersonas);
    ratings = (data ?? []) as FilaDeRating[];
  }

  const ratingPor = new Map(ratings.map((r) => [r.player_id, r]));

  const juzgados = inscritos.map((inscrito) => {
    const fila = inscrito.player_id === null ? undefined : ratingPor.get(inscrito.player_id);

    return {
      inscrito,
      veredicto: admision(restriccion, {
        rating:
          fila === undefined
            ? null
            : {
                jugadorId: fila.player_id,
                rating: fila.rating,
                desviacion: fila.desviacion,
                confianza: fila.confianza,
                partidosPuntuados: fila.partidos_puntuados,
                ultimoPartido: fila.ultimo_partido,
              },
        division: fila?.division ?? null,
        excepcionAprobada: inscrito.excepcion_aprobada,
      }),
      rating: fila ?? null,
    };
  });

  const cuenta = recontar(juzgados.map((j) => j.veredicto));

  // Lo que hay que mirar primero: quien no encaja. Después las excepciones, que son
  // decisiones ya tomadas y conviene poder revisar. Lo demás, al final.
  const orden: Record<Admision["veredicto"], number> = {
    fuera: 0,
    excepcion: 1,
    sin_datos: 2,
    encaja: 3,
  };
  const ordenados = [...juzgados].sort(
    (x, y) =>
      orden[x.veredicto.veredicto] - orden[y.veredicto.veredicto] ||
      x.inscrito.nombre.localeCompare(y.inscrito.nombre, "es"),
  );

  return (
    <>
      <PageHeader
        eyebrow={
          <Link
            href={`/panel/${club.slug}/torneo/${torneo.slug}`}
            className="hover:underline"
          >
            ← {torneo.nombre}
          </Link>
        }
        title="Nivel"
        description={describirRestriccion(restriccion)}
        actions={
          restringe(restriccion) && cuenta.fuera > 0 ? (
            <Badge tono="danger">{cuenta.fuera} no encajan</Badge>
          ) : restringe(restriccion) ? (
            <Badge tono="ok">Todos encajan</Badge>
          ) : null
        }
      />

      <Eyebrow>A quién está abierto</Eyebrow>
      <Card className="mb-8">
        <RestriccionForm
          clubSlug={club.slug}
          torneoSlug={torneo.slug}
          // De la más alta a la más baja: es el orden en que se dicen.
          divisiones={[...ESCALA_UY.divisiones].reverse().map((d) => d.nombre)}
          ratingMinimo={restriccion.ratingMinimo}
          ratingMaximo={restriccion.ratingMaximo}
          admitidas={[...restriccion.divisionesAdmitidas]}
          editable={canWrite}
        />
      </Card>

      {!restringe(restriccion) ? (
        <Aviso tono="ok" titulo="Torneo abierto">
          Sin restricción no hay nada que comprobar: cualquiera puede inscribirse. Pon
          una división o un rango arriba y esta pantalla empieza a marcar quién no
          encaja.
        </Aviso>
      ) : null}

      {restringe(restriccion) ? (
        <>
          <Eyebrow>Los inscritos · {inscritos.length}</Eyebrow>
          <p className="mb-4 text-sm text-ink-soft">
            {cuenta.encajan} encajan · {cuenta.fuera} no · {cuenta.excepciones} con
            excepción · {cuenta.sinDatos} sin datos suficientes.
            {cuenta.sinDatos > 0 ? (
              <>
                {" "}
                Los de «sin datos» no están fuera: es que todavía no se les puede
                juzgar. Identifícalos en{" "}
                <Link
                  href={`/panel/${club.slug}/jugadores`}
                  className="text-accent-ink underline underline-offset-4"
                >
                  Jugadores
                </Link>
                .
              </>
            ) : null}
          </p>

          {inscritos.length === 0 ? (
            <Vacio>Todavía no hay inscritos en este torneo.</Vacio>
          ) : (
            <div className="flex flex-col gap-2">
              {ordenados.map(({ inscrito, veredicto, rating }) => (
                <Card key={inscrito.id}>
                  <div className="flex flex-wrap items-start justify-between gap-4">
                    <div>
                      <div className="flex items-center gap-2">
                        <Badge tono={TONO[veredicto.veredicto]}>
                          {ETIQUETA[veredicto.veredicto]}
                        </Badge>
                        <span className="font-semibold text-ink">{inscrito.nombre}</span>
                        {rating ? (
                          <span className="font-mono text-xs text-ink-faint">
                            {Math.round(rating.rating)} · {rating.division}
                          </span>
                        ) : null}
                      </div>
                      {veredicto.motivo ? (
                        <p className="mt-1 text-sm text-ink-soft">{veredicto.motivo}</p>
                      ) : null}
                    </div>

                    {canWrite &&
                    (veredicto.veredicto === "fuera" ||
                      veredicto.veredicto === "excepcion") ? (
                      <ExcepcionForm
                        clubSlug={club.slug}
                        torneoSlug={torneo.slug}
                        inscritoId={inscrito.id}
                        aprobada={inscrito.excepcion_aprobada}
                        motivo={inscrito.excepcion_motivo}
                      />
                    ) : null}
                  </div>
                </Card>
              ))}
            </div>
          )}
        </>
      ) : null}
    </>
  );
}
