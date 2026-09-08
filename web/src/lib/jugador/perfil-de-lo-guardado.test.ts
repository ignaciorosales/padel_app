/**
 * El perfil montado de lo que hay en la base de datos.
 *
 * El otro test de perfil (`perfil.test.ts`) monta un club entero y comprueba que
 * la cadena encaja de punta a punta. Éste prueba lo contrario: que la capa que
 * **lee** lo guardado aguanta lo que se va a encontrar de verdad — una persona
 * sin ninguna transacción, un rating por encima del umbral que todavía no ha
 * ascendido, y el orden en que se cuentan las cosas.
 */

import test from "node:test";
import assert from "node:assert/strict";
import {
  comoSeDice,
  despuesDelPartido,
  perfilDe,
  VENTANAS,
  type FilaDeCambioDeDivision,
  type FilaDeRating,
  type FilaDeTransaccion,
} from "./perfil.ts";
import { RATING_DESCONOCIDO } from "../rating/divisiones.ts";
import { OPCIONES } from "../rating/algoritmo.ts";
import type { Partido } from "../historial/partidos.ts";

const HOY = "2026-09-08";

const rating = (p: Partial<FilaDeRating> = {}): FilaDeRating => ({
  player_id: "nacho",
  rating: 1612.4,
  desviacion: 120,
  confianza: 0.62,
  partidos_puntuados: 28,
  ultimo_partido: "2026-09-01",
  escala: "uy-v1",
  division: "3ª",
  partidos_en_zona_de_ascenso: 0,
  partidos_en_zona_de_descenso: 0,
  ...p,
});

const transaccion = (p: Partial<FilaDeTransaccion> = {}): FilaDeTransaccion => ({
  match_id: "m1",
  friendly_match_id: null,
  player_id: "nacho",
  fecha: "2026-09-01",
  rating_antes: 1600,
  rating_despues: 1612.4,
  delta: 12.4,
  probabilidad_esperada: 0.5,
  rating_rivales: 1600,
  resultado: 1,
  ...p,
});

const partido = (p: Partial<Partido> = {}): Partido => ({
  id: "m1",
  eventoId: "t1",
  fecha: "2026-09-01",
  origen: "torneo",
  formato: "americano",
  unidad: "juegos",
  a: ["nacho", "juan"],
  b: ["santi", "tincho"],
  marcadorA: 6,
  marcadorB: 4,
  ...p,
});

const base = {
  jugadorId: "nacho",
  rating: null,
  transacciones: [] as FilaDeTransaccion[],
  cambios: [] as FilaDeCambioDeDivision[],
  partidos: [] as Partido[],
  hoy: HOY,
};

// ----------------------------------------------------- la persona sin nada

test("una persona sin rating y sin partidos tiene perfil, no un hueco", () => {
  const perfil = perfilDe({ ...base });

  assert.equal(perfil.rating, RATING_DESCONOCIDO);
  assert.equal(perfil.provisional, true);
  assert.equal(perfil.partidosPuntuados, 0);
  assert.equal(perfil.confianza, 0);
  assert.deepEqual(perfil.evolucion, []);
  assert.equal(perfil.pico, null);
  assert.equal(perfil.ultimoCambio, null);
});

test("sin fila guardada, la división es la que le toca por ese rating", () => {
  const perfil = perfilDe({ ...base });

  // 1375 es el centro de la escala, que es 5ª. Antes esto decía "8ª" mientras el
  // rating decía 1375: dos respuestas para la misma pregunta.
  assert.equal(perfil.division, "5ª");
  assert.equal(perfil.progreso.division.nombre, "5ª");
});

// ------------------------------------------------------------ la división

test("la división guardada manda sobre la que tocaría por rating", () => {
  // 1755 cae en 2ª, pero le faltan partidos por sostener: sigue siendo tercera, y
  // el perfil tiene que decirlo así o la barra de progreso miente.
  const perfil = perfilDe({
    ...base,
    rating: rating({ rating: 1755, division: "3ª", partidos_en_zona_de_ascenso: 2 }),
  });

  assert.equal(perfil.division, "3ª");
  assert.equal(perfil.progreso.enZonaDeAscenso, true);
  assert.equal(perfil.progreso.partidosParaConfirmar, 3);
});

test("la barra dice cuánto falta para la siguiente", () => {
  const perfil = perfilDe({ ...base, rating: rating({ rating: 1656 }) });

  assert.equal(perfil.progreso.siguiente?.nombre, "2ª");
  assert.equal(perfil.progreso.faltan, 1750 - 1656);
  assert.equal(perfil.progreso.fraccion > 0 && perfil.progreso.fraccion < 1, true);
});

