"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireClubAccess } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { generarAmericano } from "@/lib/torneo/americano";
import {
  DESEMPATES_PAREJAS_POR_DEFECTO,
  DESEMPATES_POR_DEFECTO,
  normalizarDesempates,
} from "@/lib/torneo/clasificacion";
import {
  moverJugador,
  moverPista,
  POSICIONES,
  type PartidoCorregible,
  type Posicion,
} from "@/lib/torneo/correccion";
import { parsearLista, parsearParejas, type ProblemaPareja } from "@/lib/torneo/lista";
import {
  clasificacionPorGrupo,
  clasificados,
  generarFaseGrupos,
} from "@/lib/torneo/parejas";
import {
  fasesEnOrden,
  generarCuadro,
  llave,
  recalcularCuadro,
  type SlotCuadro,
} from "@/lib/torneo/cuadro-final";
import { sumarMinutos } from "@/lib/torneo/tipos";

const SUSPENDIDO =
  "La cuenta del club está suspendida: se puede consultar, pero no modificar.";

/** Los mismos valores que aceptan los CHECK de la 0006. */
const FORMATOS = ["americano", "parejas"];
const UNIDADES = ["juegos", "sets", "puntos"];

/**
 * Un torneo se ve en dos sitios: el panel del club y su página pública.
 *
 * Van juntas en una función porque cualquier cambio afecta a las dos, y la
 * pública se cachea un minuto (ver /t/[club]/[torneo]): olvidarla significa
 * que quien mira el enlace desde la pista ve el resultado tarde. Separarlas
 * es olvidarse de la segunda a la octava vez.
 */
function revalidarTorneo(clubSlug: string, torneoSlug: string) {
  revalidatePath(`/panel/${clubSlug}/torneo/${torneoSlug}`);
  revalidatePath(`/t/${clubSlug}/${torneoSlug}`);
}

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

  const formato = String(formData.get("formato") ?? "americano");
  const grupos = entero(formData.get("grupos"), 1);
  const clasifican = entero(formData.get("clasifican_por_grupo"), 2);
  const unidad = String(formData.get("unidad_marcador") ?? "juegos");

  if (!nombre) return { error: "El torneo necesita un nombre." };
  if (!fecha) return { error: "Falta la fecha." };
  if (pistas < 1 || pistas > 30) return { error: "Las pistas van de 1 a 30." };
  if (!FORMATOS.includes(formato)) return { error: "Formato desconocido." };
  if (!UNIDADES.includes(unidad)) return { error: "Unidad de marcador desconocida." };

  // Las rondas sólo las decide el organizador en un americano. En uno de
  // parejas salen del cuadro: con N parejas por grupo son N-1 jornadas, y
  // discutirlo con el usuario sería pedirle que calcule algo que ya sabemos.
  if (formato === "americano" && (rondas < 1 || rondas > 40)) {
    return { error: "Las rondas van de 1 a 40." };
  }
  if (formato === "parejas") {
    if (grupos < 1 || grupos > 16) return { error: "Los grupos van de 1 a 16." };
    if (clasifican < 1 || clasifican > 8) {
      return { error: "Por grupo pueden clasificarse entre 1 y 8 parejas." };
    }
  }

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
    // En un torneo de parejas este número no lo usa nadie: las jornadas salen
    // del round-robin. Se guarda algo válido para no pelear con el CHECK.
    rondas: formato === "americano" ? rondas : 1,
    minutos_por_ronda: minutos,
    formato,
    grupos: formato === "parejas" ? grupos : 1,
    clasifican_por_grupo: formato === "parejas" ? clasifican : 2,
    unidad_marcador: unidad,
    desempates:
      formato === "parejas"
        ? DESEMPATES_PAREJAS_POR_DEFECTO
        : DESEMPATES_POR_DEFECTO,
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

  revalidarTorneo(clubSlug, torneoSlug);
  return { anadidos: aInsertar.length };
}

export async function quitarInscrito(formData: FormData) {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const jugadorId = String(formData.get("jugadorId") ?? "");

  const { supabase, canWrite } = await torneoEditable(clubSlug, torneoSlug);
  if (!canWrite || !jugadorId) return;

  await supabase.from("tournament_players").delete().eq("id", jugadorId);
  revalidarTorneo(clubSlug, torneoSlug);
}

