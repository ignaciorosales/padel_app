/**
 * Los ámbitos del ranking.
 *
 * Lo que se prueba aquí es lo que decide si una tabla se puede enseñar como
 * ranking: quién entra, en qué puesto, y cuándo hay que decir que es una
 * estimación porque hay grupos que no se han cruzado. La ordenación en sí ya tiene
 * sus tests en ranking.test.ts.
 */

import test from "node:test";
import assert from "node:assert/strict";
import {
  AMBITOS,
  camarillasDeLasCoincidencias,
  comoSeLlamaEnLaTabla,
  esAmbito,
  ratingsDeLasFilas,
  tablaDelAmbito,
  type FilaDeCoincidencia,
  type FilaDelAmbito,
} from "./ambitos.ts";
import { OPCIONES } from "../rating/algoritmo.ts";

const ASENTADO = OPCIONES.partidosProvisionales + 5;

const jugador = (p: Partial<FilaDelAmbito> = {}): FilaDelAmbito => ({
  player_id: "nacho",
  nombre: "Ignacio",
  apellido: "Rosales",
  apodo: null,
  rating: 1612,
  desviacion: 110,
  confianza: 0.6,
  partidos_puntuados: ASENTADO,
  ultimo_partido: "2026-09-01",
  division: "3ª",
  escala: "uy-v1",
  ...p,
});

/** Un partido: los cuatro que lo jugaron, como los devuelve la función de Postgres. */
const partido = (id: string, ...jugadores: string[]): FilaDeCoincidencia[] =>
  jugadores.map((player_id) => ({ partido_id: id, player_id }));

// ----------------------------------------------------------------- ámbitos

test("los cuatro ámbitos van de más estrecho a más ancho", () => {
  assert.deepEqual(AMBITOS, ["club", "ciudad", "pais", "red"]);
});

test("un ámbito inventado no es un ámbito", () => {
  assert.equal(esAmbito("club"), true);
  assert.equal(esAmbito("provincia"), false);
});

// ------------------------------------------------------------- las filas

test("las filas se convierten sin redondear el rating", () => {
  const ratings = ratingsDeLasFilas([jugador({ rating: 1612.4 })]);

  assert.equal(ratings.get("nacho")!.rating, 1612.4);
  assert.equal(ratings.get("nacho")!.partidosPuntuados, ASENTADO);
});

test("en la tabla se enseña nombre y primer apellido, no el nombre entero", () => {
  assert.equal(
    comoSeLlamaEnLaTabla(jugador({ apellido: "Rosales Pérez" })),
    "Ignacio Rosales",
  );
  assert.equal(comoSeLlamaEnLaTabla(jugador({ apellido: null })), "Ignacio");
  // El apodo no se usa: un ranking es un documento, y los apodos no se reconocen
  // fuera del club propio.
  assert.equal(comoSeLlamaEnLaTabla(jugador({ apodo: "Nacho" })), "Ignacio Rosales");
});

// -------------------------------------------------------------- la tabla

test("ordena por rating y reparte puestos", () => {
  const tabla = tablaDelAmbito(
    [
      jugador({ player_id: "a", rating: 1500 }),
      jugador({ player_id: "b", rating: 1700 }),
      jugador({ player_id: "c", rating: 1600 }),
    ],
    [],
  );

  assert.deepEqual(
    tabla.filas.map((f) => f.jugadorId),
    ["b", "c", "a"],
  );
  assert.deepEqual(
    tabla.filas.map((f) => f.puesto),
    [1, 2, 3],
  );
});

test("los provisionales no salen, y se dice cuántos son", () => {
  const tabla = tablaDelAmbito(
    [
      jugador({ player_id: "asentado" }),
      jugador({ player_id: "nuevo", partidos_puntuados: 3 }),
      jugador({ player_id: "otro_nuevo", partidos_puntuados: 8 }),
    ],
    [],
  );

  assert.deepEqual(
    tabla.filas.map((f) => f.jugadorId),
    ["asentado"],
  );
  assert.equal(tabla.provisionales, 2);
});

test("filtrar por división da los puestos de esa división, no los generales", () => {
  const tabla = tablaDelAmbito(
    [
      jugador({ player_id: "primera", rating: 1950, division: "1ª" }),
      jugador({ player_id: "segunda", rating: 1800, division: "2ª" }),
      jugador({ player_id: "tercera_alto", rating: 1700, division: "3ª" }),
      jugador({ player_id: "tercera_bajo", rating: 1610, division: "3ª" }),
    ],
    [],
    { division: "3ª" },
  );

  assert.deepEqual(
    tabla.filas.map((f) => [f.jugadorId, f.puesto]),
    [
      ["tercera_alto", 1],
      ["tercera_bajo", 2],
    ],
  );
});

test("la división que se filtra es la guardada, no la que tocaría por rating", () => {
  // 1800 cae en 2ª por rating, pero su columna dice 3ª porque le faltan partidos
  // por sostener. Compite en 3ª, y el ranking de 3ª es donde tiene que salir.
  const tabla = tablaDelAmbito(
    [jugador({ player_id: "subiendo", rating: 1800, division: "3ª" })],
    [],
    { division: "3ª" },
  );

  assert.deepEqual(
    tabla.filas.map((f) => f.jugadorId),
    ["subiendo"],
  );
});

