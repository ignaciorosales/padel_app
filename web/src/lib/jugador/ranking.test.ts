import test from "node:test";
import assert from "node:assert/strict";
import {
  fiabilidadDelRanking,
  gruposConectados,
  puestosDe,
  ranking,
} from "./ranking.ts";
import { OPCIONES, type RatingJugador } from "../rating/algoritmo.ts";
import type { Partido } from "../historial/partidos.ts";

const nivel = (rating: number, partidos = 40): RatingJugador => ({
  jugadorId: "x",
  rating,
  desviacion: OPCIONES.desviacionMinima,
  confianza: 1,
  partidosPuntuados: partidos,
  ultimoPartido: "2026-08-15",
});

/** Alguien de quien todavía no se sabe lo suficiente. */
const provisional = (rating: number): RatingJugador =>
  nivel(rating, OPCIONES.partidosProvisionales - 1);

const partido = (a: [string, string], b: [string, string]): Partido => ({
  id: `${a.join("")}-${b.join("")}`,
  eventoId: "t1",
  fecha: "2026-08-15",
  origen: "torneo",
  formato: "americano",
  unidad: "juegos",
  a,
  b,
  marcadorA: 6,
  marcadorB: 4,
});

// ------------------------------------------------------------------ orden

test("el ranking va de más nivel a menos", () => {
  const filas = ranking(
    new Map([
      ["javi", nivel(1700)],
      ["yo", nivel(1800)],
      ["tincho", nivel(1600)],
    ]),
  );

  assert.deepEqual(filas.map((f) => f.jugadorId), ["yo", "javi", "tincho"]);
  assert.deepEqual(filas.map((f) => f.puesto), [1, 2, 3]);
});

test("cada fila trae su división, para no tener que calcularla en la pantalla", () => {
  const filas = ranking(new Map([["yo", nivel(1672)]]));
  assert.equal(filas[0].division, "3ª");
});

// -------------------------------------------------------------- empates

test("los que empatan comparten puesto, y el siguiente salta", () => {
  const filas = ranking(
    new Map([
      ["a", nivel(1800)],
      ["b", nivel(1700)],
      ["c", nivel(1700)],
      ["d", nivel(1600)],
    ]),
  );

  assert.deepEqual(filas.map((f) => f.puesto), [1, 2, 2, 4]);
});

// --------------------------------------------------------- provisionales

test("quien es provisional no sale en el ranking", () => {
  const niveles = new Map([
    ["asentado", nivel(1700)],
    ["nuevo", provisional(1900)],
  ]);

  assert.deepEqual(
    ranking(niveles).map((f) => f.jugadorId),
    ["asentado"],
    "el nuevo tiene más nivel, pero no se sabe todavía",
  );
});

test("se pueden pedir también los provisionales, para la pantalla del club", () => {
  const niveles = new Map([
    ["asentado", nivel(1700)],
    ["nuevo", provisional(1900)],
  ]);

  const filas = ranking(niveles, { incluirProvisionales: true });
  assert.deepEqual(filas.map((f) => f.jugadorId), ["nuevo", "asentado"]);
});

// ------------------------------------------------------------ movimiento

test("el movimiento se cuenta contra la foto anterior", () => {
  const antes = puestosDe(
    ranking(
      new Map([
        ["yo", nivel(1600)],
        ["javi", nivel(1700)],
      ]),
    ),
  );

  const ahora = ranking(
    new Map([
      ["yo", nivel(1750)],
      ["javi", nivel(1700)],
    ]),
    { anterior: antes },
  );

  assert.equal(ahora.find((f) => f.jugadorId === "yo")!.movimiento, 1);
  assert.equal(ahora.find((f) => f.jugadorId === "javi")!.movimiento, -1);
});

test("quien no estaba antes no tiene flecha, y eso no es un cero", () => {
  const filas = ranking(new Map([["nuevo", nivel(1700)]]), {
    anterior: new Map(),
  });

  assert.equal(filas[0].movimiento, null);
});

// -------------------------------------------------------------- conexión

