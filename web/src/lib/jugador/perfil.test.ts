/**
 * De la base de datos al perfil, de una pieza.
 *
 * Cada módulo tiene sus tests, pero eso no prueba que encajen: los tipos pueden
 * cuadrar y la cadena entera dar algo absurdo. Esto monta un club pequeño con
 * filas como las que devuelve el panel —incluidos un bye, un partido sin
 * terminar y alguien sin identificar— y comprueba lo que vería el jugador al
 * abrir la app.
 */

import test from "node:test";
import assert from "node:assert/strict";
import {
  identidadesDe,
  partidosDelPanel,
  resumenDeDescartes,
  soloPuntuables,
  type FilaDelPanel,
} from "./desde-el-panel.ts";
import { procesar } from "../rating/motor.ts";
import { esProvisional } from "../rating/algoritmo.ts";
import {
  divisionDe,
  ESCALA_UY,
  progresoDeDivision,
  ratingInicialDe,
} from "../rating/divisiones.ts";
import { porEvento, porMes, resumen } from "../historial/partidos.ts";
import { caraACara, companeros, destacados } from "../historial/gente.ts";

// Cuatro socios del club, con sus filas de inscrito en dos torneos distintos.
const PERSONAS = ["yo", "javi", "tincho", "santi"] as const;

const inscritos = [
  ...PERSONAS.map((p, i) => ({ id: `t1-${i}`, playerId: p })),
  ...PERSONAS.map((p, i) => ({ id: `t2-${i}`, playerId: p })),
  // Un quinto inscrito del segundo torneo que nadie ha unificado todavía.
  { id: "t2-4", playerId: null },
];

const ronda = (
  torneo: string,
  fecha: string,
  numero: number,
  lados: [number, number, number, number],
  marcador: [number, number],
  extra: Partial<FilaDelPanel> = {},
): FilaDelPanel => ({
  id: `${torneo}-r${numero}`,
  torneoId: torneo,
  fecha,
  formato: "americano",
  unidad: "juegos",
  ronda: numero,
  pista: 1,
  a1: `${torneo}-${lados[0]}`,
  a2: `${torneo}-${lados[1]}`,
  b1: `${torneo}-${lados[2]}`,
  b2: `${torneo}-${lados[3]}`,
  juegosA: marcador[0],
  juegosB: marcador[1],
  ...extra,
});

const FILAS: FilaDelPanel[] = [
  // Americano de julio: yo rotando compañero, ganando casi todo.
  ronda("t1", "2026-07-04", 1, [0, 1, 2, 3], [6, 3]),
  ronda("t1", "2026-07-04", 2, [0, 2, 1, 3], [6, 4]),
  ronda("t1", "2026-07-04", 3, [0, 3, 1, 2], [4, 6]),

  // Americano de agosto.
  ronda("t2", "2026-08-15", 1, [0, 1, 2, 3], [6, 2]),
  ronda("t2", "2026-08-15", 2, [0, 2, 1, 3], [3, 6]),
  ronda("t2", "2026-08-15", 3, [0, 3, 1, 2], [6, 5]),

  // Y las tres filas que la app no puede usar.
  ronda("t2", "2026-08-15", 4, [0, 1, 2, 3], [0, 0], {
    id: "t2-sin-jugar",
    juegosA: null,
    juegosB: null,
  }),
  ronda("t2", "2026-08-15", 5, [0, 1, 2, 3], [6, 0], {
    id: "t2-bye",
    b1: null,
    b2: null,
  }),
  ronda("t2", "2026-08-15", 6, [0, 1, 2, 4], [6, 1], { id: "t2-sin-unificar" }),
];

const IDENTIDADES = identidadesDe(inscritos);

test("la cadena entera: de filas del panel al perfil del jugador", () => {
  const { partidos, descartes } = partidosDelPanel(FILAS, IDENTIDADES);

  // --- lo que entra y lo que no ---------------------------------------
  assert.equal(partidos.length, 6, "seis rondas utilizables");
  const cuenta = resumenDeDescartes(descartes);
  assert.equal(cuenta.sin_resultado, 1);
  assert.equal(cuenta.hueco_o_bye, 1);
  assert.equal(cuenta.sin_identificar, 1);

  // --- el récord --------------------------------------------------------
  const mio = resumen("yo", partidos);
  assert.equal(mio.oficial.partidos, 6);
  assert.equal(mio.oficial.ganados, 4);
  assert.equal(mio.oficial.perdidos, 2);
  assert.equal(mio.oficial.racha.tipo, "ganando");
  assert.equal(mio.oficial.racha.largo, 1);

  // --- el historial se agrupa por evento, no por partido ----------------
  const eventos = porEvento("yo", partidos);
  assert.equal(eventos.length, 2, "dos americanos, no seis partidos sueltos");
  assert.equal(eventos[0].eventoId, "t2", "el más reciente primero");
  assert.equal(eventos[0].partidos.length, 3);

  const meses = porMes("yo", partidos);
  assert.deepEqual(meses.map((m) => m.mes), ["2026-08", "2026-07"]);

  // --- con quién y contra quién -----------------------------------------
  // El americano rota compañero, así que los tres han sido compañeros míos.
  assert.deepEqual(
    companeros("yo", partidos).map((c) => c.jugadorId).sort(),
    ["javi", "santi", "tincho"],
  );

  const contraTincho = caraACara("yo", "tincho", partidos);
  assert.equal(contraTincho.contra.partidos + contraTincho.juntos.partidos, 6);

  // Con cuatro partidos por cabeza ya se puede destacar a alguien.
  const suyos = destacados("yo", partidos, 2);
  assert.ok(suyos.mejorCompanero !== null);
  assert.ok(suyos.nemesis !== null);

  // --- el rating --------------------------------------------------------
  const partida = ratingInicialDe(ESCALA_UY, "4ª");
  const semillas = new Map(PERSONAS.map((p) => [p, partida]));
  const estado = procesar(soloPuntuables(partidos), { ratingsIniciales: semillas });

  assert.equal(estado.ratings.size, 4);
  assert.equal(estado.transacciones.length, 24, "cuatro apuntes por partido");

  const yo = estado.ratings.get("yo")!;
  assert.ok(yo.rating > partida, "gané cuatro de seis");
  assert.equal(esProvisional(yo), true, "dos mañanas no asientan un rating");

  // Lo que gana una pareja lo pierde la otra: la red no se infla.
  const suma = [...estado.ratings.values()].reduce((total, r) => total + r.rating, 0);
  assert.ok(Math.abs(suma - 4 * partida) < 1e-9);

  // --- lo que se pinta en el perfil -------------------------------------
  assert.equal(divisionDe(ESCALA_UY, yo.rating).nombre, "4ª");
  const progreso = progresoDeDivision(estado.divisiones.get("yo")!, yo.rating);
  assert.equal(progreso.siguiente?.nombre, "3ª");
  assert.ok(progreso.faltan > 0 && progreso.faltan < 150);
  assert.deepEqual(estado.historialDeDivision, [], "seis partidos no ascienden a nadie");
});

test("mientras nadie unifique, el jugador no tiene historial y se sabe por qué", () => {
  const { partidos, descartes } = partidosDelPanel(FILAS, identidadesDe([]));

  assert.deepEqual(partidos, []);
  assert.equal(resumen("yo", partidos).oficial.partidos, 0);
  // Ocho de las nueve filas caen por falta de identidad; la novena, por el bye,
  // que se descarta antes de mirar quién juega.
  assert.equal(resumenDeDescartes(descartes).sin_identificar, 7);
  assert.equal(descartes.length, FILAS.length);
});
