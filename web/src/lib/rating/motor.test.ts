import test from "node:test";
import assert from "node:assert/strict";
import {
  historialDeRating,
  procesar,
  resumenDeRating,
  ultimoCambioDeDivision,
} from "./motor.ts";
import {
  confianzaDe,
  esProvisional,
  kDe,
  modificadorPorMarcador,
  OPCIONES,
  oxidar,
  probabilidadEsperada,
  ratingNuevo,
  VERSION_ALGORITMO,
  type PartidoPuntuable,
} from "./algoritmo.ts";
import { ESCALA_UY, ratingInicialDe } from "./divisiones.ts";

const partido = (p: Partial<PartidoPuntuable> = {}): PartidoPuntuable => ({
  id: "p1",
  fecha: "2026-08-15",
  origen: "torneo",
  a: ["nacho", "juan"],
  b: ["santi", "tincho"],
  marcadorA: 6,
  marcadorB: 4,
  ...p,
});

const CUATRO = new Map([
  ["nacho", 1525],
  ["juan", 1525],
  ["santi", 1525],
  ["tincho", 1525],
]);

const ratingDe = (e: ReturnType<typeof procesar>, id: string) =>
  e.ratings.get(id)!.rating;

// -------------------------------------------------------------- lo básico

test("entre iguales se espera medio partido para cada pareja", () => {
  assert.equal(probabilidadEsperada(1500, 1500), 0.5);
});

test("ganar sube y perder baja, siempre", () => {
  const e = procesar([partido()], { ratingsIniciales: CUATRO });

  assert.ok(ratingDe(e, "nacho") > 1525);
  assert.ok(ratingDe(e, "santi") < 1525);
});

test("ganar nunca baja el rating, ni siendo el favorito clarísimo", () => {
  const desigual = new Map([
    ["nacho", 1900],
    ["juan", 1900],
    ["santi", 1400],
    ["tincho", 1400],
  ]);
  // Gana apretadísimo: con margen puro esto le habría bajado el rating.
  const e = procesar([partido({ marcadorA: 6, marcadorB: 5 })], {
    ratingsIniciales: desigual,
  });

  assert.ok(ratingDe(e, "nacho") > 1900);
  assert.ok(ratingDe(e, "santi") < 1400);
});

test("lo que gana una pareja lo pierde la otra: la red no se infla", () => {
  const e = procesar(
    [
      partido({ id: "p1", marcadorA: 6, marcadorB: 4 }),
      partido({ id: "p2", fecha: "2026-08-16", marcadorA: 0, marcadorB: 6 }),
      partido({ id: "p3", fecha: "2026-08-17", marcadorA: 6, marcadorB: 6 }),
    ],
    { ratingsIniciales: CUATRO },
  );

  const suma = [...e.ratings.values()].reduce((t, r) => t + r.rating, 0);
  assert.ok(Math.abs(suma - 4 * 1525) < 1e-9);
});

// ------------------------------------------------------- manda ganar

test("ganarle a una pareja fuerte da mucho más que ganar por paliza a una floja", () => {
  const contraFuertes = procesar(
    [partido({ marcadorA: 6, marcadorB: 5 })],
    {
      ratingsIniciales: new Map([
        ["nacho", 1500],
        ["juan", 1500],
        ["santi", 1800],
        ["tincho", 1800],
      ]),
    },
  );
  const palizaAFlojos = procesar([partido({ marcadorA: 6, marcadorB: 0 })], {
    ratingsIniciales: new Map([
      ["nacho", 1500],
      ["juan", 1500],
      ["santi", 1200],
      ["tincho", 1200],
    ]),
  });

  assert.ok(
    ratingDe(contraFuertes, "nacho") - 1500 >
      ratingDe(palizaAFlojos, "nacho") - 1500,
  );
});

test("el marcador modula poco: entre 0,85 y 1,15", () => {
  assert.equal(modificadorPorMarcador(6, 6), OPCIONES.modificadorMinimo);
  assert.equal(modificadorPorMarcador(6, 0), OPCIONES.modificadorMaximo);

  const apretado = modificadorPorMarcador(6, 5);
  assert.ok(apretado > 0.85 && apretado < 0.95);
});

test("una paliza no puede valer el doble que una victoria apretada", () => {
  const apretada = procesar([partido({ marcadorA: 6, marcadorB: 5 })], {
    ratingsIniciales: CUATRO,
  });
  const paliza = procesar([partido({ marcadorA: 6, marcadorB: 0 })], {
    ratingsIniciales: CUATRO,
  });

  const razon = (ratingDe(paliza, "nacho") - 1525) / (ratingDe(apretada, "nacho") - 1525);
  assert.ok(razon > 1 && razon < 1.4, `la paliza vale ${razon.toFixed(2)} veces más`);
});

