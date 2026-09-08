/**
 * Barrido de tamaños.
 *
 * Existe porque comprobar a mano que funciona con 8, 16 y 32 parejas no dice
 * nada de lo que pasa con 77. Los tamaños redondos son justo los que esconden
 * los fallos: son potencias de dos, se reparten exactos en grupos y no generan
 * ni byes ni grupos desiguales. Lo que rompe un torneo es el número feo.
 *
 * Estas pruebas no miran resultados concretos: comprueban invariantes —cosas
 * que tienen que ser ciertas siempre— sobre cientos de combinaciones.
 */

import test from "node:test";
import assert from "node:assert/strict";
import {
  clasificacionPorGrupo,
  clasificados,
  generarFaseGrupos,
} from "./parejas.ts";
import {
  campeon,
  generarCuadro,
  fasesEnOrden,
  llave,
  propagar,
  type ResultadoSlot,
  type SlotCuadro,
} from "./cuadro-final.ts";

const parejas = (n: number) => Array.from({ length: n }, (_, i) => `p${i}`);

/** Juega el cuadro entero (gana siempre el lado A) y devuelve el estado final. */
function jugarCuadro(cuadro: SlotCuadro[]) {
  const resultados = new Map<string, ResultadoSlot>();
  const rondas = fasesEnOrden(cuadro).length;

  for (let vuelta = 0; vuelta <= rondas; vuelta++) {
    for (const s of propagar(cuadro, resultados)) {
      const k = llave(s.fase, s.orden);
      if (!resultados.has(k) && s.parejaA && s.parejaB) {
        resultados.set(k, { juegosA: 6, juegosB: 2 });
      }
    }
  }

  return { estado: propagar(cuadro, resultados), resultados };
}

// ---------------------------------------------------------- fase de grupos

test("la fase de grupos cumple sus invariantes con cualquier número de parejas", () => {
  let combinaciones = 0;

  for (let n = 2; n <= 90; n++) {
    for (const grupos of [1, 2, 3, 5, 8, 16]) {
      if (grupos > n) continue;
      for (const pistas of [1, 3, 8]) {
        combinaciones++;
        const fase = generarFaseGrupos({ parejas: parejas(n), grupos, pistas });

        // Ninguna pareja se pierde ni se duplica al repartir.
        const repartidas = fase.grupos.flat();
        assert.equal(repartidas.length, n, `n=${n} g=${grupos}: se pierden parejas`);
        assert.equal(new Set(repartidas).size, n, `n=${n} g=${grupos}: parejas duplicadas`);

        // Los grupos quedan igualados: como mucho uno de diferencia.
        const tamanos = fase.grupos.map((g) => g.length);
        assert.ok(
          Math.max(...tamanos) - Math.min(...tamanos) <= 1,
          `n=${n} g=${grupos}: grupos desiguales ${tamanos.join(",")}`,
        );

        const todos = fase.jornadas.flatMap((j) => j.partidos);

        // Todas contra todas dentro del grupo, exactamente una vez.
        const esperados = fase.grupos.reduce(
          (s, g) => s + (g.length * (g.length - 1)) / 2,
          0,
        );
        assert.equal(todos.length, esperados, `n=${n} g=${grupos}: faltan o sobran partidos`);
        const cruces = todos.map((p) => [p.parejaA, p.parejaB].sort().join("|"));
        assert.equal(new Set(cruces).size, cruces.length, `n=${n} g=${grupos}: cruce repetido`);

        // Nunca se cruzan parejas de grupos distintos.
        const grupoDe = new Map<string, number>();
        fase.grupos.forEach((g, i) => g.forEach((p) => grupoDe.set(p, i + 1)));
        for (const p of todos) {
          assert.equal(grupoDe.get(p.parejaA), p.grupo);
          assert.equal(grupoDe.get(p.parejaB), p.grupo);
        }

        // Cada jornada es jugable: nadie en dos pistas a la vez, y ninguna
        // jornada pide más pistas de las que tiene el club.
        for (const j of fase.jornadas) {
          const enJuego = j.partidos.flatMap((p) => [p.parejaA, p.parejaB]);
          assert.equal(
            new Set(enJuego).size,
            enJuego.length,
            `n=${n} g=${grupos} pistas=${pistas}: alguien juega dos veces en la jornada ${j.numero}`,
          );
          assert.ok(
            j.partidos.length <= pistas,
            `n=${n} g=${grupos} pistas=${pistas}: la jornada ${j.numero} usa ${j.partidos.length}`,
          );
          const usadas = j.partidos.map((p) => p.pista);
          assert.equal(new Set(usadas).size, usadas.length, "pista repetida");
          assert.ok(usadas.every((p) => p >= 1 && p <= pistas), "pista fuera de rango");
        }
      }
    }
  }

  assert.ok(combinaciones > 1000, `sólo se probaron ${combinaciones} combinaciones`);
});