// ---------------------------------------------------------- parejas fijas

export type EstadoParejas = {
  error?: string;
  anadidas?: number;
  /** Líneas que no se pudieron leer. Se enseñan una a una. */
  problemas?: ProblemaPareja[];
};

/**
 * Inscribe parejas pegadas, una por línea.
 *
 * Cada jugador sigue siendo una fila de `tournament_players` —lo que ata a los
 * dos es `tournament_pairs`—, y eso no es un capricho: así los cuatro nombres
 * de un partido salen de la misma tabla en los dos formatos, y la página
 * pública, el texto de WhatsApp y la impresión no se enteran de nada.
 *
 * Las líneas con problemas se devuelven en vez de descartarse. Si alguien pega
 * 16 parejas y entran 15, sin decir cuál falló se descubre el sábado.
 */
export async function anadirParejas(
  _previo: EstadoParejas,
  formData: FormData,
): Promise<EstadoParejas> {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const { supabase, torneo, canWrite } = await torneoEditable(clubSlug, torneoSlug);

  if (!canWrite) return { error: SUSPENDIDO };
  if (!torneo) return { error: "Ese torneo ya no existe." };

  const { parejas, problemas } = parsearParejas(String(formData.get("lista") ?? ""));
  if (parejas.length === 0) {
    return {
      error: "No he encontrado ninguna pareja. Escribe una por línea: «Ana / Luis».",
      problemas,
    };
  }

  // Quién está ya inscrito, para no duplicar a nadie entre tandas de pegado.
  const [{ data: existentes }, { data: parejasPrevias }] = await Promise.all([
    supabase
      .from("tournament_players")
      .select("nombre, orden")
      .eq("tournament_id", torneo.id),
    supabase
      .from("tournament_pairs")
      .select("orden")
      .eq("tournament_id", torneo.id),
  ]);

  const clave = (n: string) =>
    n.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");

  const yaEstan = new Set((existentes ?? []).map((j) => clave(j.nombre)));
  let orden = Math.max(0, ...(existentes ?? []).map((j) => j.orden));

  const problemasFinales = [...problemas];
  const nuevas: { uno: string; dos: string }[] = [];

  for (const pareja of parejas) {
    const repetido = [pareja.uno, pareja.dos].find((n) => yaEstan.has(clave(n)));
    if (repetido) {
      problemasFinales.push({
        linea: `${pareja.uno} / ${pareja.dos}`,
        motivo: `${repetido} ya estaba inscrito`,
      });
      continue;
    }
    yaEstan.add(clave(pareja.uno));
    yaEstan.add(clave(pareja.dos));
    nuevas.push(pareja);
  }

  if (nuevas.length === 0) {
    return { error: "Ninguna de esas parejas es nueva.", problemas: problemasFinales };
  }

  const jugadores = nuevas.flatMap((p) => [
    { tournament_id: torneo.id, nombre: p.uno, orden: ++orden },
    { tournament_id: torneo.id, nombre: p.dos, orden: ++orden },
  ]);

  const { data: creados, error } = await supabase
    .from("tournament_players")
    .insert(jugadores)
    .select("id, nombre, orden");

  if (error) return { error: error.message, problemas: problemasFinales };

  // Vienen en el orden en que se insertaron, así que van de dos en dos.
  const porOrden = [...(creados ?? [])].sort((a, b) => a.orden - b.orden);

  // El orden sigue donde lo dejó la tanda anterior. Empezar otra vez en 1
  // pisaría el de las parejas ya inscritas, y ese número es el que decide la
  // siembra del cuadro: dos parejas con el mismo orden es un cruce a suertes.
  let ordenPareja = Math.max(0, ...(parejasPrevias ?? []).map((p) => p.orden));

  const filasPareja = nuevas.map((_, i) => ({
    tournament_id: torneo.id,
    jugador1: porOrden[i * 2].id,
    jugador2: porOrden[i * 2 + 1].id,
    orden: ++ordenPareja,
  }));

  const { error: errorParejas } = await supabase
    .from("tournament_pairs")
    .insert(filasPareja);

  if (errorParejas) {
    // Sin la pareja, los dos jugadores sueltos sobran y ensucian la lista.
    await supabase
      .from("tournament_players")
      .delete()
      .in("id", porOrden.map((j) => j.id));
    return { error: errorParejas.message, problemas: problemasFinales };
  }

  revalidarTorneo(clubSlug, torneoSlug);
  return { anadidas: nuevas.length, problemas: problemasFinales };
}

