/**
 * La traducción entre Postgres y el motor.
 *
 * Es la pieza que no se puede probar con una base de datos delante sin montar
 * una, y la que se equivoca: aquí es donde un `null` se convierte en un cero, o
 * donde la división con histéresis se cambia por la del rating de hoy y todo el
 * mundo asciende de golpe.
 */

import test from "node:test";
import assert from "node:assert/strict";
import {
  entradaDelMotor,
  paraGuardar,
  puntuablesDeLasFilas,
  ratingsInicialesDe,
  VERSION_SIN_PARTIDOS,
  type FilaDeInscrito,
  type FilaDeMatch,
  type FilaDeRonda,
  type FilaDeTorneo,
} from "./consultas.ts";
import { procesar } from "./motor.ts";
import { ESCALA_UY, RATING_DESCONOCIDO } from "./divisiones.ts";
import { VERSION_ALGORITMO } from "./algoritmo.ts";

// Un torneo mínimo: un americano de una ronda con dos pistas.
const TORNEO: FilaDeTorneo = {
  id: "t1",
  fecha: "2026-08-15",
  formato: "americano",
  unidad_marcador: "juegos",
};

const RONDA: FilaDeRonda = { id: "r1", tournament_id: "t1", numero: 1 };

const match = (p: Partial<FilaDeMatch> = {}): FilaDeMatch => ({
  id: "m1",
  round_id: "r1",
  pista: 1,
  a1: "i1",
  a2: "i2",
  b1: "i3",
  b2: "i4",
  juegos_a: 6,
  juegos_b: 4,
  ...p,
});

const INSCRITOS: FilaDeInscrito[] = [
  { id: "i1", player_id: "nacho" },
  { id: "i2", player_id: "juan" },
  { id: "i3", player_id: "santi" },
  { id: "i4", player_id: "tincho" },
];

// ----------------------------------------------------------- juntar las tablas

test("el partido se completa con la fecha y el formato de su torneo", () => {
  const { filas, huerfanos } = entradaDelMotor([match()], [RONDA], [TORNEO]);

  assert.equal(huerfanos.length, 0);
  assert.equal(filas.length, 1);
  assert.equal(filas[0].fecha, "2026-08-15");
  assert.equal(filas[0].formato, "americano");
  assert.equal(filas[0].unidad, "juegos");
  assert.equal(filas[0].ronda, 1);
  assert.equal(filas[0].torneoId, "t1");
});

test("un partido cuya ronda no vino sale como huérfano, no desaparece", () => {
  const { filas, huerfanos } = entradaDelMotor([match()], [], [TORNEO]);

  assert.equal(filas.length, 0);
  assert.deepEqual(huerfanos, [{ filaId: "m1", motivo: "sin_ronda" }]);
});

test("un partido cuyo torneo no vino también sale con su motivo", () => {
  const { filas, huerfanos } = entradaDelMotor([match()], [RONDA], []);

  assert.equal(filas.length, 0);
  assert.deepEqual(huerfanos, [{ filaId: "m1", motivo: "sin_torneo" }]);
});

// ------------------------------------------------------- lo que llega al motor

test("un partido completo y unificado puntúa", () => {
  const { partidos, descartes } = puntuablesDeLasFilas(
    [match()],
    [RONDA],
    [TORNEO],
    INSCRITOS,
  );

  assert.equal(descartes.length, 0);
  assert.equal(partidos.length, 1);
  assert.deepEqual(partidos[0].a, ["nacho", "juan"]);
  assert.equal(partidos[0].origen, "torneo");
  assert.equal(partidos[0].marcadorA, 6);
});

test("un partido sin resultado no puntúa, y se dice por qué", () => {
  const { partidos, descartes } = puntuablesDeLasFilas(
    [match({ juegos_a: null, juegos_b: null })],
    [RONDA],
    [TORNEO],
    INSCRITOS,
  );

  assert.equal(partidos.length, 0);
  assert.deepEqual(descartes, [
    { filaId: "m1", torneoId: "t1", motivo: "sin_resultado" },
  ]);
});

