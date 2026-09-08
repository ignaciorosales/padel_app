import test from "node:test";
import assert from "node:assert/strict";
import {
  campeon,
  generarCuadro,
  llave,
  ordenSiembra,
  propagar,
  recalcularCuadro,
  type ResultadoSlot,
  type SlotCuadro,
} from "./cuadro-final.ts";

const parejas = (n: number) => Array.from({ length: n }, (_, i) => `s${i + 1}`);

const slot = (cuadro: SlotCuadro[], fase: string, orden: number) =>
  cuadro.find((s) => s.fase === fase && s.orden === orden)!;

// ------------------------------------------------------------------ siembra

test("el 1 y el 2 caen en mitades opuestas y no pueden cruzarse antes de la final", () => {
  const cuadro = generarCuadro(parejas(8));

  // Cuartos 0 y 1 alimentan la semifinal 0; los cuartos 2 y 3, la semifinal 1.
  const donde = (pareja: string) => {
    const c = cuadro.find(
      (s) => s.fase === "cuartos" && (s.parejaA === pareja || s.parejaB === pareja),
    )!;
    return Math.floor(c.orden / 2);
  };

  assert.notEqual(donde("s1"), donde("s2"), "s1 y s2 en la misma mitad");
});

test("el primer sembrado juega contra el último", () => {
  const cuadro = generarCuadro(parejas(8));
  const primero = slot(cuadro, "cuartos", 0);
  assert.deepEqual([primero.parejaA, primero.parejaB], ["s1", "s8"]);
});

test("ordenSiembra da el orden clásico", () => {
  assert.deepEqual(ordenSiembra(2), [0, 1]);
  assert.deepEqual(ordenSiembra(4), [0, 3, 1, 2]);
  assert.deepEqual(ordenSiembra(8), [0, 7, 3, 4, 1, 6, 2, 5]);
});

// ----------------------------------------------------------------- estructura

test("8 parejas dan cuartos, semifinal y final", () => {
  const cuadro = generarCuadro(parejas(8));
  assert.equal(cuadro.filter((s) => s.fase === "cuartos").length, 4);
  assert.equal(cuadro.filter((s) => s.fase === "semifinal").length, 2);
  assert.equal(cuadro.filter((s) => s.fase === "final").length, 1);
});

test("2 parejas son sólo una final", () => {
  const cuadro = generarCuadro(parejas(2));
  assert.equal(cuadro.length, 1);
  assert.equal(cuadro[0].fase, "final");
});

test("el cuadro nace con todo vacío menos la primera ronda", () => {
  const cuadro = generarCuadro(parejas(8));
  assert.ok(
    cuadro
      .filter((s) => s.fase !== "cuartos")
      .every((s) => s.parejaA === null && s.parejaB === null),
    "la semifinal no existe hasta que acaban los cuartos",
  );
});

test("menos de dos parejas es un error con nombre", () => {
  assert.throws(() => generarCuadro(parejas(1)), /al menos 2 parejas/);
});

test("un torneo grande de verdad entra en el cuadro", () => {
  // 77 parejas en 20 grupos con 2 clasificadas por grupo dan 40, que necesitan
  // un cuadro de 64. Antes esto ni arrancaba.
  const cuadro = generarCuadro(parejas(40));
  assert.equal(cuadro.filter((s) => s.fase === "treintaidosavos").length, 32);
  assert.equal(cuadro.filter((s) => s.fase === "final").length, 1);
});

test("el techo son 128 parejas, y pasarse lo dice claro", () => {
  assert.doesNotThrow(() => generarCuadro(parejas(128)));
  assert.throws(() => generarCuadro(parejas(129)), /máximo son 128 parejas/);
});

// ---------------------------------------------------------------------- byes