export async function quitarPareja(formData: FormData) {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const parejaId = String(formData.get("parejaId") ?? "");

  const { supabase, torneo, canWrite } = await torneoEditable(clubSlug, torneoSlug);
  if (!canWrite || !torneo || !parejaId) return;

  const { data: pareja } = await supabase
    .from("tournament_pairs")
    .select("id, tournament_id, jugador1, jugador2")
    .eq("id", parejaId)
    .maybeSingle();

  if (!pareja || pareja.tournament_id !== torneo.id) return;

  // Borrar los jugadores arrastra la pareja por la clave ajena en cascada.
  await supabase
    .from("tournament_players")
    .delete()
    .in("id", [pareja.jugador1, pareja.jugador2]);

  revalidarTorneo(clubSlug, torneoSlug);
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

  revalidarTorneo(clubSlug, torneoSlug);
  return {};
}

// ---------------------------------------------------------------- resultados

export async function guardarResultado(formData: FormData) {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const partidoId = String(formData.get("partidoId") ?? "");

  const { supabase, torneo, canWrite } = await torneoEditable(clubSlug, torneoSlug);
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

  // Un resultado del cuadro decide quién pasa a la ronda siguiente. Se
  // recalcula el cuadro entero y no sólo el hueco de al lado: así corregir un
  // cuartos de hace dos horas arrastra la corrección hasta la final.
  if (torneo?.formato === "parejas") {
    await sincronizarCuadro(supabase, torneo.id);
  }

  revalidarTorneo(clubSlug, torneoSlug);
}

/**
 * El orden de los criterios de desempate.
 *
 * Llegan como tres campos sueltos (`criterio1`, `criterio2`, `criterio3`) en
 * vez de una lista, porque el formulario son tres desplegables: arrastrar y
 * soltar está descartado en el plan de producto. `normalizarDesempates` quita
 * los vacíos y los repetidos, así que elegir dos veces lo mismo no rompe nada,
 * simplemente cuenta una.
 */
export async function actualizarDesempates(formData: FormData) {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");

  const elegidos = ["criterio1", "criterio2", "criterio3"]
    .map((campo) => String(formData.get(campo) ?? ""))
    .filter((c) => c !== "");

  const { supabase, torneo, canWrite } = await torneoEditable(clubSlug, torneoSlug);
  if (!canWrite || !torneo) return;

  await supabase
    .from("tournaments")
    .update({ desempates: normalizarDesempates(elegidos) })
    .eq("id", torneo.id);

  revalidarTorneo(clubSlug, torneoSlug);
}

/**
 * Genera la fase de grupos de un torneo de parejas.
 *
 * Guarda los cuatro jugadores en a1/a2/b1/b2 igual que un americano, **y
 * además** de qué pareja es cada lado. Esa duplicación aparente es lo que
 * permite que la página pública y la impresión sigan sin saber nada de
 * formatos: leen jugadores, como siempre.
 */