test("un hueco del cuadro no es un partido", () => {
  const { partidos, descartes } = puntuablesDeLasFilas(
    [match({ b2: null })],
    [RONDA],
    [TORNEO],
    INSCRITOS,
  );

  assert.equal(partidos.length, 0);
  assert.equal(descartes[0].motivo, "hueco_o_bye");
});

test("mientras falte por unificar a uno, su partido no puntúa para nadie", () => {
  const { partidos, descartes } = puntuablesDeLasFilas(
    [match()],
    [RONDA],
    [TORNEO],
    [...INSCRITOS.slice(0, 3), { id: "i4", player_id: null }],
  );

  assert.equal(partidos.length, 0);
  assert.equal(descartes[0].motivo, "sin_identificar");
});

// -------------------------------------------------------- por dónde se empieza

test("quien declaró su división arranca en el rating de partida de ésa", () => {
  const iniciales = ratingsInicialesDe([
    { id: "nacho", division_declarada: "4ª" },
    { id: "juan", division_declarada: "1ª" },
  ]);

  assert.equal(iniciales.get("nacho"), 1525);
  assert.equal(iniciales.get("juan"), 1975);
});

test("quien no declaró nada no entra en el mapa, y el motor lo pone en el centro", () => {
  const iniciales = ratingsInicialesDe([{ id: "nacho", division_declarada: null }]);

  assert.equal(iniciales.has("nacho"), false);

  const estado = procesar(
    [
      {
        id: "m1",
        fecha: "2026-08-15",
        origen: "torneo",
        a: ["nacho", "juan"],
        b: ["santi", "tincho"],
        marcadorA: 6,
        marcadorB: 4,
      },
    ],
    { ratingsIniciales: iniciales },
  );

  // Ganó, así que subió: lo que se comprueba es de dónde partió.
  const suyas = estado.transacciones.filter((t) => t.jugadorId === "nacho");
  assert.equal(suyas[0].ratingAntes, RATING_DESCONOCIDO);
});

test("una división que no está en la escala se trata como 'no sé'", () => {
  const iniciales = ratingsInicialesDe([
    { id: "nacho", division_declarada: "12ª" },
  ]);

  assert.equal(iniciales.get("nacho"), RATING_DESCONOCIDO);
});

// ------------------------------------------------------------- lo que se guarda

/** Un jugador que gana muchos partidos seguidos: llega a ascender. */
function estadoConAscenso() {
  const partidos = [];
  for (let i = 0; i < 40; i++) {
    partidos.push({
      id: `m${String(i).padStart(2, "0")}`,
      fecha: `2026-08-${String((i % 28) + 1).padStart(2, "0")}`,
      origen: "torneo" as const,
      a: ["nacho", "juan"] as const,
      b: ["santi", "tincho"] as const,
      marcadorA: 6,
      marcadorB: 2,
    });
  }
  return procesar(partidos, {
    ratingsIniciales: new Map([
      ["nacho", 1525],
      ["juan", 1525],
      ["santi", 1525],
      ["tincho", 1525],
    ]),
  });
}

test("cada rating sale con su división, su escala y su versión", () => {
  const estado = estadoConAscenso();
  const { ratings } = paraGuardar(estado);

  assert.equal(ratings.length, 4);
  const nacho = ratings.find((r) => r.player_id === "nacho")!;
  assert.equal(nacho.escala, ESCALA_UY.id);
  assert.equal(nacho.version, VERSION_ALGORITMO);
  assert.equal(nacho.partidos_puntuados, 40);
  assert.equal(nacho.ultimo_partido !== null, true);
  assert.equal(nacho.confianza >= 0 && nacho.confianza <= 1, true);
});

test("se guarda la división de la histéresis, no la del rating de hoy", () => {
  // Se monta a mano el caso que importa: rating ya por encima del umbral de la
  // siguiente, pero sin los partidos sostenidos que hacen falta para subir.
  const estado = procesar([], {});
  estado.ratings.set("nacho", {
    jugadorId: "nacho",
    rating: 1755,
    desviacion: 120,
    confianza: 0.7,
    partidosPuntuados: 30,
    ultimoPartido: "2026-08-15",
  });
  estado.divisiones.set("nacho", {
    division: "3ª",
    partidosEnZonaDeAscenso: 2,
    partidosEnZonaDeDescenso: 0,
  });

  const { ratings } = paraGuardar(estado);

  // 1755 cae en 2ª por rating, pero le faltan tres partidos por sostener.
  assert.equal(ratings[0].division, "3ª");
  assert.equal(ratings[0].partidos_en_zona_de_ascenso, 2);
});

