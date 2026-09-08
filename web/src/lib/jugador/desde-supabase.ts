import "server-only";

/**
 * El perfil de una persona, cargado de Supabase.
 *
 * Separa las consultas de `perfil.ts`, que es puro y probado. Aquí no hay ninguna
 * decisión: se leen las filas, se convierten con las funciones que ya existen y se
 * pasan. Todo lo que decida algo tiene que estar en el otro lado de esta línea o
 * no se puede probar.
 *
 * Va con la clave del usuario, no con la de servicio: **lo que el club puede ver
 * de una persona lo decide RLS**, y no una comprobación escrita a mano aquí que
 * haya que recordar actualizar. Si el club no puede ver a alguien, las consultas
 * vuelven vacías y el perfil sale como el de un desconocido.
 */

import { createClient } from "@/lib/supabase/server";
import {
  entradaDelMotor,
  type FilaDeMatch,
  type FilaDeRonda,
  type FilaDeTorneo,
} from "@/lib/rating/consultas";
import {
  partidosDeLosAmistosos,
  type FilaDeAmistoso,
} from "@/lib/rating/amistosos";
import { identidadesDe, partidosDelPanel } from "@/lib/jugador/desde-el-panel";
import {
  perfilDe,
  type FilaDeCambioDeDivision,
  type FilaDeRating,
  type FilaDeTransaccion,
  type Perfil,
} from "@/lib/jugador/perfil";
import {
  logrosDelPerfil,
  ordenados,
  resumirLogros,
  type LogroConseguido,
  type Resumen as ResumenDeLogros,
} from "@/lib/logros/catalogo";
import type { Partido } from "@/lib/historial/partidos";

export type PersonaCargada = {
  id: string;
  nombre: string;
  apellido: string | null;
  apodo: string | null;
  division_declarada: string | null;
  publico: boolean;
};

export type PerfilCargado = {
  persona: PersonaCargada;
  perfil: Perfil;
  /** Qué tiene y qué le falta. Los conseguidos primero. */
  logros: LogroConseguido[];
  resumenDeLogros: ResumenDeLogros;
  /** Los nombres de los demás, para no enseñar uuids en el cara a cara. */
  nombrePor: Map<string, string>;
  /** Nombre del torneo de cada evento del historial. */
  torneoPor: Map<string, string>;
};

/**
 * Carga el perfil de una persona dentro del contexto de un club.
 *
 * El historial que se enseña es el de los torneos **de este club** más los
 * amistosos que el club puede ver. No es el historial completo de la persona a
 * propósito: el rating sí es de toda la red —ése sale de `player_ratings`, que ya
 * lo tiene calculado con todo—, pero la lista de partidos de otros clubes no es
 * de este club para enseñarla.
 */