export async function generarGrupos(
  _previo: EstadoGeneracion,
  formData: FormData,
): Promise<EstadoGeneracion> {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const { supabase, torneo, canWrite } = await torneoEditable(clubSlug, torneoSlug);

  if (!canWrite) return { error: SUSPENDIDO };
  if (!torneo) return { error: "Ese torneo ya no existe." };
  if (torneo.formato !== "parejas") {
    return { error: "Este torneo no es de parejas." };
  }

  const { data: parejas } = await supabase
    .from("tournament_pairs")
    .select("id, jugador1, jugador2")
    .eq("tournament_id", torneo.id)
    .order("orden", { ascending: true });

  const lista = parejas ?? [];
  if (lista.length < 2) {
    return { error: "Hacen falta al menos 2 parejas para generar la fase de grupos." };
  }

  let fase;
  try {
    fase = generarFaseGrupos({
      parejas: lista.map((p) => p.id),
      grupos: torneo.grupos ?? 1,
      pistas: torneo.pistas,
    });
  } catch (e) {
    return { error: e instanceof Error ? e.message : "No se pudo generar el cuadro." };
  }

  // Regenerar borra lo anterior, resultados incluidos. La pantalla avisa antes.
  await supabase.from("rounds").delete().eq("tournament_id", torneo.id);

  // El grupo de cada pareja se guarda para poder pintar una tabla por grupo.
  for (let i = 0; i < fase.grupos.length; i++) {
    const ids = fase.grupos[i];
    if (ids.length > 0) {
      await supabase
        .from("tournament_pairs")
        .update({ grupo: i + 1 })
        .in("id", ids);
    }
  }

  const { data: rondasCreadas, error: errorRondas } = await supabase
    .from("rounds")
    .insert(
      fase.jornadas.map((j) => ({
        tournament_id: torneo.id,
        numero: j.numero,
        fase: "grupo",
        hora: torneo.hora_inicio
          ? sumarMinutos(
              torneo.hora_inicio.slice(0, 5),
              (j.numero - 1) * torneo.minutos_por_ronda,
            )
          : null,
      })),
    )
    .select("id, numero");

  if (errorRondas) return { error: errorRondas.message };

  const idDeRonda = new Map((rondasCreadas ?? []).map((r) => [r.numero, r.id]));
  const jugadoresDe = new Map(lista.map((p) => [p.id, p]));

  const partidos = fase.jornadas.flatMap((j) =>
    j.partidos.map((p) => {
      const a = jugadoresDe.get(p.parejaA)!;
      const b = jugadoresDe.get(p.parejaB)!;
      return {
        round_id: idDeRonda.get(j.numero)!,
        pista: p.pista,
        a1: a.jugador1,
        a2: a.jugador2,
        b1: b.jugador1,
        b2: b.jugador2,
        pareja_a: p.parejaA,
        pareja_b: p.parejaB,
      };
    }),
  );

  const { error } = await supabase.from("matches").insert(partidos);
  if (error) return { error: error.message };

  revalidarTorneo(clubSlug, torneoSlug);
  return {};
}

// ------------------------------------------------------------ cuadro final

type ParejaBD = { id: string; jugador1: string; jugador2: string; grupo: number };

/**
 * Recalcula el cuadro entero desde los resultados y lo escribe.
 *
 * No va apuntando ganadores a mano según se meten: reconstruye el cuadro
 * completo cada vez a partir de la siembra (que no cambia) y de los resultados
 * (que sí). Corregir un cuartos de hace dos horas arrastra la corrección hasta
 * la final sola, en vez de dejar una semifinal con la pareja equivocada
 * esperando a que alguien se dé cuenta.
 *
 * No hace nada si el torneo no es de parejas o aún no tiene cuadro.
 */