test("sin ninguna transacción, la versión dice que no pasó por ningún algoritmo", () => {
  const estado = procesar([], {});
  estado.ratings.set("nacho", {
    jugadorId: "nacho",
    rating: RATING_DESCONOCIDO,
    desviacion: 350,
    confianza: 0,
    partidosPuntuados: 0,
    ultimoPartido: null,
  });
  estado.divisiones.set("nacho", {
    division: "5ª",
    partidosEnZonaDeAscenso: 0,
    partidosEnZonaDeDescenso: 0,
  });

  const { ratings } = paraGuardar(estado);

  assert.equal(ratings[0].version, VERSION_SIN_PARTIDOS);
  assert.equal(ratings[0].ultimo_partido, null);
});

test("el rating se guarda sin redondear: redondear en cada pasada acumula error", () => {
  const estado = estadoConAscenso();
  const { ratings } = paraGuardar(estado);
  const nacho = ratings.find((r) => r.player_id === "nacho")!;

  assert.equal(nacho.rating, estado.ratings.get("nacho")!.rating);
  assert.equal(Number.isInteger(nacho.rating), false);
});

test("cada partido puntuado deja cuatro transacciones, una por jugador", () => {
  const estado = estadoConAscenso();
  const { transacciones, partidos } = paraGuardar(estado);

  assert.equal(transacciones.length, 40 * 4);
  assert.equal(partidos.length, 40);
  assert.equal(new Set(partidos).size, 40);

  const primera = transacciones[0];
  assert.equal(primera.version, VERSION_ALGORITMO);
  assert.equal([0, 0.5, 1].includes(primera.resultado), true);
  assert.equal(
    Math.abs(primera.rating_despues - primera.rating_antes - primera.delta) < 1e-9,
    true,
  );
});

test("sólo se marcan como procesados los partidos que movieron un rating", () => {
  // Un amistoso sin confirmar entra en la lista y no puntúa: tiene que seguir
  // pendiente, porque el día que los cuatro lo confirmen hay que volver a él.
  const estado = procesar([
    {
      id: "m1",
      fecha: "2026-08-15",
      origen: "torneo",
      a: ["nacho", "juan"],
      b: ["santi", "tincho"],
      marcadorA: 6,
      marcadorB: 4,
    },
    {
      id: "m2",
      fecha: "2026-08-16",
      origen: "sin_puntuar",
      a: ["nacho", "juan"],
      b: ["santi", "tincho"],
      marcadorA: 6,
      marcadorB: 3,
    },
  ]);

  const { partidos } = paraGuardar(estado);

  assert.deepEqual(partidos, ["m1"]);
});

test("los cambios de división salen con el partido que los provocó", () => {
  const estado = estadoConAscenso();
  const { divisiones } = paraGuardar(estado);

  assert.equal(divisiones.length > 0, true);
  const cambio = divisiones[0];
  assert.equal(cambio.escala, ESCALA_UY.id);
  assert.equal(["ascenso", "descenso"].includes(cambio.tipo), true);
  assert.notEqual(cambio.anterior, cambio.nueva);
  assert.equal(typeof cambio.match_id, "string");
  assert.equal(typeof cambio.fecha, "string");
});

test("nadie sale dos veces en la misma pasada, ni en ratings ni en divisiones", () => {
  const estado = estadoConAscenso();
  const { ratings, divisiones } = paraGuardar(estado);

  assert.equal(new Set(ratings.map((r) => r.player_id)).size, ratings.length);

  // Un jugador puede cambiar de división varias veces, pero nunca dos por el
  // mismo partido: es el índice único de player_division_history.
  const llaves = divisiones.map((d) => `${d.player_id}|${d.match_id}`);
  assert.equal(new Set(llaves).size, llaves.length);
});
