import test from "node:test";
import assert from "node:assert/strict";
import {
  clasificacionParejas,
  clasificacionPorGrupo,
  clasificados,
  generarFaseGrupos,
  repartirEnGrupos,
  roundRobin,
  type ParejaId,
} from "./parejas.ts";

const parejas = (n: number): ParejaId[] =>
  Array.from({ length: n }, (_, i) => `p${i + 1}`);

// ---------------------------------------------------------------- serpentina

test("en serpentina los grupos quedan igualados, no por bloques", () => {
  const grupos = repartirEnGrupos(parejas(8), 2);
  assert.deepEqual(grupos[0], ["p1", "p4", "p5", "p8"]);
  assert.deepEqual(grupos[1], ["p2", "p3", "p6", "p7"]);
});

test("con parejas de sobra ningún grupo se queda con dos de más", () => {
  const grupos = repartirEnGrupos(parejas(11), 3);
  const tamanos = grupos.map((g) => g.length);
  assert.ok(Math.max(...tamanos) - Math.min(...tamanos) <= 1);
  assert.equal(tamanos.reduce((a, b) => a + b, 0), 11);
});

test("pedir más grupos que parejas no deja grupos vacíos", () => {
  const grupos = repartirEnGrupos(parejas(3), 8);
  assert.equal(grupos.length, 3);
  assert.ok(grupos.every((g) => g.length > 0));
});

// --------------------------------------------------------------- round robin

test("todas contra todas, exactamente una vez", () => {
  const vueltas = roundRobin(parejas(6));
  const cruces = vueltas.flat().map(([a, b]) => [a, b].sort().join("-"));

  // 6 parejas → 15 cruces posibles, todos distintos.
  assert.equal(cruces.length, 15);
  assert.equal(new Set(cruces).size, 15);
  assert.equal(vueltas.length, 5);
});

test("con parejas impares alguien descansa cada vuelta, y nunca dos veces seguidas la misma cuenta", () => {
  const ids = parejas(5);
  const vueltas = roundRobin(ids);

  assert.equal(vueltas.length, 5);
  for (const vuelta of vueltas) {
    assert.equal(vuelta.length, 2, "de 5 parejas sólo pueden jugar 4");
  }

  // Aun así, todos se cruzan con todos: 10 cruces distintos.
  const cruces = vueltas.flat().map(([a, b]) => [a, b].sort().join("-"));
  assert.equal(new Set(cruces).size, 10);
});

test("nadie juega dos veces en la misma vuelta", () => {
  for (const n of [4, 5, 6, 7, 8, 9]) {
    for (const vuelta of roundRobin(parejas(n))) {
      const enJuego = vuelta.flat();
      assert.equal(
        new Set(enJuego).size,
        enJuego.length,
        `con ${n} parejas alguien se repite en una vuelta`,
      );
    }
  }
});

test("con menos de dos parejas no hay partidos", () => {
  assert.deepEqual(roundRobin([]), []);
  assert.deepEqual(roundRobin(["p1"]), []);
});

// ------------------------------------------------------------ fase de grupos

test("respeta el número de pistas", () => {
  const { jornadas } = generarFaseGrupos({
    parejas: parejas(8),
    grupos: 2,
    pistas: 2,
  });
  assert.ok(jornadas.every((j) => j.partidos.length <= 2));
});

test("nadie juega dos partidos en la misma jornada", () => {
  const { jornadas } = generarFaseGrupos({
    parejas: parejas(10),
    grupos: 2,
    pistas: 3,
  });

  for (const j of jornadas) {
    const enJuego = j.partidos.flatMap((p) => [p.parejaA, p.parejaB]);
    assert.equal(new Set(enJuego).size, enJuego.length);
  }
});

test("las pistas de una jornada no se repiten", () => {
  const { jornadas } = generarFaseGrupos({
    parejas: parejas(12),
    grupos: 3,
    pistas: 4,
  });

  for (const j of jornadas) {
    const pistas = j.partidos.map((p) => p.pista);
    assert.equal(new Set(pistas).size, pistas.length);
  }
});

test("sólo se cruzan parejas del mismo grupo", () => {
  const { grupos, jornadas } = generarFaseGrupos({
    parejas: parejas(12),
    grupos: 3,
    pistas: 3,
  });

  const grupoDe = new Map<string, number>();
  grupos.forEach((g, i) => g.forEach((p) => grupoDe.set(p, i + 1)));

  for (const j of jornadas) {
    for (const p of j.partidos) {
      assert.equal(grupoDe.get(p.parejaA), p.grupo);
      assert.equal(grupoDe.get(p.parejaB), p.grupo);
    }
  }
});