async function sincronizarCuadro(
  supabase: Awaited<ReturnType<typeof createClient>>,
  torneoId: string,
) {
  const { data: rondas } = await supabase
    .from("rounds")
    .select("id, fase")
    .eq("tournament_id", torneoId)
    .neq("fase", "grupo");

  if (!rondas || rondas.length === 0) return;

  const { data: partidos } = await supabase
    .from("matches")
    .select("id, round_id, orden, pareja_a, pareja_b, juegos_a, juegos_b")
    .in("round_id", rondas.map((r) => r.id));

  if (!partidos || partidos.length === 0) return;

  const faseDeRonda = new Map(rondas.map((r) => [r.id, r.fase as string]));
  const conFase = partidos.map((p) => ({ ...p, fase: faseDeRonda.get(p.round_id)! }));

  // La primera ronda es la que más partidos tiene; su siembra es intocable.
  const cuantos = new Map<string, number>();
  for (const p of conFase) cuantos.set(p.fase, (cuantos.get(p.fase) ?? 0) + 1);
  const primera = [...cuantos.entries()].sort((a, b) => b[1] - a[1])[0][0];

  // Los ocupantes tal y como están guardados. Hacen falta enteros —no sólo la
  // siembra— para que recalcularCuadro pueda ver cuáles han cambiado y tirar
  // los resultados que eran de otras parejas.
  const guardados: SlotCuadro[] = conFase.map((p) => ({
    fase: p.fase,
    orden: p.orden,
    parejaA: p.pareja_a,
    parejaB: p.pareja_b,
  }));

  const resultados = new Map<string, { juegosA: number; juegosB: number }>();
  for (const p of conFase) {
    if (p.juegos_a !== null && p.juegos_b !== null) {
      resultados.set(llave(p.fase, p.orden), {
        juegosA: p.juegos_a,
        juegosB: p.juegos_b,
      });
    }
  }

  const { cuadro: avanzado, resultados: vivos } = recalcularCuadro(
    guardados,
    resultados,
  );

  const { data: parejas } = await supabase
    .from("tournament_pairs")
    .select("id, jugador1, jugador2")
    .eq("tournament_id", torneoId);

  const jugadoresDe = new Map((parejas ?? []).map((p) => [p.id, p]));

  for (const slot of avanzado) {
    const fila = conFase.find((p) => p.fase === slot.fase && p.orden === slot.orden);
    if (!fila) continue;
    // La siembra de la primera ronda no se toca nunca.
    if (fila.fase === primera) continue;

    const cambianOcupantes =
      fila.pareja_a !== slot.parejaA || fila.pareja_b !== slot.parejaB;

    // Un resultado que recalcularCuadro ha descartado era de parejas que ya no
    // juegan ese partido: hay que borrarlo aunque los ocupantes no cambien en
    // esta pasada.
    const teniaResultado = fila.juegos_a !== null && fila.juegos_b !== null;
    const pierdeResultado = teniaResultado && !vivos.has(llave(fila.fase, fila.orden));

    if (!cambianOcupantes && !pierdeResultado) continue;

    const a = slot.parejaA ? jugadoresDe.get(slot.parejaA) : null;
    const b = slot.parejaB ? jugadoresDe.get(slot.parejaB) : null;

    await supabase
      .from("matches")
      .update({
        pareja_a: slot.parejaA,
        pareja_b: slot.parejaB,
        a1: a?.jugador1 ?? null,
        a2: a?.jugador2 ?? null,
        b1: b?.jugador1 ?? null,
        b2: b?.jugador2 ?? null,
        ...(pierdeResultado || cambianOcupantes
          ? { juegos_a: null, juegos_b: null }
          : {}),
      })
      .eq("id", fila.id);
  }
}

/**
 * Genera el cuadro eliminatorio a partir de la clasificación de los grupos.
 */