test("el último cambio de división es el más reciente, no el primero", () => {
  const perfil = perfilDe({
    ...base,
    rating: rating(),
    cambios: [
      {
        player_id: "nacho",
        fecha: "2026-03-10",
        anterior: "5ª",
        nueva: "4ª",
        tipo: "ascenso",
        rating_al_cambiar: 1455,
      },
      {
        player_id: "nacho",
        fecha: "2026-07-02",
        anterior: "4ª",
        nueva: "3ª",
        tipo: "ascenso",
        rating_al_cambiar: 1605,
      },
      // De otra persona: no cuenta.
      {
        player_id: "juan",
        fecha: "2026-08-30",
        anterior: "6ª",
        nueva: "5ª",
        tipo: "ascenso",
        rating_al_cambiar: 1305,
      },
    ],
  });

  assert.equal(perfil.cambiosDeDivision.length, 2);
  assert.equal(perfil.ultimoCambio?.fecha, "2026-07-02");
  assert.equal(perfil.ultimoCambio?.nueva, "3ª");
});

// --------------------------------------------------------------- el techo

test("el techo incluye el punto de partida, no sólo los 'después'", () => {
  // Empezó en 1700 y no ha hecho más que bajar: su techo es 1700.
  const perfil = perfilDe({
    ...base,
    rating: rating({ rating: 1650 }),
    transacciones: [
      transaccion({ rating_antes: 1700, rating_despues: 1675, delta: -25, resultado: 0 }),
      transaccion({
        match_id: "m2",
        fecha: "2026-09-02",
        rating_antes: 1675,
        rating_despues: 1650,
        delta: -25,
        resultado: 0,
      }),
    ],
  });

  assert.equal(perfil.pico?.rating, 1700);
});

test("el techo es el máximo aunque esté en medio del recorrido", () => {
  const perfil = perfilDe({
    ...base,
    rating: rating({ rating: 1600 }),
    transacciones: [
      transaccion({ rating_antes: 1500, rating_despues: 1700, delta: 200 }),
      transaccion({
        match_id: "m2",
        fecha: "2026-09-02",
        rating_antes: 1700,
        rating_despues: 1600,
        delta: -100,
        resultado: 0,
      }),
    ],
  });

  assert.equal(perfil.pico?.rating, 1700);
  assert.equal(perfil.pico?.fecha, "2026-09-01");
});

// ----------------------------------------------------------- el movimiento

test("las tres ventanas son 7, 30 y 90 días", () => {
  const perfil = perfilDe({ ...base, rating: rating() });

  assert.deepEqual(
    perfil.movimientos.map((m) => m.dias),
    VENTANAS,
  );
});

test("cada ventana suma sólo los deltas que caen dentro", () => {
  const perfil = perfilDe({
    ...base,
    rating: rating(),
    transacciones: [
      // Hace tres días: entra en las tres ventanas.
      transaccion({ match_id: "reciente", fecha: "2026-09-05", delta: 10 }),
      // Hace veinte días: entra en 30 y 90, no en 7.
      transaccion({ match_id: "medio", fecha: "2026-08-19", delta: 5 }),
      // Hace cinco meses: sólo en ninguna.
      transaccion({ match_id: "viejo", fecha: "2026-04-01", delta: 100 }),
    ],
  });

  const [siete, treinta, noventa] = perfil.movimientos;
  assert.equal(siete.cambio, 10);
  assert.equal(siete.partidos, 1);
  assert.equal(treinta.cambio, 15);
  assert.equal(treinta.partidos, 2);
  assert.equal(noventa.cambio, 15);
  assert.equal(noventa.partidos, 2);
});

test("una ventana puede salir negativa, y se dice tal cual", () => {
  const perfil = perfilDe({
    ...base,
    rating: rating(),
    transacciones: [transaccion({ fecha: "2026-09-05", delta: -18, resultado: 0 })],
  });

  assert.equal(perfil.movimientos[0].cambio, -18);
});

// ---------------------------------------------------------- las victorias

test("las mejores victorias se ordenan por la fuerza de los rivales", () => {
  const perfil = perfilDe({
    ...base,
    rating: rating(),
    transacciones: [
      transaccion({ match_id: "floja", rating_rivales: 1400, delta: 30 }),
      transaccion({ match_id: "gesta", rating_rivales: 1820, delta: 20 }),
      transaccion({ match_id: "media", rating_rivales: 1600, delta: 25 }),
      // Una derrota no es una victoria, por mucho que el rival fuera fuerte.
      transaccion({ match_id: "perdida", rating_rivales: 1900, resultado: 0, delta: -8 }),
    ],
  });

  assert.deepEqual(
    perfil.mejoresVictorias.map((v) => v.partidoId),
    ["gesta", "media", "floja"],
  );
});

test("un amistoso confirmado también cuenta como victoria, con su id", () => {
  const perfil = perfilDe({
    ...base,
    rating: rating(),
    transacciones: [
      transaccion({
        match_id: null,
        friendly_match_id: "f1",
        rating_rivales: 1700,
      }),
    ],
  });

  assert.equal(perfil.mejoresVictorias[0].partidoId, "f1");
  assert.equal(perfil.evolucion[0].partidoId, "f1");
});

