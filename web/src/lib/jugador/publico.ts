import "server-only";

/**
 * La página pública de un jugador, cargada sin sesión.
 *
 * Todo pasa por las cuatro funciones de la 0019, que sólo devuelven filas si la
 * ficha está encendida. Eso significa que **la comprobación de "es público" no se
 * hace aquí**: se hace en la base de datos, en las cuatro. Si estuviera aquí,
 * añadir una quinta consulta un día y olvidar el `if` sería una fuga.
 *
 * Lo que sí se hace aquí es montar el perfil con el mismo `perfilDe()` que el
 * panel y calcular los logros con el mismo catálogo. La página pública y la privada
 * dicen lo mismo del mismo jugador porque es literalmente el mismo código; lo único
 * que cambia es qué se enseña de lo que se ha calculado.
 */

import { createPublicClient } from "@/lib/supabase/publico";
import {
  perfilDe,
  type FilaDeCambioDeDivision,
  type FilaDeRating,
  type FilaDeTransaccion,
  type Perfil,
} from "./perfil";
import { logrosDelPerfil, ordenados, resumirLogros, type LogroConseguido, type Resumen } from "@/lib/logros/catalogo";
import type { Origen, Partido, Unidad } from "@/lib/historial/partidos";
import type { Formato } from "@/lib/historial/partidos";

/** Una fila de `jugador_publico()`. */
type FilaDeFicha = {
  id: string;
  nombre: string;
  apellido: string | null;
  apodo: string | null;
  rating: number | null;
  desviacion: number | null;
  confianza: number | null;
  partidos_puntuados: number | null;
  ultimo_partido: string | null;
  division: string | null;
  escala: string | null;
  partidos_en_zona_de_ascenso: number | null;
  partidos_en_zona_de_descenso: number | null;
};

/** Una fila de `partidos_publicos()`. */
type FilaDePartido = {
  id: string;
  evento_id: string | null;
  fecha: string;
  origen: string;
  formato: string;
  unidad: string;
  a1: string | null;
  a2: string | null;
  b1: string | null;
  b2: string | null;
  marcador_a: number;
  marcador_b: number;
};

export type JugadorPublico = {
  id: string;
  /** Nombre y primer apellido. El apodo va aparte. */
  nombre: string;
  apodo: string | null;
  perfil: Perfil;
  logros: LogroConseguido[];
  resumenDeLogros: Resumen;
};

const FORMATOS = new Set<string>(["americano", "parejas", "amistoso"]);
const UNIDADES = new Set<string>(["juegos", "sets", "puntos"]);
const ORIGENES = new Set<string>([
  "sin_puntuar",
  "confirmado",
  "club",
  "torneo",
  "liga",
  "marcador",
]);

/**
 * Las filas de `partidos_publicos()` como partidos de la app.
 *
 * Un partido al que le falta uno de los cuatro —un hueco del cuadro sin ocupante—
 * o que trae un valor que no se reconoce se cae fuera, igual que en el panel. Aquí
 * no se avisa de los descartes porque no hay nadie a quien avisar: el visitante de
 * una página pública no puede arreglar los datos de un club.
 */
function partidosDeLasFilas(filas: readonly FilaDePartido[]): Partido[] {
  const partidos: Partido[] = [];

  for (const fila of filas) {
    if (fila.a1 === null || fila.a2 === null || fila.b1 === null || fila.b2 === null) continue;
    if (fila.marcador_a + fila.marcador_b <= 0) continue;
    if (!FORMATOS.has(fila.formato)) continue;
    if (!UNIDADES.has(fila.unidad)) continue;
    if (!ORIGENES.has(fila.origen)) continue;
    if (new Set([fila.a1, fila.a2, fila.b1, fila.b2]).size !== 4) continue;

    partidos.push({
      id: fila.id,
      eventoId: fila.evento_id,
      fecha: fila.fecha,
      origen: fila.origen as Origen,
      formato: fila.formato as Formato,
      unidad: fila.unidad as Unidad,
      a: [fila.a1, fila.a2],
      b: [fila.b1, fila.b2],
      marcadorA: fila.marcador_a,
      marcadorB: fila.marcador_b,
    });
  }

  return partidos;
}

/** La fila de rating, o null cuando existe la ficha pero no el rating. */
function ratingDeLaFicha(ficha: FilaDeFicha): FilaDeRating | null {
  if (ficha.rating === null || ficha.division === null) return null;

  return {
    player_id: ficha.id,
    rating: ficha.rating,
    desviacion: ficha.desviacion ?? 350,
    confianza: ficha.confianza ?? 0,
    partidos_puntuados: ficha.partidos_puntuados ?? 0,
    ultimo_partido: ficha.ultimo_partido,
    escala: ficha.escala ?? "uy-v1",
    division: ficha.division,
    partidos_en_zona_de_ascenso: ficha.partidos_en_zona_de_ascenso ?? 0,
    partidos_en_zona_de_descenso: ficha.partidos_en_zona_de_descenso ?? 0,
  };
}

/**
 * Carga la página pública, o `null` si no existe o está apagada.
 *
 * Los dos casos devuelven lo mismo a propósito: desde fuera, un enlace mal escrito
 * y una ficha apagada tienen que ser indistinguibles. Si no lo fueran, se podría
 * averiguar quién tiene ficha en Puntazo probando enlaces — que es exactamente lo
 * que el interruptor está para impedir. Mismo criterio que la página de un torneo
 * sin publicar (`torneo/publico.ts`).
 */
export async function cargarJugadorPublico(
  id: string,
  hoy: string,
): Promise<JugadorPublico | null> {
  const supabase = createPublicClient();

  const { data: fichas } = await supabase.rpc("jugador_publico", { p_id: id });
  const ficha = (fichas as FilaDeFicha[] | null)?.[0];
  if (!ficha) return null;

  const [{ data: partidosBrutos }, { data: transaccionesBrutas }, { data: cambiosBrutos }] =
    await Promise.all([
      supabase.rpc("partidos_publicos", { p_id: id }),
      supabase.rpc("transacciones_publicas", { p_id: id }),
      supabase.rpc("divisiones_publicas", { p_id: id }),
    ]);

  const perfil = perfilDe({
    jugadorId: id,
    rating: ratingDeLaFicha(ficha),
    transacciones: (transaccionesBrutas ?? []) as FilaDeTransaccion[],
    cambios: (cambiosBrutos ?? []) as FilaDeCambioDeDivision[],
    partidos: partidosDeLasFilas((partidosBrutos ?? []) as FilaDePartido[]),
    hoy,
  });

  const logros = ordenados(logrosDelPerfil(perfil));

  return {
    id: ficha.id,
    nombre: [ficha.nombre, ficha.apellido?.trim().split(/\s+/)[0]]
      .filter(Boolean)
      .join(" "),
    apodo: ficha.apodo,
    perfil,
    logros,
    resumenDeLogros: resumirLogros(logros),
  };
}