test("un empate deja a los cuatro donde estaban", () => {
  const e = procesar([partido({ marcadorA: 5, marcadorB: 5 })], {
    ratingsIniciales: CUATRO,
  });

  assert.equal(ratingDe(e, "nacho"), 1525);
  assert.equal(ratingDe(e, "santi"), 1525);
});

// ------------------------------------------------------ incertidumbre

test("un jugador nuevo se mueve mucho más rápido que uno asentado", () => {
  const nuevo = ratingNuevo("x", 1525);
  const asentado = { ...nuevo, desviacion: OPCIONES.desviacionMinima };

  assert.ok(kDe(nuevo) > kDe(asentado) * 3);
  assert.equal(kDe(nuevo), OPCIONES.kMaxima);
  assert.equal(kDe(asentado), OPCIONES.kMinima);
});

test("la confianza sube con los partidos, pero no llega arriba enseguida", () => {
  const jugar = (cuantos: number) =>
    procesar(
      Array.from({ length: cuantos }, (_, i) =>
        partido({
          id: `p${i}`,
          fecha: `2026-${String(1 + Math.floor(i / 28)).padStart(2, "0")}-${String(1 + (i % 28)).padStart(2, "0")}`,
        }),
      ),
      { ratingsIniciales: CUATRO },
    ).ratings.get("nacho")!;

  const dosMañanas = jugar(16);
  const unaTemporada = jugar(100);

  assert.equal(dosMañanas.partidosPuntuados, 16);
  assert.equal(esProvisional(dosMañanas), false, "ya no es provisional");

  // Pero tampoco está resuelto: dos mañanas de americano no dan para asegurar
  // nada. Un sistema que dice estar seguro de todo en dos meses no se cree.
  assert.ok(dosMañanas.confianza < 0.5, `confianza ${dosMañanas.confianza.toFixed(2)}`);
  assert.ok(unaTemporada.confianza > dosMañanas.confianza);
  assert.ok(unaTemporada.confianza > 0.9);
  assert.ok(unaTemporada.confianza < 1, "nunca se está del todo seguro");
});

test("con pocos partidos el rating es provisional", () => {
  const e = procesar([partido()], { ratingsIniciales: CUATRO });
  assert.equal(esProvisional(e.ratings.get("nacho")!), true);
});

test("quien lleva medio año sin jugar no baja de rating, pero se sabe menos de él", () => {
  const e = procesar([partido()], { ratingsIniciales: CUATRO });
  const antes = e.ratings.get("nacho")!;
  const despues = oxidar(antes, "2027-06-01");

  assert.equal(despues.rating, antes.rating, "no se castiga con puntos");
  assert.ok(despues.desviacion > antes.desviacion);
  assert.ok(despues.confianza < antes.confianza);
  assert.ok(confianzaDe(despues.desviacion) === despues.confianza);
});

// ------------------------------------------------------------ auditoría

test("cada movimiento deja su transacción, con el porqué", () => {
  const e = procesar([partido()], { ratingsIniciales: CUATRO });

  assert.equal(e.transacciones.length, 4, "una por jugador");
  const suya = e.transacciones.find((t) => t.jugadorId === "nacho")!;

  assert.equal(suya.partidoId, "p1");
  assert.equal(suya.ratingAntes, 1525);
  assert.equal(suya.ratingDespues, suya.ratingAntes + suya.delta);
  assert.equal(suya.probabilidadEsperada, 0.5);
  assert.equal(suya.ratingRivales, 1525);
  assert.equal(suya.resultado, 1);
  assert.equal(suya.version, VERSION_ALGORITMO);
});

test("el mismo partido no puntúa dos veces", () => {
  const dosVeces = [partido({ id: "p1" }), partido({ id: "p1" })];
  const e = procesar(dosVeces, { ratingsIniciales: CUATRO });

  assert.equal(e.transacciones.length, 4);
  assert.deepEqual(e.ignorados, [{ partidoId: "p1", motivo: "repetido" }]);
});

test("reprocesar el historial entero da exactamente lo mismo", () => {
  const historial = [
    partido({ id: "p1", marcadorA: 6, marcadorB: 3 }),
    partido({ id: "p2", fecha: "2026-08-16", a: ["nacho", "santi"], b: ["juan", "tincho"], marcadorA: 4, marcadorB: 6 }),
  ];

  const uno = procesar(historial, { ratingsIniciales: CUATRO });
  const dos = procesar(historial, { ratingsIniciales: CUATRO });

  for (const id of ["nacho", "juan", "santi", "tincho"]) {
    assert.equal(ratingDe(uno, id), ratingDe(dos, id));
  }
});

test("un partido sin puntuar se ignora y se dice por qué", () => {
  const e = procesar([partido({ origen: "sin_puntuar" })], {
    ratingsIniciales: CUATRO,
  });

  assert.equal(e.transacciones.length, 0);
  assert.deepEqual(e.ignorados, [{ partidoId: "p1", motivo: "sin_puntuar" }]);
});

