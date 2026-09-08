import "server-only";

import { createPublicClient } from "@/lib/supabase/publico";
import {
  calcularClasificacion,
  normalizarDesempates,
  type FilaClasificacion,
} from "./clasificacion.ts";
import { clasificacionPorGrupo } from "./parejas.ts";
import { resumenPublico } from "./resumen.ts";
import type { InscritoPublico, PartidoFila, RondaFila, Torneo } from "./tipos.ts";

export { fechaLarga } from "./resumen.ts";

export type ClubPublico = { id: string; slug: string; nombre: string };

export type TorneoPublico = {
  club: ClubPublico;
  torneo: Torneo;
  inscritos: InscritoPublico[];
  rondas: RondaFila[];
  partidosPorRonda: Map<string, PartidoFila[]>;
  clasificacion: FilaClasificacion[];
  /** Partidos con resultado metido, sobre el total. Mueve el titular de la página. */
  jugados: number;
  total: number;
  nombrePor: Map<string, string>;
  /** Quien va primero, sólo cuando el torneo ya está cerrado. */
  campeon: string | null;
  esParejas: boolean;
  /** Una tabla por grupo. Vacío en un americano. */
  tablasGrupo: FilaClasificacion[][];
  /** Cómo se llama una pareja: "Ana / Luis". */
  nombreDePareja: (id: string) => string;
  /** Cuántas pasan al cuadro, para marcarlas en la tabla. */
  clasificanPorGrupo: number;
  /** La frase de la vista previa de WhatsApp. Se calcula una vez, aquí. */
  resumen: string;
};

/**
 * Todo lo que la página pública enseña, en una llamada.
 *
 * Lo cargan tres sitios —la página, sus metadatos y la imagen de vista previa—
 * y los tres tienen que contar lo mismo, así que la consulta vive aquí y no en
 * cada uno. Devuelve `null` cuando el torneo no existe o no es público: desde
 * fuera son indistinguibles a propósito, para que un enlace mal escrito no
 * revele que el torneo existe pero está sin publicar.
 */
