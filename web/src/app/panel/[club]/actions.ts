"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireClubAccess } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { generarAmericano } from "@/lib/torneo/americano";
import { parsearLista } from "@/lib/torneo/lista";
import { sumarMinutos } from "@/lib/torneo/tipos";

const SUSPENDIDO =
  "La cuenta del club está suspendida: se puede consultar, pero no modificar.";

function aSlug(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 50);
}

function entero(valor: FormDataEntryValue | null, porDefecto: number): number {
  const n = Number.parseInt(String(valor ?? ""), 10);
  return Number.isFinite(n) ? n : porDefecto;
}

// ------------------------------------------------------------- crear torneo

export type EstadoTorneoForm = { error?: string };

export async function crearTorneo(
  _previo: EstadoTorneoForm,
  formData: FormData,
): Promise<EstadoTorneoForm> {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const { club, canWrite } = await requireClubAccess(clubSlug);
  if (!canWrite) return { error: SUSPENDIDO };

  const nombre = String(formData.get("nombre") ?? "").trim();
  const fecha = String(formData.get("fecha") ?? "");
  const horaInicio = String(formData.get("hora_inicio") ?? "").trim();
  const pistas = entero(formData.get("pistas"), 0);
  const rondas = entero(formData.get("rondas"), 0);
  const minutos = entero(formData.get("minutos_por_ronda"), 20);

  if (!nombre) return { error: "El torneo necesita un nombre." };
  if (!fecha) return { error: "Falta la fecha." };
  if (pistas < 1 || pistas > 30) return { error: "Las pistas van de 1 a 30." };
  if (rondas < 1 || rondas > 40) return { error: "Las rondas van de 1 a 40." };

  const supabase = await createClient();
  const base = aSlug(nombre) || "torneo";

  // Dos americanos con el mismo nombre en el mismo club son de lo más normal.
  let slug = base;
  for (let intento = 2; intento < 40; intento++) {
    const { data: ocupado } = await supabase
      .from("tournaments")
      .select("id")
      .eq("club_id", club.id)
      .eq("slug", slug)
      .maybeSingle();
    if (!ocupado) break;
    slug = `${base}-${intento}`;
  }

  const { error } = await supabase.from("tournaments").insert({
    club_id: club.id,
    slug,
    nombre,
    fecha,
    hora_inicio: horaInicio || null,
    pistas,
    rondas,
    minutos_por_ronda: minutos,
  });

  if (error) return { error: error.message };

  revalidatePath(`/panel/${clubSlug}`);
  redirect(`/panel/${clubSlug}/torneo/${slug}`);
}

// ------------------------------------------------------------- inscripciones

async function torneoEditable(clubSlug: string, torneoSlug: string) {
  const { club, canWrite } = await requireClubAccess(clubSlug);
  const supabase = await createClient();

  const { data: torneo } = await supabase
    .from("tournaments")
    .select("*")
    .eq("club_id", club.id)
    .eq("slug", torneoSlug)
    .single();

  return { supabase, club, torneo, canWrite };
}

export type EstadoInscritos = { error?: string; anadidos?: number };

export async function anadirInscritos(
  _previo: EstadoInscritos,
  formData: FormData,
): Promise<EstadoInscritos> {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const { supabase, torneo, canWrite } = await torneoEditable(clubSlug, torneoSlug);

  if (!canWrite) return { error: SUSPENDIDO };
  if (!torneo) return { error: "Ese torneo ya no existe." };

  const pegado = String(formData.get("lista") ?? "");
  const nuevos = parsearLista(pegado);
  if (nuevos.length === 0) return { error: "No he encontrado ningún nombre ahí." };

  const { data: existentes } = await supabase
    .from("tournament_players")
    .select("nombre, orden")
    .eq("tournament_id", torneo.id);

  const yaEstan = new Set(
    (existentes ?? []).map((j) =>
      j.nombre.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, ""),
    ),
  );
  let orden = Math.max(0, ...(existentes ?? []).map((j) => j.orden));

  const aInsertar = nuevos
    .filter(
      (j) =>
        !yaEstan.has(j.nombre.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")),
    )
    .map((j) => ({
      tournament_id: torneo.id,
      nombre: j.nombre,
      telefono: j.telefono,
      orden: ++orden,
    }));

  if (aInsertar.length === 0) {
    return { error: "Todos esos nombres ya estaban inscritos." };
  }

  const { error } = await supabase.from("tournament_players").insert(aInsertar);
  if (error) return { error: error.message };

  revalidatePath(`/panel/${clubSlug}/torneo/${torneoSlug}`);
  return { anadidos: aInsertar.length };
}