test("un resultado confirmado por los jugadores pesa menos que uno del marcador", () => {
  const delMarcador = procesar([partido({ origen: "marcador" })], {
    ratingsIniciales: CUATRO,
  });
  const confirmado = procesar([partido({ origen: "confirmado" })], {
    ratingsIniciales: CUATRO,
  });

  assert.ok(ratingDe(delMarcador, "nacho") > ratingDe(confirmado, "nacho"));
});

// ------------------------------------------------------------ divisiones

test("no se asciende por cruzar el umbral una vez", () => {
  // Sube de golpe por encima de 1600 ganándole a gente mucho mejor.
  const e = procesar(
    [partido({ marcadorA: 6, marcadorB: 0 })],
    {
      ratingsIniciales: new Map([
        ["nacho", 1595],
        ["juan", 1595],
        ["santi", 1900],
        ["tincho", 1900],
      ]),
    },
  );

  assert.ok(ratingDe(e, "nacho") > 1600, "el rating sí cruzó");
  assert.equal(e.divisiones.get("nacho")!.division, "4ª", "la división todavía no");
  assert.deepEqual(e.historialDeDivision, []);
});

test("se asciende tras sostener el umbral, y queda registrado", () => {
  const historial = Array.from({ length: 8 }, (_, i) =>
    partido({
      id: `p${i}`,
      fecha: `2026-08-${String(i + 1).padStart(2, "0")}`,
      marcadorA: 6,
      marcadorB: 0,
    }),
  );
  const e = procesar(historial, {
    ratingsIniciales: new Map([
      ["nacho", 1590],
      ["juan", 1590],
      ["santi", 1900],
      ["tincho", 1900],
    ]),
  });

  assert.equal(e.divisiones.get("nacho")!.division, "3ª");

  const ascenso = ultimoCambioDeDivision(e, "nacho")!;
  assert.equal(ascenso.tipo, "ascenso");
  assert.equal(ascenso.anterior, "4ª");
  assert.equal(ascenso.nueva, "3ª");
  assert.ok(ascenso.ratingAlCambiar >= 1600);
});

// -------------------------------------------------------------- historial

test("el historial de rating sirve para pintar el gráfico", () => {
  const historial = [
    partido({ id: "p1", fecha: "2026-08-01" }),
    partido({ id: "p2", fecha: "2026-08-08" }),
  ];
  const e = procesar(historial, { ratingsIniciales: CUATRO });
  const puntos = historialDeRating(e, "nacho");

  assert.equal(puntos.length, 2);
  assert.deepEqual(puntos.map((p) => p.fecha), ["2026-08-01", "2026-08-08"]);
  assert.equal(puntos[1].rating, ratingDe(e, "nacho"));
});

test("el resumen da el máximo histórico y el cambio del periodo", () => {
  const e = procesar(
    [
      partido({ id: "p1", fecha: "2026-06-01", marcadorA: 6, marcadorB: 0 }),
      partido({ id: "p2", fecha: "2026-08-01", marcadorA: 0, marcadorB: 6 }),
      partido({ id: "p3", fecha: "2026-08-20", marcadorA: 6, marcadorB: 2 }),
    ],
    { ratingsIniciales: CUATRO },
  );

  const resumen = resumenDeRating(e, "nacho", "2026-07-01")!;
  assert.ok(resumen.maximo >= resumen.actual);
  assert.ok(resumen.minimo <= resumen.actual);

  // El cambio de la ventana ignora el partido de junio.
  const ultimos = e.transacciones
    .filter((t) => t.jugadorId === "nacho" && t.fecha >= "2026-07-01")
    .reduce((total, t) => total + t.delta, 0);
  assert.ok(Math.abs(resumen.cambio - ultimos) < 1e-9);
});

test("quien no ha jugado no tiene resumen, y eso no es un cero", () => {
  const e = procesar([], {});
  assert.equal(resumenDeRating(e, "fantasma"), null);
});

// ------------------------------------------------------ división de partida

test("la división declarada al registrarse fija el rating de partida", () => {
  assert.equal(ratingInicialDe(ESCALA_UY, "4ª"), 1525);
  assert.equal(ratingInicialDe(ESCALA_UY, "1ª"), 1975);
  assert.equal(ratingInicialDe(ESCALA_UY, "8ª"), 950);
});

test("quien dice «no sé» empieza en el centro de la escala", () => {
  const desconocido = ratingInicialDe(ESCALA_UY, null);
  assert.ok(desconocido > 1300 && desconocido < 1450);
});

test("quien no declara división empieza en el centro, no en el suelo", () => {
  const e = procesar([partido()], {});
  const suyo = e.ratings.get("nacho")!;

  // Dar por hecho que alguien es de la última división es peor que admitir que
  // no se sabe: arrancaría en 950 y tardaría media temporada en salir de ahí.
  assert.ok(suyo.rating > 1300, `arrancó en ${suyo.rating.toFixed(0)}`);
  assert.equal(e.divisiones.get("nacho")!.division, "5ª");
});
