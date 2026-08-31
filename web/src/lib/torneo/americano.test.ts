import test from "node:test";
import assert from "node:assert/strict";
import { generarAmericano, type Cuadro } from "./americano.ts";

function jugadores(n: number): string[] {
  return Array.from({ length: n }, (_, i) => `J${i + 1}`);
}

/** Todos los jugadores que aparecen en una ronda, jugando o descansando. */
function censoDeRonda(cuadro: Cuadro, indice: number): string[] {
  const ronda = cuadro.rondas[indice];
  return [
    ...ronda.partidos.flatMap((p) => [...p.equipoA, ...p.equipoB]),
    ...ronda.descansan,
  ];
}

test("nadie aparece dos veces en la misma ronda", () => {
  const cuadro = generarAmericano({ jugadores: jugadores(16), pistas: 3, rondas: 6 });

  for (let i = 0; i < cuadro.rondas.length; i++) {
    const censo = censoDeRonda(cuadro, i);
    assert.equal(
      new Set(censo).size,
      censo.length,
      `Alguien repite en la ronda ${i + 1}`,
    );
  }
});

test("todos los jugadores están en todas las rondas, jugando o descansando", () => {
  const lista = jugadores(14);
  const cuadro = generarAmericano({ jugadores: lista, pistas: 3, rondas: 5 });

  for (let i = 0; i < cuadro.rondas.length; i++) {
    assert.deepEqual(
      censoDeRonda(cuadro, i).sort(),
      [...lista].sort(),
      `Falta o sobra alguien en la ronda ${i + 1}`,
    );
  }
});

test("con 8 jugadores y 2 pistas nadie repite compañero en 5 rondas", () => {
  // Caso ideal: 8 jugadores dan 7 rondas sin repetir pareja, así que el
  // generador no tiene excusa para repetir ninguna en 5.
  const cuadro = generarAmericano({ jugadores: jugadores(8), pistas: 2, rondas: 5 });

  assert.equal(cuadro.calidad.companerosRepetidos, 0);
  assert.equal(cuadro.calidad.partidosPorJugador.min, 5);
  assert.equal(cuadro.calidad.partidosPorJugador.max, 5);
});

test("un americano de club (20 jugadores, 5 pistas, 7 rondas) no repite compañeros", () => {
  const cuadro = generarAmericano({ jugadores: jugadores(20), pistas: 5, rondas: 7 });

  assert.equal(cuadro.calidad.companerosRepetidos, 0);
  assert.equal(cuadro.rondas.length, 7);
  assert.equal(cuadro.rondas[0].partidos.length, 5);
  assert.equal(cuadro.rondas[0].descansan.length, 0);
});

test("cuando sobran jugadores, los descansos se reparten", () => {
  // 14 jugadores en 3 pistas: juegan 12 y descansan 2 en cada ronda.
  const cuadro = generarAmericano({ jugadores: jugadores(14), pistas: 3, rondas: 7 });

  for (const ronda of cuadro.rondas) {
    assert.equal(ronda.partidos.length, 3);
    assert.equal(ronda.descansan.length, 2);
  }

  const { min, max } = cuadro.calidad.descansosPorJugador;
  assert.ok(max - min <= 1, `Descansos desiguales: entre ${min} y ${max}`);

  const partidos = cuadro.calidad.partidosPorJugador;
  assert.ok(
    partidos.max - partidos.min <= 1,
    `Partidos desiguales: entre ${partidos.min} y ${partidos.max}`,
  );
});

test("sobran pistas: se usan sólo las que caben", () => {
  // 9 jugadores no llenan 4 pistas; sólo se puede montar 2 partidos.
  const cuadro = generarAmericano({ jugadores: jugadores(9), pistas: 4, rondas: 3 });

  for (const ronda of cuadro.rondas) {
    assert.equal(ronda.partidos.length, 2);
    assert.equal(ronda.descansan.length, 1);
  }
});

test("la misma semilla da siempre el mismo cuadro", () => {
  const opciones = { jugadores: jugadores(12), pistas: 3, rondas: 5, semilla: 42 };
  const a = generarAmericano(opciones);
  const b = generarAmericano(opciones);

  assert.deepEqual(a.rondas, b.rondas);
});

test("semillas distintas dan cuadros distintos", () => {
  const base = { jugadores: jugadores(12), pistas: 3, rondas: 5 };
  const a = generarAmericano({ ...base, semilla: 1 });
  const b = generarAmericano({ ...base, semilla: 999 });

  assert.notDeepEqual(a.rondas, b.rondas);
});

test("las pistas se numeran desde 1 y sin huecos", () => {
  const cuadro = generarAmericano({ jugadores: jugadores(16), pistas: 4, rondas: 3 });

  for (const ronda of cuadro.rondas) {
    assert.deepEqual(
      ronda.partidos.map((p) => p.pista),
      [1, 2, 3, 4],
    );
  }
});

test("rechaza las entradas imposibles", () => {
  assert.throws(
    () => generarAmericano({ jugadores: jugadores(3), pistas: 1, rondas: 3 }),
    /al menos 4 jugadores/,
  );
  assert.throws(
    () => generarAmericano({ jugadores: ["Ana", "Ana", "Luis", "Eva"], pistas: 1, rondas: 2 }),
    /repetidos/,
  );
  assert.throws(
    () => generarAmericano({ jugadores: jugadores(8), pistas: 0, rondas: 3 }),
    /al menos una pista/,
  );
  assert.throws(
    () => generarAmericano({ jugadores: jugadores(8), pistas: 2, rondas: 0 }),
    /al menos una ronda/,
  );
});
