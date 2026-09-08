import test from "node:test";
import assert from "node:assert/strict";
import {
  caraACara,
  companeros,
  destacados,
  MINIMO_PARA_DESTACAR,
  rivales,
} from "./gente.ts";
import type { Partido } from "./partidos.ts";

let contador = 0;
const partido = (p: Partial<Partido> = {}): Partido => ({
  id: `p${contador++}`,
  eventoId: "t1",
  fecha: "2026-08-15",
  origen: "torneo",
  formato: "americano",
  unidad: "juegos",
  a: ["yo", "javi"],
  b: ["tincho", "santi"],
  marcadorA: 6,
  marcadorB: 4,
  ...p,
});

/** n partidos iguales, con fechas distintas para que el orden sea estable. */
const repetir = (n: number, p: Partial<Partido> = {}): Partido[] =>
  Array.from({ length: n }, (_, i) =>
    partido({ ...p, fecha: `2026-08-${String(i + 1).padStart(2, "0")}` }),
  );

// ------------------------------------------------------------- compañeros

test("los compañeros salen de más veces jugadas a menos", () => {
  const filas = companeros("yo", [
    ...repetir(3, { a: ["yo", "javi"] }),
    ...repetir(1, { a: ["yo", "mauro"] }),
  ]);

  assert.deepEqual(filas.map((f) => f.jugadorId), ["javi", "mauro"]);
  assert.equal(filas[0].totales.partidos, 3);
});

test("un americano regala compañeros: cada ronda cambia", () => {
  const filas = companeros("yo", [
    partido({ a: ["yo", "javi"] }),
    partido({ a: ["yo", "tincho"], b: ["santi", "mauro"] }),
    partido({ a: ["yo", "santi"], b: ["javi", "mauro"] }),
  ]);

  assert.equal(filas.length, 3);
});

test("los dos rivales de cada partido cuentan por separado", () => {
  const filas = rivales("yo", [partido()]);

  assert.deepEqual(filas.map((f) => f.jugadorId).sort(), ["santi", "tincho"]);
  assert.ok(filas.every((f) => f.totales.partidos === 1));
});

test("aquí los amistosos sí cuentan: si no dan nivel, dan esto", () => {
  const filas = companeros("yo", [
    partido({ origen: "torneo", a: ["yo", "javi"] }),
    partido({ origen: "sin_puntuar", a: ["yo", "javi"] }),
  ]);

  assert.equal(filas[0].totales.partidos, 2);
});

// ------------------------------------------------------------ cara a cara

test("el cara a cara separa lo jugado en contra de lo jugado juntos", () => {
  const h = caraACara("yo", "tincho", [
    ...repetir(2, { a: ["yo", "javi"], b: ["tincho", "santi"] }),
    ...repetir(1, { a: ["yo", "tincho"], b: ["javi", "santi"] }),
  ]);

  assert.equal(h.contra.partidos, 2);
  assert.equal(h.contra.ganados, 2);
  assert.equal(h.juntos.partidos, 1);
});

test("los últimos enfrentamientos vienen del más nuevo al más antiguo", () => {
  const h = caraACara("yo", "tincho", [
    partido({ fecha: "2026-08-01", marcadorA: 6, marcadorB: 4 }),
    partido({ fecha: "2026-08-02", marcadorA: 4, marcadorB: 6 }),
    partido({ fecha: "2026-08-03", marcadorA: 4, marcadorB: 4 }),
  ]);

  assert.deepEqual(h.ultimos, ["empatado", "perdido", "ganado"]);
});

test("contra alguien con quien nunca jugaste, todo a cero", () => {
  const h = caraACara("yo", "federico", [partido()]);

  assert.equal(h.contra.partidos, 0);
  assert.deepEqual(h.ultimos, []);
});

// ------------------------------------------------------------- destacados

test("nadie es tu mejor compañero por haber jugado una vez", () => {
  const d = destacados("yo", [
    partido({ a: ["yo", "suerte"], marcadorA: 6, marcadorB: 0 }),
    ...repetir(MINIMO_PARA_DESTACAR, { a: ["yo", "javi"], marcadorA: 6, marcadorB: 4 }),
  ]);

  assert.equal(d.mejorCompanero?.jugadorId, "javi");
});

test("sin partidos suficientes no hay destacados, y el hueco es correcto", () => {
  const d = destacados("yo", [partido(), partido()]);

  assert.equal(d.mejorCompanero, null);
  assert.equal(d.nemesis, null);
});

test("el mejor compañero es con quien mejor te va", () => {
  const d = destacados("yo", [
    ...repetir(5, { a: ["yo", "javi"], marcadorA: 6, marcadorB: 2 }),
    ...repetir(5, { a: ["yo", "mauro"], marcadorA: 2, marcadorB: 6 }),
  ]);

  assert.equal(d.mejorCompanero?.jugadorId, "javi");
  assert.equal(d.mejorCompanero?.totales.ganados, 5);
});

test("la némesis es contra quien peor te va, no contra quien más juegas", () => {
  const d = destacados("yo", [
    // A Tincho le ganas casi siempre, aunque juegues mucho con él.
    ...repetir(8, { b: ["tincho", "santi"], marcadorA: 6, marcadorB: 3 }),
    // Mauro te gana casi siempre.
    ...repetir(5, { b: ["mauro", "santi"], marcadorA: 3, marcadorB: 6 }),
  ]);

  assert.equal(d.nemesis?.jugadorId, "mauro");
});

test("con muchos partidos, el porcentaje real se impone al suavizado", () => {
  const d = destacados("yo", [
    ...repetir(4, { a: ["yo", "nuevo"], marcadorA: 6, marcadorB: 0 }),
    ...repetir(20, { a: ["yo", "javi"], marcadorA: 6, marcadorB: 4 }),
  ]);

  // Los dos ganan todo lo suyo; el que tiene veinte partidos lo sostiene mejor.
  assert.equal(d.mejorCompanero?.jugadorId, "javi");
});

test("el mínimo se puede bajar cuando hay poco historial", () => {
  const partidos = repetir(2, { a: ["yo", "javi"] });

  assert.equal(destacados("yo", partidos).mejorCompanero, null);
  assert.equal(destacados("yo", partidos, 2).mejorCompanero?.jugadorId, "javi");
});