test("con 6 parejas, los dos mejores pasan sin jugar", () => {
  const cuadro = generarCuadro(parejas(6));

  // Cuadro de 8: sobran dos huecos, y le tocan a los mejor sembrados.
  const conBye = cuadro.filter(
    (s) => s.fase === "cuartos" && (s.parejaA === null) !== (s.parejaB === null),
  );
  assert.equal(conBye.length, 2);

  // Y ya están colocados en semifinales desde el minuto cero.
  const enSemis = cuadro
    .filter((s) => s.fase === "semifinal")
    .flatMap((s) => [s.parejaA, s.parejaB])
    .filter(Boolean);
  assert.deepEqual(enSemis.sort(), ["s1", "s2"]);
});

test("un hueco de semifinal NO es un bye: nadie llega a la final sin jugar", () => {
  const cuadro = generarCuadro(parejas(8));
  const resultados = new Map<string, ResultadoSlot>([
    // Sólo se decide un cuarto: la semifinal 0 tiene un lado y el otro no.
    [llave("cuartos", 0), { juegosA: 6, juegosB: 2 }],
  ]);

  const avanzado = propagar(cuadro, resultados);
  const semi = slot(avanzado, "semifinal", 0);

  assert.equal(semi.parejaA, "s1");
  assert.equal(semi.parejaB, null);

  const final = slot(avanzado, "final", 0);
  assert.equal(final.parejaA, null, "s1 no puede estar en la final todavía");
  assert.equal(final.parejaB, null);
});

// --------------------------------------------------------------- propagación

test("el ganador del partido n va al partido n/2 de la ronda siguiente", () => {
  const cuadro = generarCuadro(parejas(8));
  const resultados = new Map<string, ResultadoSlot>([
    [llave("cuartos", 0), { juegosA: 6, juegosB: 1 }], // gana s1 → semi 0, lado A
    [llave("cuartos", 1), { juegosA: 1, juegosB: 6 }], // gana s5 → semi 0, lado B
    [llave("cuartos", 2), { juegosA: 6, juegosB: 1 }], // gana s2 → semi 1, lado A
    [llave("cuartos", 3), { juegosA: 6, juegosB: 1 }], // gana s3 → semi 1, lado B
  ]);

  const avanzado = propagar(cuadro, resultados);

  assert.deepEqual(
    [slot(avanzado, "semifinal", 0).parejaA, slot(avanzado, "semifinal", 0).parejaB],
    ["s1", "s5"],
  );
  assert.deepEqual(
    [slot(avanzado, "semifinal", 1).parejaA, slot(avanzado, "semifinal", 1).parejaB],
    ["s2", "s3"],
  );
});

test("un empate no decide: en eliminatoria alguien tiene que pasar", () => {
  const cuadro = generarCuadro(parejas(4));
  const avanzado = propagar(
    cuadro,
    new Map([[llave("semifinal", 0), { juegosA: 5, juegosB: 5 }]]),
  );
  assert.equal(slot(avanzado, "final", 0).parejaA, null);
});

test("corregir un resultado de cuartos arrastra la corrección hasta la final", () => {
  const cuadro = generarCuadro(parejas(4));

  const conError = new Map<string, ResultadoSlot>([
    [llave("semifinal", 0), { juegosA: 6, juegosB: 2 }], // gana s1
    [llave("semifinal", 1), { juegosA: 6, juegosB: 2 }], // gana s2
    [llave("final", 0), { juegosA: 6, juegosB: 3 }], // gana s1
  ]);
  assert.equal(campeon(propagar(cuadro, conError), conError), "s1");

  // El club se equivocó: la semifinal 0 la ganó el otro.
  const corregido = new Map(conError);
  corregido.set(llave("semifinal", 0), { juegosA: 2, juegosB: 6 });

  const avanzado = propagar(cuadro, corregido);
  assert.equal(slot(avanzado, "final", 0).parejaA, "s4", "la final se recalcula sola");
  // Y el campeón cambia con ella, sin tocar el resultado de la final.
  assert.equal(campeon(avanzado, corregido), "s4");
});

test("no hay campeón hasta que la final tiene resultado", () => {
  const cuadro = generarCuadro(parejas(4));
  assert.equal(campeon(cuadro, new Map()), null);
});

// ------------------------------------- recalcular tirando lo que ya no vale