export async function generarCuadroFinal(
  _previo: EstadoGeneracion,
  formData: FormData,
): Promise<EstadoGeneracion> {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const { supabase, torneo, canWrite } = await torneoEditable(clubSlug, torneoSlug);

  if (!canWrite) return { error: SUSPENDIDO };
  if (!torneo) return { error: "Ese torneo ya no existe." };
  if (torneo.formato !== "parejas") return { error: "Este torneo no es de parejas." };

  const { data: parejasBrutas } = await supabase
    .from("tournament_pairs")
    .select("id, jugador1, jugador2, grupo")
    .eq("tournament_id", torneo.id)
    .order("orden", { ascending: true });

  const parejas = (parejasBrutas ?? []) as ParejaBD[];
  if (parejas.length < 2) return { error: "No hay parejas suficientes." };

  const { data: rondasGrupo } = await supabase
    .from("rounds")
    .select("id, numero")
    .eq("tournament_id", torneo.id)
    .eq("fase", "grupo");

  if (!rondasGrupo || rondasGrupo.length === 0) {
    return { error: "Genera antes la fase de grupos." };
  }

  const { data: partidosGrupo } = await supabase
    .from("matches")
    .select("pareja_a, pareja_b, juegos_a, juegos_b")
    .in("round_id", rondasGrupo.map((r) => r.id));

  const jugados = (partidosGrupo ?? []).filter(
    (p) => p.juegos_a !== null && p.juegos_b !== null && p.pareja_a && p.pareja_b,
  );

  if (jugados.length === 0) {
    return { error: "Todavía no hay ningún resultado en la fase de grupos." };
  }

  const porGrupo: string[][] = [];
  for (const p of parejas) {
    (porGrupo[Math.max(1, p.grupo) - 1] ??= []).push(p.id);
  }

  const tablas = clasificacionPorGrupo(
    porGrupo.filter(Boolean),
    jugados.map((p) => ({
      parejaA: p.pareja_a!,
      parejaB: p.pareja_b!,
      juegosA: p.juegos_a!,
      juegosB: p.juegos_b!,
    })),
    normalizarDesempates(torneo.desempates),
  );

  const pasan = clasificados(
    tablas.map((t) => t.map((f) => f.jugadorId)),
    torneo.clasifican_por_grupo ?? 2,
  );

  if (pasan.length < 2) {
    return { error: "Con los ajustes actuales sólo se clasifica una pareja." };
  }

  let cuadro;
  try {
    cuadro = generarCuadro(pasan);
  } catch (e) {
    return { error: e instanceof Error ? e.message : "No se pudo generar el cuadro." };
  }

  // Regenerar el cuadro borra el anterior, pero nunca la fase de grupos.
  await supabase
    .from("rounds")
    .delete()
    .eq("tournament_id", torneo.id)
    .neq("fase", "grupo");

  const fases = fasesEnOrden(cuadro);
  const ultimaJornada = Math.max(...rondasGrupo.map((r) => r.numero));

  const { data: rondasCreadas, error: errorRondas } = await supabase
    .from("rounds")
    .insert(
      fases.map((fase, i) => ({
        tournament_id: torneo.id,
        numero: ultimaJornada + i + 1,
        fase,
        hora: torneo.hora_inicio
          ? sumarMinutos(
              torneo.hora_inicio.slice(0, 5),
              (ultimaJornada + i) * torneo.minutos_por_ronda,
            )
          : null,
      })),
    )
    .select("id, fase");

  if (errorRondas) return { error: errorRondas.message };

  const rondaDeFase = new Map((rondasCreadas ?? []).map((r) => [r.fase as string, r.id]));
  const jugadoresDe = new Map(parejas.map((p) => [p.id, p]));

  const filas = cuadro.map((slot) => {
    const a = slot.parejaA ? jugadoresDe.get(slot.parejaA) : null;
    const b = slot.parejaB ? jugadoresDe.get(slot.parejaB) : null;
    return {
      round_id: rondaDeFase.get(slot.fase)!,
      // La pista es sólo dónde se juega y el organizador la cambia a gusto; la
      // posición en el cuadro es `orden` y no la toca nadie.
      pista: slot.orden + 1,
      orden: slot.orden,
      pareja_a: slot.parejaA,
      pareja_b: slot.parejaB,
      a1: a?.jugador1 ?? null,
      a2: a?.jugador2 ?? null,
      b1: b?.jugador1 ?? null,
      b2: b?.jugador2 ?? null,
    };
  });

  const { error } = await supabase.from("matches").insert(filas);
  if (error) return { error: error.message };

  revalidarTorneo(clubSlug, torneoSlug);
  return {};
}

// ---------------------------------------------------- correcciones del cuadro

/**
 * Carga los partidos de la ronda a la que pertenece un partido, comprobando
 * que esa ronda es de este torneo. Sin esa comprobación, un `partidoId`
 * inventado dejaría tocar el cuadro de otro club: las políticas RLS lo
 * pararían igualmente, pero la autorización no se delega en un solo sitio.
 */
async function rondaDelPartido(
  clubSlug: string,
  torneoSlug: string,
  partidoId: string,
) {
  const { supabase, torneo, canWrite } = await torneoEditable(clubSlug, torneoSlug);
  if (!canWrite || !torneo || !partidoId) return null;

  const { data: partido } = await supabase
    .from("matches")
    .select("round_id")
    .eq("id", partidoId)
    .maybeSingle();

  if (!partido) return null;

  const { data: ronda } = await supabase
    .from("rounds")
    .select("id,tournament_id")
    .eq("id", partido.round_id)
    .maybeSingle();

  if (!ronda || ronda.tournament_id !== torneo.id) return null;

  const { data: partidos } = await supabase
    .from("matches")
    .select("id,pista,a1,a2,b1,b2")
    .eq("round_id", ronda.id)
    .order("pista", { ascending: true });

  return { supabase, partidos: (partidos ?? []) as PartidoCorregible[] };
}

