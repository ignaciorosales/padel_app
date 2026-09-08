/**
 * Lo que estos tests protegen no es la mecánica —de eso va `motor.test.ts`—
 * sino tres propiedades del sistema entero que sólo se ven en agregado y que ya
 * fallaron una vez cada una.
 */

import test from "node:test";
import assert from "node:assert/strict";
import {
  crearClub,
  medirTemporada,
  media,
  simularTemporada,
  type JugadorSimulado,
} from "./simulacion.ts";
import { procesar, revisarDivisionDeclarada } from "./motor.ts";
import { divisionDe, ESCALA_UY, ratingInicialDe } from "./divisiones.ts";

/** Sembrar a cada jugador por la división que le tocaría por su fuerza real. */
const sembrar = (jugadores: readonly JugadorSimulado[]) =>
  new Map(
    jugadores.map((j) => [
      j.id,
      ratingInicialDe(ESCALA_UY, divisionDe(ESCALA_UY, j.fuerza).nombre),
    ]),
  );

const CLUB = { rondas: 8, pistas: 6 } as const;
const club = crearClub("c", 4, 6, 1525, 150);

test("tras unas cuantas mañanas, la tabla ordena a la gente como es", () => {
  const m = medirTemporada({ jugadores: club, torneos: 4, ...CLUB }, sembrar(club));
  assert.ok(m.orden > 0.9, `correlación de orden ${m.orden.toFixed(3)}`);
});

test("con la división declarada, la escala se conserva desde el primer torneo", () => {
  const m = medirTemporada({ jugadores: club, torneos: 1, ...CLUB }, sembrar(club));

  assert.ok(Math.abs(m.compresion - 1) < 0.15, `escala ${m.compresion.toFixed(3)}`);
  assert.ok(m.orden > 0.9);
});

test("el rating medio de la red no se mueve por mucho que se juegue", () => {
  // Éste es el que cazó la fuga: con el suelo puesto sobre el ajuste en vez de
  // sobre (S − E), la media subía unos dos puntos por torneo y jugador, hasta
  // ascender a todo el club sin que nadie jugara mejor.
  const semillas = sembrar(club);
  const partida = media([...semillas.values()]);

  for (const torneos of [1, 8, 30]) {
    const m = medirTemporada({ jugadores: club, torneos, ...CLUB }, semillas);
    assert.ok(
      Math.abs(m.nivelMedio - partida) < 0.001,
      `con ${torneos} torneos la media es ${m.nivelMedio.toFixed(2)}, no ${partida}`,
    );
  }
});

test("dos clubes que nunca se cruzan sólo son comparables si están sembrados", () => {
  const flojo = crearClub("f", 4, 6, 1525, 150);
  const fuerte = crearClub("g", 4, 6, 1825, 150);
  const separacionReal = 300;

  const jugar = (
    jugadores: JugadorSimulado[],
    semillas?: ReadonlyMap<string, number>,
  ) => {
    const { ratings } = procesar(
      simularTemporada({ jugadores, torneos: 10, ...CLUB, semilla: 7 }),
      { ratingsIniciales: semillas },
    );
    return media([...ratings.values()].map((r) => r.rating));
  };

  // Sin sembrar, los dos clubes acaban en el mismo sitio: un ranking conjunto
  // diría que son iguales, y es mentira.
  const sinSemilla = jugar(fuerte) - jugar(flojo);
  assert.ok(Math.abs(sinSemilla) < 1, `separación estimada ${sinSemilla.toFixed(1)}`);

  // Sembrando por división, la distancia real sobrevive.
  const conSemilla = jugar(fuerte, sembrar(fuerte)) - jugar(flojo, sembrar(flojo));
  assert.ok(
    conSemilla > separacionReal * 0.8,
    `separación estimada ${conSemilla.toFixed(1)} de ${separacionReal} reales`,
  );
});

test("quien declara mal su división se corrige, aunque le lleve tiempo", () => {
  // Un 2ª que se anota como 6ª. Con el resultado por margen esto tardaba
  // doscientos cuarenta partidos en moverse ciento cincuenta puntos; mandando
  // ganar o perder, el recorrido es de verdad.
  const impostor: JugadorSimulado = { id: "impostor", fuerza: 1825 };
  const jugadores = [...crearClub("c", 4, 6, 1525, 150).slice(0, 23), impostor];
  const semillas = sembrar(jugadores);
  const partida = ratingInicialDe(ESCALA_UY, "6ª");
  semillas.set("impostor", partida);

  const { ratings, historialDeDivision } = procesar(
    simularTemporada({ jugadores, torneos: 8, ...CLUB }),
    { ratingsIniciales: semillas },
  );
  const suyo = ratings.get("impostor")!;

  assert.ok(
    suyo.rating > partida + 300,
    `de ${partida} a ${suyo.rating.toFixed(0)} en 64 partidos`,
  );
  assert.ok(
    historialDeDivision.some((c) => c.jugadorId === "impostor" && c.tipo === "ascenso"),
    "debería haber subido de división por el camino",
  );
});

test("la histéresis evita que el club entero cambie de división cada sábado", () => {
  const { historialDeDivision } = procesar(
    simularTemporada({ jugadores: club, torneos: 8, ...CLUB }),
    { ratingsIniciales: sembrar(club) },
  );

  // Con 24 jugadores y ocho torneos, unos pocos ascensos son sanos; decenas
  // serían el sistema bailando.
  assert.ok(
    historialDeDivision.length < club.length,
    `${historialDeDivision.length} cambios de división en ocho torneos`,
  );
});

test("a quien declara mal su división se le detecta en dos torneos", () => {
  const impostor: JugadorSimulado = { id: "impostor", fuerza: 1825 };
  const jugadores = [...crearClub("c", 4, 6, 1525, 150).slice(0, 23), impostor];
  const semillas = sembrar(jugadores);
  semillas.set("impostor", ratingInicialDe(ESCALA_UY, "6ª"));

  const estado = procesar(simularTemporada({ jugadores, torneos: 2, ...CLUB }), {
    ratingsIniciales: semillas,
  });
  const revisiones = revisarDivisionDeclarada(estado);

  assert.equal(revisiones[0].jugadorId, "impostor", "debería ser el más sospechoso");
  assert.equal(revisiones[0].veredicto, "parece_mas_fuerte");
});

test("y a quien está bien declarado no se le molesta", () => {
  const estado = procesar(simularTemporada({ jugadores: club, torneos: 4, ...CLUB }), {
    ratingsIniciales: sembrar(club),
  });

  const marcados = revisarDivisionDeclarada(estado).filter((r) => r.veredicto !== "encaja");
  assert.deepEqual(marcados, []);
});
