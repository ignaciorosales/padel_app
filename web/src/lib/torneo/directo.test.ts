import test from "node:test";
import assert from "node:assert/strict";
import { porcentajeJugado, rondaDestacada, type EstadoRonda } from "./directo.ts";

const rondas = (...pares: [number, number][]): EstadoRonda[] =>
  pares.map(([jugados, total], i) => ({ id: `r${i + 1}`, jugados, total }));

test("la ronda que toca es la primera sin completar", () => {
  assert.deepEqual(rondaDestacada(rondas([3, 3], [1, 3], [0, 3])), {
    id: "r2",
    marca: "en juego",
  });
});

test("una ronda que aun no ha empezado dice «siguiente», no «en juego»", () => {
  assert.deepEqual(rondaDestacada(rondas([3, 3], [0, 3])), {
    id: "r2",
    marca: "siguiente",
  });
});

test("recien generadas las rondas, la primera es la siguiente", () => {
  assert.deepEqual(rondaDestacada(rondas([0, 3], [0, 3], [0, 3])), {
    id: "r1",
    marca: "siguiente",
  });
});

test("con el torneo entero jugado no se destaca ninguna", () => {
  assert.equal(rondaDestacada(rondas([3, 3], [3, 3])), null);
});

test("sin rondas no hay nada que destacar", () => {
  assert.equal(rondaDestacada([]), null);
});

test("una ronda vacia no cuenta como la que toca", () => {
  assert.deepEqual(rondaDestacada(rondas([0, 0], [0, 3])), {
    id: "r2",
    marca: "siguiente",
  });
});

test("que cuatro se adelanten no mueve la ronda actual", () => {
  // La 2 esta a medias y la 4 ya tiene un resultado porque unos iban sobrados.
  // La que el torneo espera sigue siendo la 2.
  assert.deepEqual(rondaDestacada(rondas([3, 3], [1, 3], [0, 3], [1, 3])), {
    id: "r2",
    marca: "en juego",
  });
});

test("el porcentaje no dice 0 habiendo empezado ni 100 sin terminar", () => {
  assert.equal(porcentajeJugado(1, 200), 1);
  assert.equal(porcentajeJugado(199, 200), 99);
  assert.equal(porcentajeJugado(0, 18), 0);
  assert.equal(porcentajeJugado(18, 18), 100);
});

test("el porcentaje redondea por el camino", () => {
  assert.equal(porcentajeJugado(9, 18), 50);
  assert.equal(porcentajeJugado(6, 18), 33);
});

test("sin partidos el porcentaje es cero, no una division por cero", () => {
  assert.equal(porcentajeJugado(0, 0), 0);
});