test("los que juegan un partido quedan conectados", () => {
  const grupos = gruposConectados([partido(["a", "b"], ["c", "d"])]);

  assert.equal(grupos.length, 1);
  assert.deepEqual(grupos[0], ["a", "b", "c", "d"]);
});

test("la conexión es indirecta: si A jugó con B y B con C, los tres se comparan", () => {
  const grupos = gruposConectados([
    partido(["a", "b"], ["c", "d"]),
    partido(["d", "e"], ["f", "g"]),
  ]);

  assert.equal(grupos.length, 1);
  assert.equal(grupos[0].length, 7);
});

test("dos clubes que nunca se cruzan son dos grupos", () => {
  const grupos = gruposConectados([
    partido(["a1", "a2"], ["a3", "a4"]),
    partido(["b1", "b2"], ["b3", "b4"]),
  ]);

  assert.equal(grupos.length, 2);
});

test("un solo partido entre los dos clubes los cose", () => {
  const grupos = gruposConectados([
    partido(["a1", "a2"], ["a3", "a4"]),
    partido(["b1", "b2"], ["b3", "b4"]),
    partido(["a1", "b1"], ["a2", "b2"]),
  ]);

  assert.equal(grupos.length, 1);
});

// ------------------------------------------------------------ fiabilidad

test("dentro de un club el ranking es comparable y no lleva aviso", () => {
  const partidos = [partido(["a", "b"], ["c", "d"])];
  const filas = ranking(
    new Map([
      ["a", nivel(1800)],
      ["b", nivel(1700)],
      ["c", nivel(1650)],
      ["d", nivel(1600)],
    ]),
  );

  const fiabilidad = fiabilidadDelRanking(filas, partidos);
  assert.equal(fiabilidad.comparable, true);
  assert.equal(fiabilidad.aviso, null);
});

test("juntar dos clubes que no se han cruzado da una estimación, no un ranking", () => {
  const partidos = [
    partido(["a1", "a2"], ["a3", "a4"]),
    partido(["b1", "b2"], ["b3", "b4"]),
  ];
  const filas = ranking(
    new Map(
      ["a1", "a2", "a3", "a4", "b1", "b2", "b3", "b4"].map((id, i) => [
        id,
        nivel(1800 - i * 20),
      ]),
    ),
  );

  const fiabilidad = fiabilidadDelRanking(filas, partidos);
  assert.equal(fiabilidad.comparable, false);
  assert.equal(fiabilidad.grupos, 2);
  assert.ok(fiabilidad.aviso!.includes("no se han cruzado"));
});

test("en cuanto hay un partido entre los dos, la tabla pasa a ser comparable", () => {
  const partidos = [
    partido(["a1", "a2"], ["a3", "a4"]),
    partido(["b1", "b2"], ["b3", "b4"]),
    partido(["a1", "b1"], ["a2", "b2"]),
  ];
  const filas = ranking(
    new Map(
      ["a1", "a2", "a3", "a4", "b1", "b2", "b3", "b4"].map((id, i) => [
        id,
        nivel(1800 - i * 20),
      ]),
    ),
  );

  assert.equal(fiabilidadDelRanking(filas, partidos).comparable, true);
});

test("quien está en la tabla sin haber jugado cuenta como su propio grupo", () => {
  const partidos = [partido(["a", "b"], ["c", "d"])];
  const filas = ranking(
    new Map([
      ["a", nivel(1800)],
      ["suelto", nivel(1700)],
    ]),
  );

  const fiabilidad = fiabilidadDelRanking(filas, partidos);
  assert.equal(fiabilidad.comparable, false);
  assert.equal(fiabilidad.grupos, 2);
});

test("los grupos de fuera de la tabla no cuentan para su fiabilidad", () => {
  const partidos = [
    partido(["a1", "a2"], ["a3", "a4"]),
    partido(["b1", "b2"], ["b3", "b4"]),
  ];
  // La tabla es sólo del club A, aunque en la base de datos haya otro club.
  const filas = ranking(
    new Map(
      ["a1", "a2", "a3", "a4"].map((id, i) => [id, nivel(1800 - i * 20)]),
    ),
  );

  assert.equal(fiabilidadDelRanking(filas, partidos).comparable, true);
});