export async function quitarInscrito(formData: FormData) {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const jugadorId = String(formData.get("jugadorId") ?? "");

  const { supabase, canWrite } = await torneoEditable(clubSlug, torneoSlug);
  if (!canWrite || !jugadorId) return;

  await supabase.from("tournament_players").delete().eq("id", jugadorId);
  revalidatePath(`/panel/${clubSlug}/torneo/${torneoSlug}`);
}

// ------------------------------------------------------------ generar rondas

export type EstadoGeneracion = { error?: string };

export async function generarRondas(
  _previo: EstadoGeneracion,
  formData: FormData,
): Promise<EstadoGeneracion> {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const { supabase, torneo, canWrite } = await torneoEditable(clubSlug, torneoSlug);

  if (!canWrite) return { error: SUSPENDIDO };
  if (!torneo) return { error: "Ese torneo ya no existe." };

  const { data: inscritos } = await supabase
    .from("tournament_players")
    .select("id")
    .eq("tournament_id", torneo.id)
    .order("orden", { ascending: true });

  const ids = (inscritos ?? []).map((j) => j.id);
  if (ids.length < 4) {
    return { error: "Hacen falta al menos 4 inscritos para generar las rondas." };
  }

  // Regenerar borra lo anterior, resultados incluidos. La pantalla avisa antes.
  await supabase.from("rounds").delete().eq("tournament_id", torneo.id);

  const semilla = Math.floor(Math.random() * 1_000_000) + 1;

  let cuadro;
  try {
    cuadro = generarAmericano({
      jugadores: ids,
      pistas: torneo.pistas,
      rondas: torneo.rondas,
      semilla,
    });
  } catch (e) {
    return { error: e instanceof Error ? e.message : "No se pudieron generar las rondas." };
  }

  const filasRondas = cuadro.rondas.map((r) => ({
    tournament_id: torneo.id,
    numero: r.numero,
    hora: torneo.hora_inicio
      ? sumarMinutos(torneo.hora_inicio.slice(0, 5), (r.numero - 1) * torneo.minutos_por_ronda)
      : null,
  }));

  const { data: rondasCreadas, error: errorRondas } = await supabase
    .from("rounds")
    .insert(filasRondas)
    .select("id, numero");

  if (errorRondas || !rondasCreadas) {
    return { error: errorRondas?.message ?? "No se pudieron crear las rondas." };
  }

  const idPorNumero = new Map(rondasCreadas.map((r) => [r.numero, r.id]));

  const filasPartidos = cuadro.rondas.flatMap((ronda) =>
    ronda.partidos.map((p) => ({
      round_id: idPorNumero.get(ronda.numero)!,
      pista: p.pista,
      a1: p.equipoA[0],
      a2: p.equipoA[1],
      b1: p.equipoB[0],
      b2: p.equipoB[1],
    })),
  );

  const { error: errorPartidos } = await supabase.from("matches").insert(filasPartidos);

  if (errorPartidos) {
    // Sin transacciones desde el cliente: si los partidos fallan, deshacemos
    // las rondas para no dejar un torneo a medio montar.
    await supabase.from("rounds").delete().eq("tournament_id", torneo.id);
    return { error: errorPartidos.message };
  }

  await supabase
    .from("tournaments")
    .update({ estado: "en_juego", semilla })
    .eq("id", torneo.id);

  revalidatePath(`/panel/${clubSlug}/torneo/${torneoSlug}`);
  return {};
}