// ---------------------------------------------------------- la evolución

test("la evolución va en el orden en que se jugó", () => {
  const perfil = perfilDe({
    ...base,
    rating: rating(),
    transacciones: [
      transaccion({ match_id: "m3", fecha: "2026-09-03", rating_despues: 1630 }),
      transaccion({ match_id: "m1", fecha: "2026-09-01", rating_despues: 1612.4 }),
      transaccion({ match_id: "m2", fecha: "2026-09-02", rating_despues: 1620 }),
    ],
  });

  assert.deepEqual(
    perfil.evolucion.map((p) => p.partidoId),
    ["m1", "m2", "m3"],
  );
});

test("las transacciones de otra persona no entran en el perfil de ésta", () => {
  const perfil = perfilDe({
    ...base,
    rating: rating(),
    transacciones: [transaccion(), transaccion({ player_id: "juan", match_id: "m9" })],
  });

  assert.equal(perfil.evolucion.length, 1);
});

// -------------------------------------------------------- lo provisional

test("por debajo del umbral el perfil dice que es provisional", () => {
  const casi = perfilDe({
    ...base,
    rating: rating({ partidos_puntuados: OPCIONES.partidosProvisionales - 1 }),
  });
  const ya = perfilDe({
    ...base,
    rating: rating({ partidos_puntuados: OPCIONES.partidosProvisionales }),
  });

  assert.equal(casi.provisional, true);
  assert.equal(ya.provisional, false);
});

// ------------------------------------------------------- lo que se enseña

test("el rating se enseña redondeado, no como se guarda", () => {
  const perfil = perfilDe({ ...base, rating: rating({ rating: 1546.8231 }) });

  assert.equal(perfil.rating, 1547);
  assert.equal(comoSeDice(1546.4), 1546);
});

test("el historial y la gente salen del perfil, ya calculados", () => {
  const perfil = perfilDe({
    ...base,
    rating: rating(),
    partidos: [
      partido(),
      partido({ id: "m2", fecha: "2026-09-02", marcadorA: 3, marcadorB: 6 }),
    ],
  });

  assert.equal(perfil.resumen.oficial.partidos, 2);
  assert.equal(perfil.resumen.oficial.ganados, 1);
  assert.equal(perfil.resumen.oficial.perdidos, 1);
  assert.equal(perfil.resumen.actividad.partidos, 2);
  assert.equal(perfil.eventos.length, 1, "los dos son del mismo torneo");
  assert.equal(perfil.meses.length, 1);
  assert.equal(perfil.companeros.length, 1, "sólo ha jugado con Juan");
  assert.equal(perfil.rivales.length, 2);
  // Con dos partidos nadie llega al mínimo para destacar, y eso está bien.
  assert.equal(perfil.destacados.mejorCompanero, null);
});

// --------------------------------------------- la pantalla del después

test("después del partido se ve el antes y el después de los cuatro", () => {
  const transacciones: FilaDeTransaccion[] = [
    transaccion({ player_id: "nacho", rating_antes: 1532, rating_despues: 1547, delta: 15 }),
    transaccion({ player_id: "juan", rating_antes: 1490, rating_despues: 1505, delta: 15 }),
    transaccion({
      player_id: "santi",
      rating_antes: 1600,
      rating_despues: 1585,
      delta: -15,
      resultado: 0,
    }),
    transaccion({
      player_id: "tincho",
      rating_antes: 1550,
      rating_despues: 1535,
      delta: -15,
      resultado: 0,
    }),
  ];

  const despues = despuesDelPartido("m1", transacciones)!;

  assert.equal(despues.movidas.length, 4);
  // Ganadores primero.
  assert.deepEqual(
    despues.movidas.slice(0, 2).map((m) => m.gano),
    [true, true],
  );
  const nacho = despues.movidas.find((m) => m.jugadorId === "nacho")!;
  assert.equal(nacho.antes, 1532);
  assert.equal(nacho.despues, 1547);
});

test("una sorpresa se reconoce por la probabilidad que se le daba al ganador", () => {
  const despues = despuesDelPartido("m1", [
    transaccion({ probabilidad_esperada: 0.18 }),
    transaccion({ player_id: "santi", resultado: 0, probabilidad_esperada: 0.82, delta: -20 }),
  ])!;

  assert.equal(despues.probabilidadDelGanador, 0.18);
});

test("un partido que no puntuó no tiene pantalla del después", () => {
  assert.equal(despuesDelPartido("m9", [transaccion()]), null);
});

test("la pantalla del después vale igual para un amistoso", () => {
  const despues = despuesDelPartido("f1", [
    transaccion({ match_id: null, friendly_match_id: "f1" }),
  ])!;

  assert.equal(despues.partidoId, "f1");
  assert.equal(despues.movidas.length, 1);
});
