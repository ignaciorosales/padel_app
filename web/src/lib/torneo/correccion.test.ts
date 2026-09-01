import test from "node:test";
import assert from "node:assert/strict";
import {
  aplicar,
  cuadroValido,
  moverJugador,
  moverPista,
  type PartidoCorregible,
} from "./correccion.ts";

/** Dos pistas, ocho jugando, "nueve" y "diez" descansando. */
function cuadro(): PartidoCorregible[] {
  return [
    { id: "m1", pista: 1, a1: "uno", a2: "dos", b1: "tres", b2: "cuatro" },
    { id: "m2", pista: 2, a1: "cinco", a2: "seis", b1: "siete", b2: "ocho" },
  ];
}

test("meter a quien descansa deja al otro descansando, sin duplicar a nadie", () => {
  const antes = cuadro();
  const despues = aplicar(antes, moverJugador(antes, "m1", "a1", "nueve"));

  assert.equal(despues[0].a1, "nueve");
  assert.ok(cuadroValido(despues));
  // "uno" ya no juega esta ronda.
  const jugando = despues.flatMap((p) => [p.a1, p.a2, p.b1, p.b2]);
  assert.ok(!jugando.includes("uno"));
});

test("traer a alguien de otro partido los intercambia, no lo clona", () => {
  const antes = cuadro();
  const despues = aplicar(antes, moverJugador(antes, "m1", "a1", "cinco"));

  assert.equal(despues[0].a1, "cinco");
  assert.equal(despues[1].a1, "uno");
  assert.ok(cuadroValido(despues));
});

test("intercambiar dentro del mismo partido cambia de pareja sin tocar el resto", () => {
  const antes = cuadro();
  const despues = aplicar(antes, moverJugador(antes, "m1", "a1", "tres"));

  assert.equal(despues[0].a1, "tres");
  assert.equal(despues[0].b1, "uno");
  assert.deepEqual(despues[1], antes[1]);
  assert.ok(cuadroValido(despues));
});

test("poner a quien ya estaba ahí no genera ningún cambio", () => {
  const antes = cuadro();
  assert.deepEqual(moverJugador(antes, "m1", "a1", "uno"), []);
});

test("un partido que no existe no rompe nada", () => {
  assert.deepEqual(moverJugador(cuadro(), "inventado", "a1", "nueve"), []);
});

test("mover a una pista libre no toca a nadie más", () => {
  const antes = cuadro();
  const despues = aplicar(antes, moverPista(antes, "m1", 5));

  assert.equal(despues[0].pista, 5);
  assert.equal(despues[1].pista, 2);
  assert.ok(cuadroValido(despues));
});

test("mover a una pista ocupada intercambia los dos partidos", () => {
  const antes = cuadro();
  const despues = aplicar(antes, moverPista(antes, "m1", 2));

  assert.equal(despues[0].pista, 2);
  assert.equal(despues[1].pista, 1);
  // La restricción unique (round_id, pista) seguiría contenta.
  assert.ok(cuadroValido(despues));
});

test("mover a la pista en la que ya está no genera cambios", () => {
  assert.deepEqual(moverPista(cuadro(), "m1", 1), []);
});

test("cuadroValido detecta a un jugador repetido", () => {
  const roto = cuadro();
  roto[1].a1 = "uno";
  assert.equal(cuadroValido(roto), false);
});

test("cuadroValido detecta dos partidos en la misma pista", () => {
  const roto = cuadro();
  roto[1].pista = 1;
  assert.equal(cuadroValido(roto), false);
});

test("una cadena de correcciones nunca deja el cuadro inválido", () => {
  let estado = cuadro();
  const movimientos: [string, "a1" | "a2" | "b1" | "b2", string][] = [
    ["m1", "a1", "cinco"],
    ["m2", "b2", "nueve"],
    ["m1", "b1", "diez"],
    ["m2", "a1", "tres"],
    ["m1", "a2", "ocho"],
  ];

  for (const [id, pos, quien] of movimientos) {
    estado = aplicar(estado, moverJugador(estado, id, pos, quien));
    assert.ok(cuadroValido(estado), `se rompió al poner ${quien} en ${id}.${pos}`);
  }
});