test("al cambiar unos cuartos, la semifinal pierde el resultado que era de otros", () => {
  const inicial = generarCuadro(parejas(4));

  // Se juega todo: gana el lado A en las dos semis y en la final.
  const resultados = new Map<string, ResultadoSlot>([
    [llave("semifinal", 0), { juegosA: 6, juegosB: 2 }],
    [llave("semifinal", 1), { juegosA: 6, juegosB: 2 }],
    [llave("final", 0), { juegosA: 6, juegosB: 2 }],
  ]);
  const jugado = propagar(inicial, resultados);
  assert.equal(slot(jugado, "final", 0).parejaA, "s1");

  // Ahora se corrige la semifinal 0: gana el otro.
  const corregidos = new Map(resultados);
  corregidos.set(llave("semifinal", 0), { juegosA: 2, juegosB: 6 });

  const { cuadro, resultados: vivos } = recalcularCuadro(jugado, corregidos);

  assert.equal(slot(cuadro, "final", 0).parejaA, "s4", "la final cambia de finalista");
  assert.ok(
    !vivos.has(llave("final", 0)),
    "y el resultado de la final se descarta: era de una pareja que ya no juega",
  );
  assert.ok(vivos.has(llave("semifinal", 0)), "la semifinal corregida sí conserva el suyo");
});

test("si la corrección no cambia a nadie, no se tira ningún resultado", () => {
  const inicial = generarCuadro(parejas(4));
  const resultados = new Map<string, ResultadoSlot>([
    [llave("semifinal", 0), { juegosA: 6, juegosB: 2 }],
    [llave("semifinal", 1), { juegosA: 6, juegosB: 2 }],
    [llave("final", 0), { juegosA: 6, juegosB: 2 }],
  ]);
  const jugado = propagar(inicial, resultados);

  // Mismo ganador, otro marcador.
  const otros = new Map(resultados);
  otros.set(llave("semifinal", 0), { juegosA: 6, juegosB: 4 });

  const { resultados: vivos } = recalcularCuadro(jugado, otros);
  assert.equal(vivos.size, 3, "no se descarta nada");
});

test("una corrección en la primera ronda se arrastra dos rondas abajo", () => {
  const inicial = generarCuadro(parejas(8));

  const resultados = new Map<string, ResultadoSlot>();
  for (let i = 0; i < 4; i++) {
    resultados.set(llave("cuartos", i), { juegosA: 6, juegosB: 1 });
  }
  let jugado = propagar(inicial, resultados);
  resultados.set(llave("semifinal", 0), { juegosA: 6, juegosB: 1 });
  resultados.set(llave("semifinal", 1), { juegosA: 6, juegosB: 1 });
  jugado = propagar(inicial, resultados);
  resultados.set(llave("final", 0), { juegosA: 6, juegosB: 1 });
  jugado = propagar(inicial, resultados);

  const campeonaAntes = campeon(jugado, resultados);
  assert.equal(campeonaAntes, "s1");

  // Se corrige el primer cuarto: s1 pierde y se cae del cuadro.
  const corregidos = new Map(resultados);
  corregidos.set(llave("cuartos", 0), { juegosA: 1, juegosB: 6 });

  const { cuadro, resultados: vivos } = recalcularCuadro(jugado, corregidos);

  const enFinal = [slot(cuadro, "final", 0).parejaA, slot(cuadro, "final", 0).parejaB];
  assert.ok(!enFinal.includes("s1"), "s1 ya no puede estar en la final");
  assert.ok(!vivos.has(llave("final", 0)), "el resultado de la final se descarta");
  assert.ok(
    !vivos.has(llave("semifinal", 0)),
    "y el de la semifinal por la que pasaba, también",
  );
  assert.ok(vivos.has(llave("semifinal", 1)), "la otra semifinal no se toca");
});

test("propagar no modifica el cuadro que recibe", () => {
  const cuadro = generarCuadro(parejas(4));
  const antes = JSON.stringify(cuadro);
  propagar(cuadro, new Map([[llave("semifinal", 0), { juegosA: 6, juegosB: 0 }]]));
  assert.equal(JSON.stringify(cuadro), antes);
});