export async function corregirJugador(formData: FormData) {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const partidoId = String(formData.get("partidoId") ?? "");
  const posicion = String(formData.get("posicion") ?? "");
  const jugadorId = String(formData.get("jugadorId") ?? "");

  if (!POSICIONES.includes(posicion as Posicion)) return;

  const ctx = await rondaDelPartido(clubSlug, torneoSlug, partidoId);
  if (!ctx) return;

  for (const cambio of moverJugador(
    ctx.partidos,
    partidoId,
    posicion as Posicion,
    jugadorId,
  )) {
    await ctx.supabase.from("matches").update(cambio.campos).eq("id", cambio.id);
  }

  revalidarTorneo(clubSlug, torneoSlug);
}

export async function corregirPista(formData: FormData) {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const partidoId = String(formData.get("partidoId") ?? "");
  const pista = entero(formData.get("pista"), 0);

  if (pista < 1) return;

  const ctx = await rondaDelPartido(clubSlug, torneoSlug, partidoId);
  if (!ctx) return;

  const cambios = moverPista(ctx.partidos, partidoId, pista);
  if (cambios.length === 0) return;

  // Intercambio: hay un `unique (round_id, pista)` de por medio, así que el
  // ocupante tiene que apartarse a una pista libre antes de que el otro entre.
  // Sin este paso el primer UPDATE de los dos choca contra el índice.
  if (cambios.length === 2) {
    const libre = Math.max(...ctx.partidos.map((p) => p.pista), pista) + 1;
    await ctx.supabase
      .from("matches")
      .update({ pista: libre })
      .eq("id", cambios[1].id);
  }

  for (const cambio of cambios) {
    await ctx.supabase.from("matches").update(cambio.campos).eq("id", cambio.id);
  }

  revalidarTorneo(clubSlug, torneoSlug);
}

export async function corregirHora(formData: FormData) {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const rondaId = String(formData.get("rondaId") ?? "");
  const hora = String(formData.get("hora") ?? "").trim();

  // Vaciar la hora es válido: hay clubes que no las anuncian.
  if (hora !== "" && !/^\d{2}:\d{2}$/.test(hora)) return;

  const { supabase, torneo, canWrite } = await torneoEditable(clubSlug, torneoSlug);
  if (!canWrite || !torneo || !rondaId) return;

  await supabase
    .from("rounds")
    .update({ hora: hora === "" ? null : hora })
    .eq("id", rondaId)
    .eq("tournament_id", torneo.id);

  revalidarTorneo(clubSlug, torneoSlug);
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
  revalidarTorneo(clubSlug, torneoSlug);
}

/**
 * Publicar o retirar la página pública del torneo.
 *
 * Revalida también la ruta pública: si no, un torneo retirado seguiría
 * viéndose hasta un minuto —lo que tarda el `revalidate` de /t— y retirar la
 * página es justo lo que se hace con prisa cuando alguien pide no aparecer.
 */
export async function cambiarVisibilidad(formData: FormData) {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");
  const publico = formData.get("publico") === "si";

  const { supabase, torneo, canWrite } = await torneoEditable(clubSlug, torneoSlug);
  if (!canWrite || !torneo) return;

  await supabase.from("tournaments").update({ publico }).eq("id", torneo.id);

  revalidarTorneo(clubSlug, torneoSlug);
}

export async function borrarTorneo(formData: FormData) {
  const clubSlug = String(formData.get("clubSlug") ?? "");
  const torneoSlug = String(formData.get("torneoSlug") ?? "");

  const { supabase, torneo, canWrite } = await torneoEditable(clubSlug, torneoSlug);
  if (!canWrite || !torneo) return;

  await supabase.from("tournaments").delete().eq("id", torneo.id);

  revalidarTorneo(clubSlug, torneoSlug);
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

  revalidarTorneo(clubSlug, torneoSlug);
  return { ok: true };
}