test("se juegan todos los cruces de todos los grupos y ninguno de más", () => {
  const { grupos, jornadas } = generarFaseGrupos({
    parejas: parejas(9),
    grupos: 3,
    pistas: 2,
  });

  // Cada grupo de 3 tiene 3 cruces: 9 en total.
  const esperados = grupos.reduce((n, g) => n + (g.length * (g.length - 1)) / 2, 0);
  const jugados = jornadas.flatMap((j) => j.partidos);

  assert.equal(jugados.length, esperados);
  const cruces = jugados.map((p) => [p.parejaA, p.parejaB].sort().join("-"));
  assert.equal(new Set(cruces).size, esperados);
});

test("con una sola pista sale una jornada por partido", () => {
  const { jornadas } = generarFaseGrupos({
    parejas: parejas(4),
    grupos: 1,
    pistas: 1,
  });
  assert.equal(jornadas.length, 6);
  assert.ok(jornadas.every((j) => j.partidos.length === 1));
});

test("los que descansan son los que no aparecen en ningún partido", () => {
  const { jornadas } = generarFaseGrupos({
    parejas: parejas(6),
    grupos: 1,
    pistas: 1,
  });

  for (const j of jornadas) {
    const jugando = new Set(j.partidos.flatMap((p) => [p.parejaA, p.parejaB]));
    assert.equal(j.descansan.length, 6 - jugando.size);
    assert.ok(j.descansan.every((p) => !jugando.has(p)));
  }
});

test("menos de dos parejas es un error con nombre, no un cuadro vacío", () => {
  assert.throws(
    () => generarFaseGrupos({ parejas: parejas(1), grupos: 1, pistas: 2 }),
    /al menos 2 parejas/,
  );
});

// ------------------------------------------------------------- clasificados

test("los clasificados se intercalan por grupos para no repetir cruces", () => {
  const orden = clasificados([["1a", "1b", "1c"], ["2a", "2b", "2c"]], 2);
  // Primeros de cada grupo, luego segundos: el 1º del A no cae contra el 2º
  // del A en la primera eliminatoria.
  assert.deepEqual(orden, ["1a", "2a", "1b", "2b"]);
});

test("un grupo con menos parejas de las que clasifican no rompe la siembra", () => {
  const orden = clasificados([["1a", "1b"], ["2a"]], 2);
  assert.deepEqual(orden, ["1a", "2a", "1b"]);
});

// ------------------------------------------------- clasificación de parejas

test("en parejas manda ganar partidos, no acumular juegos", () => {
  // "solida" gana dos ajustados; "goleadora" gana uno por paliza y pierde uno.
  const tabla = clasificacionParejas(
    ["solida", "goleadora", "otra"],
    [
      { parejaA: "solida", parejaB: "goleadora", juegosA: 6, juegosB: 5 },
      { parejaA: "solida", parejaB: "otra", juegosA: 6, juegosB: 5 },
      { parejaA: "goleadora", parejaB: "otra", juegosA: 12, juegosB: 0 },
    ],
  );

  const solida = tabla.find((f) => f.jugadorId === "solida")!;
  const goleadora = tabla.find((f) => f.jugadorId === "goleadora")!;

  assert.ok(
    goleadora.juegosFavor > solida.juegosFavor,
    "la goleadora suma más juegos",
  );
  assert.equal(solida.puesto, 1, "pero pasa la que gana partidos");
  assert.ok(goleadora.puesto > solida.puesto);
});

test("cada partido suma a dos parejas, no a cuatro jugadores", () => {
  const tabla = clasificacionParejas(
    ["a", "b"],
    [{ parejaA: "a", parejaB: "b", juegosA: 6, juegosB: 3 }],
  );
  assert.equal(tabla.length, 2);
  assert.equal(tabla.find((f) => f.jugadorId === "a")!.juegosFavor, 6);
  assert.equal(tabla.find((f) => f.jugadorId === "b")!.juegosContra, 6);
});

test("cada grupo se numera desde el puesto 1", () => {
  const tablas = clasificacionPorGrupo(
    [
      ["a1", "a2"],
      ["b1", "b2"],
    ],
    [
      { parejaA: "a1", parejaB: "a2", juegosA: 6, juegosB: 1 },
      { parejaA: "b1", parejaB: "b2", juegosA: 6, juegosB: 1 },
    ],
  );

  assert.equal(tablas.length, 2);
  assert.equal(tablas[0][0].puesto, 1);
  assert.equal(tablas[1][0].puesto, 1, "el grupo B también tiene un primero");
});

test("un grupo no cuenta partidos de otro grupo", () => {
  const tablas = clasificacionPorGrupo(
    [["a1", "a2"], ["b1"]],
    [
      { parejaA: "a1", parejaB: "a2", juegosA: 6, juegosB: 1 },
      // Cruce imposible entre grupos: no debe contar en ninguna tabla.
      { parejaA: "a1", parejaB: "b1", juegosA: 6, juegosB: 0 },
    ],
  );

  assert.equal(tablas[0].find((f) => f.jugadorId === "a1")!.partidos, 1);
  assert.equal(tablas[1].find((f) => f.jugadorId === "b1")!.partidos, 0);
});
