import test from "node:test";
import assert from "node:assert/strict";
import { calcularClasificacion, type PartidoJugado } from "./clasificacion.ts";

test("suma los juegos de cada jugador, no los de su pareja", () => {
  const tabla = calcularClasificacion(
    ["ana", "luis", "eva", "juan"],
    [{ a1: "ana", a2: "luis", b1: "eva", b2: "juan", juegosA: 6, juegosB: 2 }],
  );

  const ana = tabla.find((f) => f.jugadorId === "ana")!;
  assert.equal(ana.juegosFavor, 6);
  assert.equal(ana.juegosContra, 2);
  assert.equal(ana.diferencia, 4);
  assert.equal(ana.ganados, 1);
  assert.equal(ana.partidos, 1);

  const eva = tabla.find((f) => f.jugadorId === "eva")!;
  assert.equal(eva.juegosFavor, 2);
  assert.equal(eva.perdidos, 1);
});

test("ordena por juegos a favor", () => {
  const partidos: PartidoJugado[] = [
    { a1: "ana", a2: "luis", b1: "eva", b2: "juan", juegosA: 6, juegosB: 3 },
    { a1: "ana", a2: "eva", b1: "luis", b2: "juan", juegosA: 6, juegosB: 1 },
  ];

  const tabla = calcularClasificacion(["ana", "luis", "eva", "juan"], partidos);

  assert.equal(tabla[0].jugadorId, "ana");
  assert.equal(tabla[0].puesto, 1);
  assert.equal(tabla[0].juegosFavor, 12);
});

test("los empatados comparten puesto y el siguiente lo salta", () => {
  // luis y eva acaban exactamente iguales.
  const tabla = calcularClasificacion(
    ["ana", "luis", "eva", "juan"],
    [
      { a1: "ana", a2: "luis", b1: "eva", b2: "juan", juegosA: 6, juegosB: 6 },
      { a1: "ana", a2: "eva", b1: "luis", b2: "juan", juegosA: 6, juegosB: 6 },
    ],
  );

  assert.deepEqual(
    tabla.map((f) => [f.jugadorId, f.puesto]),
    [
      ["ana", 1],
      ["luis", 1],
      ["eva", 1],
      ["juan", 1],
    ],
  );
  assert.equal(tabla[0].empatados, 2);
});

test("desempata por diferencia y luego por partidos ganados", () => {
  const tabla = calcularClasificacion(
    ["a", "b", "c", "d", "e", "f", "g", "h"],
    [
      // "a" gana 6-0; "e" gana 6-4. Mismos juegos a favor, distinta diferencia.
      { a1: "a", a2: "b", b1: "c", b2: "d", juegosA: 6, juegosB: 0 },
      { a1: "e", a2: "f", b1: "g", b2: "h", juegosA: 6, juegosB: 4 },
    ],
  );

  assert.equal(tabla[0].jugadorId, "a");
  assert.equal(tabla[0].diferencia, 6);
  assert.equal(tabla[2].jugadorId, "e");
  assert.equal(tabla[2].diferencia, 2);
});

test("quien aún no ha jugado aparece a cero, no desaparece", () => {
  const tabla = calcularClasificacion(
    ["ana", "luis", "eva", "juan", "marta"],
    [{ a1: "ana", a2: "luis", b1: "eva", b2: "juan", juegosA: 6, juegosB: 2 }],
  );

  assert.equal(tabla.length, 5);
  const marta = tabla.find((f) => f.jugadorId === "marta")!;
  assert.equal(marta.partidos, 0);
  assert.equal(marta.juegosFavor, 0);
  assert.equal(marta.puesto, 5);
});

test("sin partidos, todos empatados en el puesto 1", () => {
  const tabla = calcularClasificacion(["ana", "luis"], []);
  assert.deepEqual(tabla.map((f) => f.puesto), [1, 1]);
});

test("un partido de alguien ya borrado no rompe la tabla", () => {
  const tabla = calcularClasificacion(
    ["ana", "luis", "eva"],
    [{ a1: "ana", a2: "luis", b1: "eva", b2: "fantasma", juegosA: 6, juegosB: 1 }],
  );

  assert.equal(tabla.length, 3);
  assert.ok(!tabla.some((f) => f.jugadorId === "fantasma"));
});