export async function cargarTorneoPublico(
  clubSlug: string,
  torneoSlug: string,
): Promise<TorneoPublico | null> {
  const supabase = createPublicClient();

  // El club necesita la función: su política de lectura no deja pasar a los
  // anónimos (ver backend/migrations/0004_pagina_publica.sql).
  const { data: clubes } = await supabase.rpc("club_publico", {
    p_slug: clubSlug,
  });

  const club = (clubes as ClubPublico[] | null)?.[0];
  if (!club) return null;

  // El resto sí sale por RLS: `publico = true` es lo que lo abre.
  const { data: torneoBruto } = await supabase
    .from("tournaments")
    .select("*")
    .eq("club_id", club.id)
    .eq("slug", torneoSlug)
    .maybeSingle();

  if (!torneoBruto) return null;
  const torneo = torneoBruto as Torneo;

  const [{ data: inscritosBrutos }, { data: rondasBrutas }] = await Promise.all([
    // Columnas por su nombre, nunca `*`: desde la 0013 esta tabla guarda
    // también el importe de la inscripción y si está pagado, y eso no sale de
    // aquí. El anónimo tiene revocado el permiso sobre esas dos columnas, así
    // que un `*` que se cuele falla en vez de filtrar; esta lista es la puerta
    // y el permiso es la red debajo.
    supabase
      .from("tournament_players")
      .select("id, tournament_id, nombre, orden")
      .eq("tournament_id", torneo.id)
      .order("orden", { ascending: true }),
    supabase
      .from("rounds")
      .select("*")
      .eq("tournament_id", torneo.id)
      .order("numero", { ascending: true }),
  ]);

  const inscritos = (inscritosBrutos ?? []) as InscritoPublico[];
  const rondas = (rondasBrutas ?? []) as RondaFila[];

  let partidos: PartidoFila[] = [];
  if (rondas.length > 0) {
    const { data } = await supabase
      .from("matches")
      .select("*")
      .in(
        "round_id",
        rondas.map((r) => r.id),
      )
      .order("pista", { ascending: true });
    partidos = (data ?? []) as PartidoFila[];
  }

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
    // Un partido con resultado siempre tiene sus cuatro jugadores; el filtro
    // está para que el tipo lo sepa, no porque se espere ninguno a medias.
    jugados
      .filter((p) => p.a1 && p.a2 && p.b1 && p.b2)
      .map((p) => ({
        a1: p.a1!,
        a2: p.a2!,
        b1: p.b1!,
        b2: p.b2!,
        juegosA: p.juegos_a!,
        juegosB: p.juegos_b!,
      })),
    normalizarDesempates(torneo.desempates),
  );

  const nombrePor = new Map(inscritos.map((j) => [j.id, j.nombre]));

  // ------------------------------------------------------ torneo de parejas
  const esParejas = torneo.formato === "parejas";

  type FilaPareja = { id: string; jugador1: string; jugador2: string; grupo: number };
  let parejas: FilaPareja[] = [];

  if (esParejas) {
    const { data } = await supabase
      .from("tournament_pairs")
      .select("id, jugador1, jugador2, grupo")
      .eq("tournament_id", torneo.id)
      .order("grupo", { ascending: true })
      .order("orden", { ascending: true });
    parejas = (data ?? []) as FilaPareja[];
  }

  const nombreDePareja = (id: string) => {
    const p = parejas.find((x) => x.id === id);
    return p
      ? `${nombrePor.get(p.jugador1) ?? "—"} / ${nombrePor.get(p.jugador2) ?? "—"}`
      : "—";
  };

  const porGrupo: string[][] = [];
  for (const p of parejas) (porGrupo[Math.max(1, p.grupo) - 1] ??= []).push(p.id);

  const tablasGrupo = esParejas
    ? clasificacionPorGrupo(
        porGrupo.filter(Boolean),
        jugados
          .filter((p) => p.pareja_a && p.pareja_b)
          .map((p) => ({
            parejaA: p.pareja_a!,
            parejaB: p.pareja_b!,
            juegosA: p.juegos_a!,
            juegosB: p.juegos_b!,
          })),
        normalizarDesempates(torneo.desempates),
      )
    : [];

  // En un torneo de parejas gana quien gana la final, no quien más juegos
  // acumuló: la clasificación individual ahí no decide nada.
  const finalJugada = esParejas
    ? rondas
        .filter((r) => r.fase === "final")
        .flatMap((r) => partidosPorRonda.get(r.id) ?? [])
        .find((p) => p.juegos_a !== null && p.juegos_b !== null)
    : undefined;

  const campeonParejas = finalJugada
    ? finalJugada.juegos_a! > finalJugada.juegos_b!
      ? finalJugada.pareja_a
      : finalJugada.juegos_b! > finalJugada.juegos_a!
        ? finalJugada.pareja_b
        : null
    : null;

  const campeon = esParejas
    ? campeonParejas
      ? nombreDePareja(campeonParejas)
      : null
    : torneo.estado === "terminado" && clasificacion.length > 0
      ? (nombrePor.get(clasificacion[0].jugadorId) ?? null)
      : null;

  return {
    club,
    torneo,
    inscritos,
    rondas,
    partidosPorRonda,
    clasificacion,
    jugados: jugados.length,
    total: partidos.length,
    nombrePor,
    campeon,
    esParejas,
    tablasGrupo,
    nombreDePareja,
    clasificanPorGrupo: torneo.clasifican_por_grupo ?? 2,
    resumen: resumenPublico({
      estado: torneo.estado,
      fecha: torneo.fecha,
      jugadores: inscritos.length,
      jugados: jugados.length,
      total: partidos.length,
      campeon,
    }),
  };
}
