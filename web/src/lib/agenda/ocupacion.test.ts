import test from "node:test";
import assert from "node:assert/strict";
import {
  ocupacionesDeTorneo,
  pistasQueFaltan,
  rangoTsrange,
  type PartidoEnAgenda,
} from "./ocupacion.ts";

const PISTAS = new Map([
  [1, "court-1"],
  [2, "court-2"],
]);

function torneo(partidos: PartidoEnAgenda[], minutos = 20) {
  return {
    clubId: "club",
    torneoId: "torneo",
    fecha: "2026-09-05",
    minutosPorRonda: minutos,
    pistaAPista: PISTAS,
    partidos,
  };
}

test("el rango es medio abierto: dos rondas seguidas no se solapan", () => {
  const primera = rangoTsrange("2026-09-05", "10:00", 20);
  const segunda = rangoTsrange("2026-09-05", "10:20", 20);

  assert.equal(primera, '["2026-09-05 10:00:00","2026-09-05 10:20:00")');
  assert.equal(segunda, '["2026-09-05 10:20:00","2026-09-05 10:40:00")');
});

test("la hora que viene de Postgres con segundos vale igual", () => {
  assert.equal(
    rangoTsrange("2026-09-05", "10:00:00", 20),
    rangoTsrange("2026-09-05", "10:00", 20),
  );
});

test("un partido de madrugada no da la vuelta al reloj y deja el rango al revés", () => {
  // Con vuelta de reloj el fin saldría "00:20" del mismo día, o sea antes del
  // principio, y la base de datos rechazaría la fila entera.
  const rango = rangoTsrange("2026-09-05", "23:50", 30);
  assert.equal(rango, '["2026-09-05 23:50:00","2026-09-05 23:59:00")');
});

test("cada partido con hora y pista conocida ocupa su hueco", () => {
  const filas = ocupacionesDeTorneo(
    torneo([
      { id: "m1", pista: 1, hora: "10:00" },
      { id: "m2", pista: 2, hora: "10:00" },
    ]),
  );

  assert.equal(filas.length, 2);
  assert.deepEqual(filas[0], {
    club_id: "club",
    court_id: "court-1",
    durante: '["2026-09-05 10:00:00","2026-09-05 10:20:00")',
    motivo: "torneo",
    tournament_id: "torneo",
    match_id: "m1",
  });
  assert.equal(filas[1].court_id, "court-2");
});

test("una ronda sin hora no ocupa nada: media ocupación no es una ocupación", () => {
  const filas = ocupacionesDeTorneo(
    torneo([
      { id: "m1", pista: 1, hora: null },
      { id: "m2", pista: 2, hora: "10:00" },
    ]),
  );

  assert.deepEqual(
    filas.map((f) => f.match_id),
    ["m2"],
  );
});

test("un partido movido a una pista que el torneo no tiene se queda fuera, no rompe", () => {
  const filas = ocupacionesDeTorneo(
    torneo([
      { id: "m1", pista: 7, hora: "10:00" },
      { id: "m2", pista: 1, hora: "10:00" },
    ]),
  );

  assert.deepEqual(
    filas.map((f) => f.match_id),
    ["m2"],
  );
});

test("las dos pistas de la misma hora son distintas, y la misma pista a horas distintas no choca", () => {
  const filas = ocupacionesDeTorneo(
    torneo([
      { id: "m1", pista: 1, hora: "10:00" },
      { id: "m2", pista: 1, hora: "10:20" },
    ]),
  );

  assert.equal(filas[0].court_id, filas[1].court_id);
  assert.notEqual(filas[0].durante, filas[1].durante);
});

test("un club sin pistas dadas de alta recibe las que le faltan, numeradas", () => {
  assert.deepEqual(pistasQueFaltan([], 3), [
    { nombre: "Pista 1", orden: 1 },
    { nombre: "Pista 2", orden: 2 },
    { nombre: "Pista 3", orden: 3 },
  ]);
});

test("no se duplican las pistas que el club ya tiene, aunque estén salteadas", () => {
  assert.deepEqual(pistasQueFaltan([1, 3], 4), [
    { nombre: "Pista 2", orden: 2 },
    { nombre: "Pista 4", orden: 4 },
  ]);
});

test("un club con más pistas que el torneo no gana ninguna", () => {
  assert.deepEqual(pistasQueFaltan([1, 2, 3, 4], 2), []);
});