// ---------------------------------------------------------------- resultados

export async function guardarResultado(formData: FormData) {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const partidoId = String(formData.get("partidoId") ?? "");

  const { supabase, canWrite } = await torneoEditable(clubSlug, torneoSlug);
  if (!canWrite || !partidoId) return;

  const brutoA = String(formData.get("juegos_a") ?? "").trim();
  const brutoB = String(formData.get("juegos_b") ?? "").trim();

  // Vaciar los dos campos borra el resultado; es como se corrige una errata.
  const vacio = brutoA === "" && brutoB === "";
  const a = Number.parseInt(brutoA, 10);
  const b = Number.parseInt(brutoB, 10);

  if (!vacio && (!Number.isFinite(a) || !Number.isFinite(b) || a < 0 || b < 0)) return;

  await supabase
    .from("matches")
    .update(vacio ? { juegos_a: null, juegos_b: null } : { juegos_a: a, juegos_b: b })
    .eq("id", partidoId);

  revalidatePath(`/panel/${clubSlug}/torneo/${torneoSlug}`);
}

// ------------------------------------------------------------ estado y borrado

export async function cambiarEstadoTorneo(formData: FormData) {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const estado = String(formData.get("estado") ?? "");

  if (!["borrador", "en_juego", "terminado"].includes(estado)) return;

  const { supabase, torneo, canWrite } = await torneoEditable(clubSlug, torneoSlug);
  if (!canWrite || !torneo) return;

  await supabase.from("tournaments").update({ estado }).eq("id", torneo.id);
  revalidatePath(`/panel/${clubSlug}/torneo/${torneoSlug}`);
}

export async function borrarTorneo(formData: FormData) {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");

  const { supabase, torneo, canWrite } = await torneoEditable(clubSlug, torneoSlug);
  if (!canWrite || !torneo) return;

  await supabase.from("tournaments").delete().eq("id", torneo.id);

  revalidatePath(`/panel/${clubSlug}`);
  redirect(`/panel/${clubSlug}`);
}

// ------------------------------------------------------- ajustes del cuadro

export type EstadoAjustes = { error?: string; ok?: boolean };

/**
 * Pistas, rondas y minutos se deciden de verdad cuando ya sabes cuánta gente
 * viene, así que se pueden cambiar después de crear el torneo. Si ya hay
 * rondas generadas hay que regenerarlas para que el cambio se note.
 */
export async function actualizarAjustes(
  _previo: EstadoAjustes,
  formData: FormData,
): Promise<EstadoAjustes> {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const { supabase, torneo, canWrite } = await torneoEditable(clubSlug, torneoSlug);

  if (!canWrite) return { error: SUSPENDIDO };
  if (!torneo) return { error: "Ese torneo ya no existe." };

  const pistas = entero(formData.get("pistas"), 0);
  const rondas = entero(formData.get("rondas"), 0);
  const minutos = entero(formData.get("minutos_por_ronda"), 0);
  const horaInicio = String(formData.get("hora_inicio") ?? "").trim();

  if (pistas < 1 || pistas > 30) return { error: "Las pistas van de 1 a 30." };
  if (rondas < 1 || rondas > 40) return { error: "Las rondas van de 1 a 40." };
  if (minutos < 5 || minutos > 180) return { error: "Los minutos van de 5 a 180." };

  const { error } = await supabase
    .from("tournaments")
    .update({
      pistas,
      rondas,
      minutos_por_ronda: minutos,
      hora_inicio: horaInicio || null,
    })
    .eq("id", torneo.id);

  if (error) return { error: error.message };

  revalidatePath(`/panel/${clubSlug}/torneo/${torneoSlug}`);
  return { ok: true };
}