test("las divisiones del filtro salen en el orden de la escala", () => {
  const tabla = tablaDelAmbito(
    [
      jugador({ player_id: "a", division: "5ª" }),
      jugador({ player_id: "b", division: "1ª" }),
      jugador({ player_id: "c", division: "3ª" }),
    ],
    [],
  );

  assert.deepEqual(tabla.divisiones, ["1ª", "3ª", "5ª"]);
});

test("el filtro de divisiones lista el ámbito entero, no sólo la división filtrada", () => {
  const tabla = tablaDelAmbito(
    [
      jugador({ player_id: "a", division: "5ª" }),
      jugador({ player_id: "b", division: "1ª" }),
    ],
    [],
    { division: "1ª" },
  );

  assert.deepEqual(tabla.divisiones, ["1ª", "5ª"]);
  assert.equal(tabla.filas.length, 1);
});

// ---------------------------------------------------------- la fiabilidad

test("un club donde todos han jugado juntos es un ranking, no una estimación", () => {
  const tabla = tablaDelAmbito(
    [
      jugador({ player_id: "a" }),
      jugador({ player_id: "b" }),
      jugador({ player_id: "c" }),
      jugador({ player_id: "d" }),
    ],
    partido("m1", "a", "b", "c", "d"),
  );

  assert.equal(tabla.fiabilidad.comparable, true);
  assert.equal(tabla.fiabilidad.grupos, 1);
  assert.equal(tabla.fiabilidad.aviso, null);
});

test("dos clubes que nunca se han cruzado dan una estimación, y lo dice", () => {
  const tabla = tablaDelAmbito(
    [
      jugador({ player_id: "a" }),
      jugador({ player_id: "b" }),
      jugador({ player_id: "c" }),
      jugador({ player_id: "d" }),
      jugador({ player_id: "e" }),
      jugador({ player_id: "f" }),
      jugador({ player_id: "g" }),
      jugador({ player_id: "h" }),
    ],
    [...partido("m1", "a", "b", "c", "d"), ...partido("m2", "e", "f", "g", "h")],
  );

  assert.equal(tabla.fiabilidad.comparable, false);
  assert.equal(tabla.fiabilidad.grupos, 2);
  assert.equal(tabla.fiabilidad.aviso !== null, true);
});

test("un solo partido en común une los dos grupos", () => {
  // Es la razón por la que un torneo abierto vale por diez cerrados.
  const tabla = tablaDelAmbito(
    [
      jugador({ player_id: "a" }),
      jugador({ player_id: "b" }),
      jugador({ player_id: "c" }),
      jugador({ player_id: "d" }),
      jugador({ player_id: "e" }),
      jugador({ player_id: "f" }),
      jugador({ player_id: "g" }),
      jugador({ player_id: "h" }),
    ],
    [
      ...partido("m1", "a", "b", "c", "d"),
      ...partido("m2", "e", "f", "g", "h"),
      // El puente: uno de cada grupo, en el mismo partido.
      ...partido("m3", "a", "e", "b", "f"),
    ],
  );

  assert.equal(tabla.fiabilidad.comparable, true);
  assert.equal(tabla.fiabilidad.grupos, 1);
});

test("las coincidencias se agrupan por partido, no por jugador", () => {
  const camarillas = camarillasDeLasCoincidencias([
    ...partido("m1", "a", "b"),
    ...partido("m2", "c", "d"),
    ...partido("m1", "e"),
  ]);

  assert.equal(camarillas.length, 2);
  assert.deepEqual(camarillas[0].sort(), ["a", "b", "e"]);
  assert.deepEqual(camarillas[1].sort(), ["c", "d"]);
});

test("sin ninguna coincidencia, cada uno es su propio grupo", () => {
  const tabla = tablaDelAmbito(
    [jugador({ player_id: "a" }), jugador({ player_id: "b" })],
    [],
  );

  assert.equal(tabla.fiabilidad.comparable, false);
  assert.equal(tabla.fiabilidad.grupos, 2);
});

test("un ámbito vacío no es una estimación: no hay nada que estimar", () => {
  const tabla = tablaDelAmbito([], []);

  assert.deepEqual(tabla.filas, []);
  assert.equal(tabla.fiabilidad.comparable, true);
  assert.equal(tabla.provisionales, 0);
  assert.deepEqual(tabla.divisiones, []);
});

// ------------------------------------------------------------ el movimiento

test("el movimiento sale de comparar con la foto anterior", () => {
  const anterior = new Map([
    ["a", 3],
    ["b", 1],
  ]);

  const tabla = tablaDelAmbito(
    [jugador({ player_id: "a", rating: 1700 }), jugador({ player_id: "b", rating: 1600 })],
    [],
    { anterior },
  );

  const a = tabla.filas.find((f) => f.jugadorId === "a")!;
  const b = tabla.filas.find((f) => f.jugadorId === "b")!;

  assert.equal(a.movimiento, 2, "iba tercero y va primero");
  assert.equal(b.movimiento, -1, "iba primero y va segundo");
});

test("quien no estaba en la foto anterior no tiene flecha, y no es un cero", () => {
  const tabla = tablaDelAmbito([jugador({ player_id: "nuevo" })], [], {
    anterior: new Map(),
  });

  assert.equal(tabla.filas[0].movimiento, null);
});
