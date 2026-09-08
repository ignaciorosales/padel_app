import test from "node:test";
import assert from "node:assert/strict";
import {
  comoLoVio,
  esVerificado,
  partidosDe,
  porEvento,
  porMes,
  rachaDe,
  resumen,
  totalesDe,
  type Partido,
} from "./partidos.ts";

const partido = (p: Partial<Partido> = {}): Partido => ({
  id: "p1",
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

// -------------------------------------------------------------- perspectiva

test("el partido se gira hacia quien lo mira", () => {
  const mio = comoLoVio("yo", partido())!;

  assert.equal(mio.companero, "javi");
  assert.deepEqual([...mio.rivales], ["tincho", "santi"]);
  assert.equal(mio.propio, 6);
  assert.equal(mio.resultado, "ganado");
});

test("el mismo partido, para el rival, es una derrota", () => {
  const suyo = comoLoVio("tincho", partido())!;

  assert.equal(suyo.companero, "santi");
  assert.equal(suyo.propio, 4);
  assert.equal(suyo.resultado, "perdido");
});

test("quien no jugó no ve nada", () => {
  assert.equal(comoLoVio("mauro", partido()), null);
});

test("los americanos a tiempo empatan, y eso no es un caso raro", () => {
  const empate = comoLoVio("yo", partido({ marcadorA: 4, marcadorB: 4 }))!;
  assert.equal(empate.resultado, "empatado");
});

test("el historial sale ordenado del más antiguo al más nuevo", () => {
  const vistas = partidosDe("yo", [
    partido({ id: "c", fecha: "2026-08-20" }),
    partido({ id: "a", fecha: "2026-06-01" }),
    partido({ id: "b", fecha: "2026-07-10" }),
  ]);

  assert.deepEqual(vistas.map((v) => v.partido.id), ["a", "b", "c"]);
});

// ------------------------------------------------------------------ récord

test("un amistoso no es un partido verificado", () => {
  assert.equal(esVerificado(partido({ origen: "sin_puntuar" })), false);
  assert.equal(esVerificado(partido({ origen: "torneo" })), true);
  assert.equal(esVerificado(partido({ origen: "marcador" })), true);
});

test("el amistoso suma actividad pero no toca el récord", () => {
  const r = resumen("yo", [
    partido({ id: "p1", origen: "torneo", marcadorA: 6, marcadorB: 4 }),
    partido({ id: "p2", origen: "sin_puntuar", marcadorA: 6, marcadorB: 0 }),
  ]);

  assert.equal(r.oficial.partidos, 1);
  assert.equal(r.oficial.ganados, 1);
  assert.equal(r.actividad.partidos, 2);
  assert.equal(r.actividad.ganados, 2);
});

test("un empate no es media victoria: es un partido que no se ganó", () => {
  const t = totalesDe(
    partidosDe("yo", [
      partido({ id: "p1", marcadorA: 6, marcadorB: 4 }),
      partido({ id: "p2", marcadorA: 4, marcadorB: 4 }),
    ]),
  );

  assert.equal(t.partidos, 2);
  assert.equal(t.ganados, 1);
  assert.equal(t.empatados, 1);
  assert.equal(t.porcentaje, 0.5);
});

test("los juegos a favor y en contra se suman desde tu lado", () => {
  const t = totalesDe(
    partidosDe("tincho", [partido({ marcadorA: 6, marcadorB: 4 })]),
  );

  assert.equal(t.favor, 4);
  assert.equal(t.contra, 6);
  assert.equal(t.diferencia, -2);
});

test("sin partidos, el porcentaje es cero y no una división rara", () => {
  const t = totalesDe([]);
  assert.equal(t.porcentaje, 0);
  assert.equal(t.partidos, 0);
});

// ------------------------------------------------------------------ rachas

const conResultados = (marcadores: Array<[number, number]>) =>
  partidosDe(
    "yo",
    marcadores.map(([a, b], i) =>
      partido({ id: `p${i}`, fecha: `2026-08-${String(i + 1).padStart(2, "0")}`, marcadorA: a, marcadorB: b }),
    ),
  );

test("la racha actual cuenta hacia atrás desde el último partido", () => {
  const r = rachaDe(conResultados([[4, 6], [6, 4], [6, 3], [6, 2]]));

  assert.equal(r.tipo, "ganando");
  assert.equal(r.largo, 3);
});

test("una racha de derrotas también es una racha", () => {
  const r = rachaDe(conResultados([[6, 4], [4, 6], [3, 6]]));

  assert.equal(r.tipo, "perdiendo");
  assert.equal(r.largo, 2);
});

test("un empate corta la racha sin abrir otra", () => {
  const r = rachaDe(conResultados([[6, 4], [6, 4], [4, 4]]));

  assert.equal(r.tipo, "ninguna");
  assert.equal(r.largo, 0);
  assert.equal(r.mejor, 2, "la mejor racha histórica se mantiene");
});

test("la mejor racha se guarda aunque ya se haya cortado", () => {
  const r = rachaDe(conResultados([[6, 0], [6, 1], [6, 2], [0, 6], [6, 4]]));

  assert.equal(r.mejor, 3);
  assert.equal(r.largo, 1);
});

test("sin partidos no hay racha", () => {
  assert.deepEqual(rachaDe([]), { tipo: "ninguna", largo: 0, mejor: 0 });
});

// ----------------------------------------------------------------- eventos

test("las ocho rondas de un americano son un solo evento", () => {
  const rondas = Array.from({ length: 8 }, (_, i) =>
    partido({ id: `r${i}`, eventoId: "americano-sabado" }),
  );
  const eventos = porEvento("yo", rondas);

  assert.equal(eventos.length, 1);
  assert.equal(eventos[0].partidos.length, 8);
  assert.equal(eventos[0].totales.ganados, 8);
});

test("cada amistoso es su propio evento: en el historial es una fila suelta", () => {
  const eventos = porEvento("yo", [
    partido({ id: "a1", eventoId: null, origen: "sin_puntuar" }),
    partido({ id: "a2", eventoId: null, origen: "sin_puntuar" }),
  ]);

  assert.equal(eventos.length, 2);
});

test("los eventos salen del más nuevo al más antiguo", () => {
  const eventos = porEvento("yo", [
    partido({ id: "p1", eventoId: "viejo", fecha: "2026-06-01" }),
    partido({ id: "p2", eventoId: "nuevo", fecha: "2026-08-01" }),
  ]);

  assert.deepEqual(eventos.map((e) => e.eventoId), ["nuevo", "viejo"]);
});

test("el evento se fecha por su primer partido", () => {
  const eventos = porEvento("yo", [
    partido({ id: "r2", eventoId: "t1", fecha: "2026-08-15" }),
    partido({ id: "r1", eventoId: "t1", fecha: "2026-08-14" }),
  ]);

  assert.equal(eventos[0].fecha, "2026-08-14");
});

// -------------------------------------------------------------------- mes

test("el mes cuenta partidos y eventos por separado", () => {
  const meses = porMes("yo", [
    partido({ id: "r1", eventoId: "t1", fecha: "2026-08-01" }),
    partido({ id: "r2", eventoId: "t1", fecha: "2026-08-01" }),
    partido({ id: "r3", eventoId: "t2", fecha: "2026-08-20", marcadorA: 2, marcadorB: 6 }),
    partido({ id: "r4", eventoId: "t3", fecha: "2026-07-05" }),
  ]);

  assert.deepEqual(meses.map((m) => m.mes), ["2026-08", "2026-07"]);
  assert.equal(meses[0].totales.partidos, 3);
  assert.equal(meses[0].eventos, 2);
  assert.equal(meses[0].totales.ganados, 2);
});