// ------------------------------------------------------------ cuadro final

test("el cuadro llega a un único campeón con cualquier número de clasificados", () => {
  for (let n = 2; n <= 128; n++) {
    const cuadro = generarCuadro(parejas(n));
    const { estado, resultados } = jugarCuadro(cuadro);

    assert.ok(campeon(estado, resultados), `n=${n}: se juega entero y no sale campeón`);

    // Nadie puede estar dos veces en la misma ronda.
    for (const fase of fasesEnOrden(estado)) {
      const enFase = estado
        .filter((s) => s.fase === fase)
        .flatMap((s) => [s.parejaA, s.parejaB])
        .filter(Boolean);
      assert.equal(
        new Set(enFase).size,
        enFase.length,
        `n=${n}: alguien aparece dos veces en ${fase}`,
      );
    }
  }
});

test("los byes son exactamente los huecos que sobran, y se los llevan los mejores", () => {
  for (let n = 2; n <= 128; n++) {
    const cuadro = generarCuadro(parejas(n));
    const primera = fasesEnOrden(cuadro)[0];
    const slots = cuadro.filter((s) => s.fase === primera);

    const tamano = slots.length * 2;
    const conBye = slots.filter(
      (s) => (s.parejaA === null) !== (s.parejaB === null),
    );

    assert.equal(conBye.length, tamano - n, `n=${n}: número de byes incorrecto`);

    // Un bye nunca deja los dos lados vacíos: eso sería un partido fantasma.
    assert.ok(
      !slots.some((s) => s.parejaA === null && s.parejaB === null),
      `n=${n}: hay un partido sin nadie`,
    );

    // Los byes van a los mejor sembrados, que son los primeros de la lista.
    const conByeIds = conBye.map((s) => s.parejaA ?? s.parejaB!);
    const mejores = parejas(n).slice(0, conBye.length);
    assert.deepEqual(
      [...conByeIds].sort(),
      [...mejores].sort(),
      `n=${n}: los byes no son de los mejor clasificados`,
    );
  }
});

// -------------------------------------------------- el torneo entero, en cadena

test("la cadena grupos → clasificados → cuadro aguanta cualquier tamaño", () => {
  let cadenas = 0;

  for (let n = 4; n <= 90; n++) {
    for (const grupos of [1, 2, 4, 8, 16, 20]) {
      if (grupos > n) continue;
      for (const porGrupo of [1, 2, 4]) {
        cadenas++;

        const fase = generarFaseGrupos({ parejas: parejas(n), grupos, pistas: 4 });
        const jugados = fase.jornadas.flatMap((j) =>
          j.partidos.map((p) => ({
            parejaA: p.parejaA,
            parejaB: p.parejaB,
            juegosA: 6,
            juegosB: 2,
          })),
        );

        const tablas = clasificacionPorGrupo(fase.grupos, jugados);
        const pasan = clasificados(
          tablas.map((t) => t.map((f) => f.jugadorId)),
          porGrupo,
        );

        // Nadie se clasifica dos veces.
        assert.equal(new Set(pasan).size, pasan.length, `n=${n} g=${grupos}: clasificado repetido`);
        assert.ok(pasan.length <= n, `n=${n}: pasan más de los que juegan`);

        // Con menos de dos clasificados no hay cuadro, y es legítimo.
        if (pasan.length < 2) continue;

        const cuadro = generarCuadro(pasan);
        const { estado, resultados } = jugarCuadro(cuadro);
        assert.ok(
          campeon(estado, resultados),
          `n=${n} g=${grupos} pasan/grupo=${porGrupo}: no sale campeón`,
        );
      }
    }
  }

  assert.ok(cadenas > 500, `sólo se probaron ${cadenas} cadenas`);
});

test("un torneo de 77 parejas se juega entero y sale una campeona", () => {
  const todas = parejas(77);

  const fase = generarFaseGrupos({ parejas: todas, grupos: 20, pistas: 6 });
  assert.equal(fase.grupos.flat().length, 77);

  const jugados = fase.jornadas.flatMap((j) =>
    j.partidos.map((p) => ({
      parejaA: p.parejaA,
      parejaB: p.parejaB,
      juegosA: 6,
      juegosB: 2,
    })),
  );

  const tablas = clasificacionPorGrupo(fase.grupos, jugados);
  const pasan = clasificados(tablas.map((t) => t.map((f) => f.jugadorId)), 2);

  assert.equal(pasan.length, 40, "20 grupos por 2 que pasan son 40");

  const cuadro = generarCuadro(pasan);
  assert.deepEqual(fasesEnOrden(cuadro), [
    "treintaidosavos",
    "dieciseisavos",
    "octavos",
    "cuartos",
    "semifinal",
    "final",
  ]);

  const { estado, resultados } = jugarCuadro(cuadro);
  assert.ok(campeon(estado, resultados));
});
