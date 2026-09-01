import test from "node:test";
import assert from "node:assert/strict";
import {
  calcularClasificacion,
  DESEMPATES_POR_DEFECTO,
  normalizarDesempates,
  type PartidoJugado,
} from "./clasificacion.ts";

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

// ----------------------------------------------------- desempates configurables

/**
 * El caso que discuten los clubes, montado a propósito para que los dos
 * criterios den ganadores distintos:
 *
 *   · "ganador" gana sus dos partidos, ajustados  → 8 juegos, 2 victorias
 *   · "acumulador" pierde los tres, uno de ellos goleado → 15 juegos, 0 victorias
 *
 * Con "juegos a favor" primero gana el acumulador; con "partidos ganados"
 * primero, el ganador. Si algún día el orden dejara de cambiar, las pruebas de
 * abajo dejarían de comprobar nada, así que lo primero que verifican es eso.
 */
const JUGADORES = ["ganador", "acumulador", "p1", "p2", "p3", "p4"];

const DISPUTA: PartidoJugado[] = [
  { a1: "ganador", a2: "p1", b1: "acumulador", b2: "p2", juegosA: 4, juegosB: 3 },
  { a1: "ganador", a2: "p2", b1: "acumulador", b2: "p1", juegosA: 4, juegosB: 3 },
  // El acumulador suma nueve juegos en un partido que pierde igual.
  { a1: "acumulador", a2: "p3", b1: "p1", b2: "p4", juegosA: 9, juegosB: 10 },
];

const puestoDe = (
  tabla: ReturnType<typeof calcularClasificacion>,
  id: string,
) => tabla.find((f) => f.jugadorId === id)!.puesto;

test("el escenario de prueba de verdad separa los dos criterios", () => {
  const tabla = calcularClasificacion(JUGADORES, DISPUTA);
  const g = tabla.find((f) => f.jugadorId === "ganador")!;
  const a = tabla.find((f) => f.jugadorId === "acumulador")!;

  assert.ok(a.juegosFavor > g.juegosFavor, "el acumulador suma más juegos");
  assert.ok(g.ganados > a.ganados, "pero el ganador gana más partidos");
});

test("por defecto manda quien más juegos suma", () => {
  const tabla = calcularClasificacion(JUGADORES, DISPUTA);
  assert.ok(puestoDe(tabla, "acumulador") < puestoDe(tabla, "ganador"));
});

test("poniendo 'ganados' primero se le da la vuelta al podio", () => {
  const tabla = calcularClasificacion(JUGADORES, DISPUTA, [
    "ganados",
    "juegos_favor",
  ]);
  assert.ok(puestoDe(tabla, "ganador") < puestoDe(tabla, "acumulador"));
});

test("'menos juegos en contra' ordena al revés que los demás", () => {
  const tabla = calcularClasificacion(JUGADORES, DISPUTA, ["juegos_contra"]);
  for (let i = 1; i < tabla.length; i++) {
    assert.ok(
      tabla[i - 1].juegosContra <= tabla[i].juegosContra,
      "quien menos juegos encaja tiene que ir primero",
    );
  }
});

test("con un solo criterio, empatar en él comparte puesto", () => {
  const tabla = calcularClasificacion(
    ["ana", "luis", "eva", "juan"],
    [{ a1: "ana", a2: "luis", b1: "eva", b2: "juan", juegosA: 6, juegosB: 6 }],
    ["juegos_favor"],
  );
  assert.ok(tabla.every((f) => f.puesto === 1));
});

test("un criterio inventado no rompe la clasificación", () => {
  const tabla = calcularClasificacion(JUGADORES, DISPUTA, [
    "esto_no_existe" as never,
    "juegos_favor",
  ]);
  assert.equal(tabla.length, JUGADORES.length);
  assert.equal(tabla[0].puesto, 1);
});

test("normalizarDesempates limpia basura y no deja la lista vacía", () => {
  assert.deepEqual(normalizarDesempates(null), DESEMPATES_POR_DEFECTO);
  assert.deepEqual(normalizarDesempates([]), DESEMPATES_POR_DEFECTO);
  assert.deepEqual(normalizarDesempates(["nada", 7]), DESEMPATES_POR_DEFECTO);
  assert.deepEqual(normalizarDesempates(["ganados", "ganados"]), ["ganados"]);
  assert.deepEqual(normalizarDesempates(["diferencia", "mal", "ganados"]), [
    "diferencia",
    "ganados",
  ]);
});