export async function cargarPerfil(
  clubId: string,
  personaId: string,
  hoy: string,
): Promise<PerfilCargado | null> {
  const supabase = await createClient();

  const { data: personaBruta } = await supabase
    .from("players")
    .select("id, nombre, apellido, apodo, division_declarada, publico")
    .eq("id", personaId)
    .maybeSingle();

  if (!personaBruta) return null;
  const persona = personaBruta as PersonaCargada;

  const { data: torneosBrutos } = await supabase
    .from("tournaments")
    .select("id, nombre, fecha, formato, unidad_marcador")
    .eq("club_id", clubId);

  const torneos = (torneosBrutos ?? []) as (FilaDeTorneo & { nombre: string })[];
  const idsDeTorneos = torneos.map((t) => t.id);

  let rondas: FilaDeRonda[] = [];
  let matches: FilaDeMatch[] = [];
  let inscritos: { id: string; player_id: string | null }[] = [];

  if (idsDeTorneos.length > 0) {
    const [{ data: rondasBrutas }, { data: inscritosBrutos }] = await Promise.all([
      supabase
        .from("rounds")
        .select("id, tournament_id, numero")
        .in("tournament_id", idsDeTorneos),
      supabase
        .from("tournament_players")
        .select("id, player_id")
        .in("tournament_id", idsDeTorneos),
    ]);

    rondas = (rondasBrutas ?? []) as FilaDeRonda[];
    inscritos = (inscritosBrutos ?? []) as { id: string; player_id: string | null }[];

    if (rondas.length > 0) {
      const { data } = await supabase
        .from("matches")
        .select("id, round_id, pista, a1, a2, b1, b2, juegos_a, juegos_b")
        .in(
          "round_id",
          rondas.map((r) => r.id),
        );
      matches = (data ?? []) as FilaDeMatch[];
    }
  }

  const { data: amistososBrutos } = await supabase
    .from("friendly_matches")
    .select(
      "id, club_id, fecha, a1, a2, b1, b2, marcador_a, marcador_b, unidad, estado, origen_confirmado",
    )
    .or(`a1.eq.${personaId},a2.eq.${personaId},b1.eq.${personaId},b2.eq.${personaId}`);

  const [{ data: ratingBruto }, { data: transaccionesBrutas }, { data: cambiosBrutos }] =
    await Promise.all([
      supabase
        .from("player_ratings")
        .select(
          "player_id, rating, desviacion, confianza, partidos_puntuados, ultimo_partido, escala, division, partidos_en_zona_de_ascenso, partidos_en_zona_de_descenso",
        )
        .eq("player_id", personaId)
        .maybeSingle(),
      supabase
        .from("rating_transactions")
        .select(
          "match_id, friendly_match_id, player_id, fecha, rating_antes, rating_despues, delta, probabilidad_esperada, rating_rivales, resultado",
        )
        .eq("player_id", personaId)
        .order("fecha", { ascending: true }),
      supabase
        .from("player_division_history")
        .select("player_id, fecha, anterior, nueva, tipo, rating_al_cambiar")
        .eq("player_id", personaId)
        .order("fecha", { ascending: true }),
    ]);

  // Las mismas conversiones que usa el servicio de rating. Reutilizarlas es lo
  // que garantiza que el historial cuente lo mismo que puntuó.
  const { filas } = entradaDelMotor(matches, rondas, torneos);
  const identidades = identidadesDe(
    inscritos.map((i) => ({ id: i.id, playerId: i.player_id })),
  );
  const deTorneo = partidosDelPanel(filas, identidades).partidos;
  const deAmistosos = partidosDeLosAmistosos(
    (amistososBrutos ?? []) as FilaDeAmistoso[],
  ).partidos;

  const partidos: Partido[] = [...deTorneo, ...deAmistosos];

  const perfil = perfilDe({
    jugadorId: personaId,
    rating: (ratingBruto ?? null) as FilaDeRating | null,
    transacciones: (transaccionesBrutas ?? []) as FilaDeTransaccion[],
    cambios: (cambiosBrutos ?? []) as FilaDeCambioDeDivision[],
    partidos,
    hoy,
  });

  const logros = ordenados(logrosDelPerfil(perfil));

  return {
    persona,
    perfil,
    logros,
    resumenDeLogros: resumirLogros(logros),
    nombrePor: await nombresDe(supabase, gentePresente(partidos, personaId)),
    torneoPor: new Map(torneos.map((t) => [t.id, t.nombre])),
  };
}

/** Con quién ha jugado y contra quién, sin repetirse y sin él mismo. */
function gentePresente(partidos: readonly Partido[], sinContar: string): string[] {
  const gente = new Set<string>();
  for (const partido of partidos) {
    for (const id of [...partido.a, ...partido.b]) {
      if (id !== sinContar) gente.add(id);
    }
  }
  return [...gente];
}

async function nombresDe(
  supabase: Awaited<ReturnType<typeof createClient>>,
  ids: readonly string[],
): Promise<Map<string, string>> {
  if (ids.length === 0) return new Map();

  const { data } = await supabase
    .from("players")
    .select("id, nombre, apellido, apodo")
    .in("id", ids);

  const filas = (data ?? []) as {
    id: string;
    nombre: string;
    apellido: string | null;
    apodo: string | null;
  }[];

  return new Map(
    filas.map((p) => [
      p.id,
      // El apodo gana en el historial: "perdiste con Nacho" se lee mejor que
      // "perdiste con Ignacio Rosales Pérez". En la unificación es al contrario,
      // y por eso son dos funciones distintas.
      p.apodo ?? [p.nombre, p.apellido].filter(Boolean).join(" "),
    ]),
  );
}
