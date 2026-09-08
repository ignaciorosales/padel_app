import test from "node:test";
import assert from "node:assert/strict";
import {
  identidadesDe,
  paraRating,
  partidosDelPanel,
  resumenDeDescartes,
  soloPuntuables,
  type FilaDelPanel,
} from "./desde-el-panel.ts";
import type { Partido } from "../historial/partidos.ts";

const fila = (p: Partial<FilaDelPanel> = {}): FilaDelPanel => ({
  id: "m1",
  torneoId: "t1",
  fecha: "2026-08-15",
  formato: "americano",
  unidad: "juegos",
  ronda: 1,
  pista: 1,
  a1: "i1",
  a2: "i2",
  b1: "i3",
  b2: "i4",
  juegosA: 6,
  juegosB: 4,
  ...p,
});

/** Los cuatro inscritos, ya unificados. */
const CUATRO = identidadesDe([
  { id: "i1", playerId: "yo" },
  { id: "i2", playerId: "javi" },
  { id: "i3", playerId: "tincho" },
  { id: "i4", playerId: "santi" },
]);

// ------------------------------------------------------------------ el caso

test("una fila normal se convierte en un partido con personas", () => {
  const { partidos, descartes } = partidosDelPanel([fila()], CUATRO);

  assert.deepEqual(descartes, []);
  assert.equal(partidos.length, 1);
  assert.deepEqual([...partidos[0].a], ["yo", "javi"]);
  assert.deepEqual([...partidos[0].b], ["tincho", "santi"]);
  assert.equal(partidos[0].eventoId, "t1");
  assert.equal(partidos[0].origen, "torneo");
});

// -------------------------------------------------------------- lo que cae

test("un hueco del cuadro no es un partido", () => {
  const { partidos, descartes } = partidosDelPanel(
    [fila({ b1: null, b2: null })],
    CUATRO,
  );

  assert.deepEqual(partidos, []);
  assert.equal(descartes[0].motivo, "hueco_o_bye");
});

test("un partido sin resultado todavía no cuenta", () => {
  const { descartes } = partidosDelPanel(
    [fila({ juegosA: null, juegosB: null })],
    CUATRO,
  );

  assert.equal(descartes[0].motivo, "sin_resultado");
});

test("un 0-0 no dice nada de nadie", () => {
  const { descartes } = partidosDelPanel([fila({ juegosA: 0, juegosB: 0 })], CUATRO);
  assert.equal(descartes[0].motivo, "sin_juego");
});

test("si falta alguien por identificar, el partido entero espera", () => {
  const tres = identidadesDe([
    { id: "i1", playerId: "yo" },
    { id: "i2", playerId: "javi" },
    { id: "i3", playerId: "tincho" },
    { id: "i4", playerId: null },
  ]);
  const { partidos, descartes } = partidosDelPanel([fila()], tres);

  assert.deepEqual(partidos, []);
  assert.equal(descartes[0].motivo, "sin_identificar");
});

test("la misma persona a los dos lados es una unificación mal hecha", () => {
  const mezclado = identidadesDe([
    { id: "i1", playerId: "yo" },
    { id: "i2", playerId: "javi" },
    { id: "i3", playerId: "yo" },
    { id: "i4", playerId: "santi" },
  ]);
  const { partidos, descartes } = partidosDelPanel([fila()], mezclado);

  assert.deepEqual(partidos, []);
  assert.equal(descartes[0].motivo, "sin_identificar");
});

test("no se adivina un formato ni una unidad que no se conocen", () => {
  const raro = partidosDelPanel(
    [fila({ id: "m1", formato: "mexicano" }), fila({ id: "m2", unidad: "sets_cortos" })],
    CUATRO,
  );

  assert.deepEqual(raro.partidos, []);
  assert.deepEqual(
    raro.descartes.map((d) => d.motivo).sort(),
    ["formato_desconocido", "unidad_desconocida"],
  );
});

test("nada se cae en silencio: cada descarte dice de qué torneo es y por qué", () => {
  const { descartes } = partidosDelPanel(
    [fila({ id: "m1", torneoId: "tA", juegosA: null, juegosB: null })],
    CUATRO,
  );

  assert.deepEqual(descartes, [
    { filaId: "m1", torneoId: "tA", motivo: "sin_resultado" },
  ]);
});

test("el resumen convierte los descartes en una tarea para el club", () => {
  const { descartes } = partidosDelPanel(
    [
      fila({ id: "m1", juegosA: null, juegosB: null }),
      fila({ id: "m2", juegosA: null, juegosB: null }),
      fila({ id: "m3", a1: null, a2: null }),
    ],
    CUATRO,
  );

  const cuenta = resumenDeDescartes(descartes);
  assert.equal(cuenta.sin_resultado, 2);
  assert.equal(cuenta.hueco_o_bye, 1);
  assert.equal(cuenta.sin_identificar, 0);
});

// ------------------------------------------------------------------- orden

test("los partidos salen en el orden en que se jugaron, no en el que llegan", () => {
  const { partidos } = partidosDelPanel(
    [
      fila({ id: "c", fecha: "2026-08-15", ronda: 2, pista: 1 }),
      fila({ id: "d", fecha: "2026-09-01", ronda: 1, pista: 1 }),
      fila({ id: "a", fecha: "2026-08-15", ronda: 1, pista: 1 }),
      fila({ id: "b", fecha: "2026-08-15", ronda: 1, pista: 2 }),
    ],
    CUATRO,
  );

  assert.deepEqual(partidos.map((p) => p.id), ["a", "b", "c", "d"]);
});

test("el orden es estable aunque coincidan fecha, ronda y pista", () => {
  const dos = [fila({ id: "z" }), fila({ id: "a" })];

  assert.deepEqual(
    partidosDelPanel(dos, CUATRO).partidos.map((p) => p.id),
    partidosDelPanel([...dos].reverse(), CUATRO).partidos.map((p) => p.id),
  );
});

// -------------------------------------------------------------- identidades

test("los inscritos sin unificar no entran en el mapa", () => {
  const mapa = identidadesDe([
    { id: "i1", playerId: "yo" },
    { id: "i2", playerId: null },
  ]);

  assert.equal(mapa.get("i1"), "yo");
  assert.equal(mapa.has("i2"), false);
});

// ----------------------------------------------------------------- puentes

test("el mismo partido, proyectado a lo que necesita el rating", () => {
  const { partidos } = partidosDelPanel([fila()], CUATRO);
  const paraElRating = paraRating(partidos[0]);

  assert.equal(paraElRating.id, "m1");
  assert.equal(paraElRating.marcadorA, 6);
  assert.equal(paraElRating.fecha, "2026-08-15");
  assert.equal(paraElRating.origen, "torneo");
  assert.equal(
    "eventoId" in paraElRating,
    false,
    "al rating no le hace falta saber de torneos",
  );
});

test("los amistosos sin confirmar se quedan fuera del rating", () => {
  const { partidos } = partidosDelPanel([fila()], CUATRO);
  const amistoso: Partido = { ...partidos[0], id: "a1", origen: "sin_puntuar" };

  const puntuables = soloPuntuables([...partidos, amistoso]);
  assert.deepEqual(puntuables.map((p: { id: string }) => p.id), ["m1"]);
});

test("un amistoso que los cuatro confirman sí puntúa", () => {
  const { partidos } = partidosDelPanel([fila()], CUATRO);
  const confirmado: Partido = { ...partidos[0], id: "a2", origen: "confirmado" };

  const puntuables = soloPuntuables([confirmado]);
  assert.deepEqual(puntuables.map((p: { id: string }) => p.id), ["a2"]);
});
