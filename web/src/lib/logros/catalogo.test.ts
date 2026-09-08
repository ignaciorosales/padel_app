/**
 * Los logros.
 *
 * Lo que se prueba aquí no son las cuentas —son sumas— sino la decisión de
 * producto que las ordena: **los logros premian lo que el rating no puede
 * premiar.** Si la mayoría se sacaran ganando, serían un segundo ranking que sólo
 * gana quien ya gana, y el amistoso se quedaría sin ninguna recompensa.
 */

import test from "node:test";
import assert from "node:assert/strict";
import {
  CATALOGO,
  cuentasDe,
  logrosDelPerfil,
  ordenados,
  resumirLogros,
} from "./catalogo.ts";
import { perfilDe, type FilaDeTransaccion } from "../jugador/perfil.ts";
import type { Partido } from "../historial/partidos.ts";

const HOY = "2026-09-08";

const transaccion = (p: Partial<FilaDeTransaccion> = {}): FilaDeTransaccion => ({
  match_id: "m1",
  friendly_match_id: null,
  player_id: "nacho",
  fecha: "2026-09-01",
  rating_antes: 1500,
  rating_despues: 1515,
  delta: 15,
  probabilidad_esperada: 0.5,
  rating_rivales: 1500,
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

/** Un amistoso confirmado: es el que da los logros de palabra. */
const amistoso = (id: string, fecha: string, rivales: [string, string]): Partido => ({
  id,
  eventoId: null,
  fecha,
  origen: "confirmado",
  formato: "amistoso",
  unidad: "juegos",
  a: ["nacho", "juan"],
  b: rivales,
  marcadorA: 6,
  marcadorB: 3,
});

const perfil = (p: { partidos?: Partido[]; transacciones?: FilaDeTransaccion[] } = {}) =>
  perfilDe({
    jugadorId: "nacho",
    rating: null,
    transacciones: p.transacciones ?? [],
    cambios: [],
    partidos: p.partidos ?? [],
    hoy: HOY,
  });

const sacados = (perfilDado: ReturnType<typeof perfil>) =>
  logrosDelPerfil(perfilDado)
    .filter((l) => l.conseguido)
    .map((l) => l.logro.id);

// ------------------------------------------------------ el catálogo en sí

test("el catálogo no tiene ids repetidos", () => {
  const ids = CATALOGO.map((l) => l.id);
  assert.equal(new Set(ids).size, ids.length);
});

test("todos los logros tienen una condición que los evalúa", () => {
  // Un logro sin condición se queda a cero para siempre y nadie se entera.
  const vacio = perfil();
  const evaluados = logrosDelPerfil(vacio);

  assert.equal(evaluados.length, CATALOGO.length);
});

test("la mayoría se saca sin ganar un solo partido", () => {
  // Es la regla que justifica que los logros existan. Si esto se invierte, son
  // otro ranking.
  const sinGanar = CATALOGO.filter((l) => l.familia !== "gesta").length;

  assert.equal(sinGanar > CATALOGO.length / 2, true);
  assert.equal(sinGanar, 12);
  assert.equal(CATALOGO.length, 17);
});

test("no hay ningún logro que se pueda perder", () => {
  // Todos son "llegar a", nunca "mantener". Un logro que se pierde es una amenaza,
  // y el sistema ya tiene un número que baja.
  for (const logro of CATALOGO) {
    assert.equal((logro.meta ?? 1) >= 1, true, logro.id);
  }
});

// ------------------------------------------------------ la ficha vacía

test("una ficha nueva no tiene ningún logro, y los ve todos", () => {
  const evaluados = logrosDelPerfil(perfil());

  assert.deepEqual(sacados(perfil()), []);
  assert.equal(evaluados.length, CATALOGO.length, "se ven todos, no sólo los sacados");
  assert.equal(
    evaluados.every((l) => l.falta > 0),
    true,
  );
});

// ------------------------------------------------------ jugar y aparecer

test("el primer partido da el primer logro, y no hace falta ganarlo", () => {
  const perdido = perfil({ partidos: [partido({ marcadorA: 3, marcadorB: 6 })] });

  assert.equal(sacados(perdido).includes("primer_partido"), true);
});

test("un amistoso sin confirmar cuenta para jugar, no para la palabra dada", () => {
  const conPendiente = perfil({
    partidos: [{ ...amistoso("f1", "2026-09-01", ["santi", "tincho"]), origen: "sin_puntuar" }],
  });

  const suyos = sacados(conPendiente);
  assert.equal(suyos.includes("primer_partido"), true, "jugar es jugar");
  assert.equal(suyos.includes("primer_amistoso"), false, "todavía no lo han confirmado");
});

test("un amistoso confirmado da el logro de la palabra dada", () => {
  const conConfirmado = perfil({
    partidos: [amistoso("f1", "2026-09-01", ["santi", "tincho"])],
  });

  assert.equal(sacados(conConfirmado).includes("primer_amistoso"), true);
});

test("los amistosos confirmados se cuentan uno por uno", () => {
  const partidos = Array.from({ length: 10 }, (_, i) =>
    amistoso(`f${i}`, `2026-0${(i % 9) + 1}-15`, ["santi", "tincho"]),
  );
  const diez = perfil({ partidos });

  assert.equal(sacados(diez).includes("diez_amistosos"), true);
  assert.equal(sacados(diez).includes("cincuenta_amistosos"), false);
});

test("jugar con gente distinta da los logros de club", () => {
  const partidos = Array.from({ length: 5 }, (_, i) =>
    partido({
      id: `m${i}`,
      fecha: `2026-09-0${i + 1}`,
      a: ["nacho", `companero${i}`],
      b: [`rival${i}a`, `rival${i}b`],
    }),
  );
  const variado = perfil({ partidos });

  const suyos = sacados(variado);
  assert.equal(suyos.includes("cinco_companeros"), true, "cinco compañeros distintos");
  assert.equal(suyos.includes("diez_personas"), true, "cinco compañeros + diez rivales");
});

test("jugar siempre con los mismos no da el logro de gente distinta", () => {
  const partidos = Array.from({ length: 20 }, (_, i) =>
    partido({ id: `m${i}`, fecha: `2026-09-${String(i + 1).padStart(2, "0")}` }),
  );
  const monogamo = perfil({ partidos });

  const suyos = sacados(monogamo);
  assert.equal(suyos.includes("diez_partidos"), true);
  assert.equal(suyos.includes("cinco_companeros"), false, "siempre con Juan");
  assert.equal(suyos.includes("diez_personas"), false, "sólo tres personas en total");
});

// ------------------------------------------------------------ las gestas

test("ganar un partido que se daba por perdido es una gesta", () => {
  const gesta = perfil({
    transacciones: [transaccion({ probabilidad_esperada: 0.15, rating_rivales: 1800 })],
  });

  const suyos = sacados(gesta);
  assert.equal(suyos.includes("primera_gesta"), true);
  assert.equal(suyos.includes("matagigantes"), true, "los rivales eran más fuertes");
});

test("ganar lo que tocaba ganar no es una gesta", () => {
  const normal = perfil({
    transacciones: [transaccion({ probabilidad_esperada: 0.8, rating_rivales: 1300 })],
  });

  const suyos = sacados(normal);
  assert.equal(suyos.includes("primera_gesta"), false);
  assert.equal(suyos.includes("matagigantes"), false);
});

test("perder contra alguien fuerte no da nada, tampoco quita nada", () => {
  const derrota = perfil({
    transacciones: [
      transaccion({ resultado: 0, probabilidad_esperada: 0.1, rating_rivales: 1900, delta: -5 }),
    ],
  });

  assert.equal(sacados(derrota).includes("primera_gesta"), false);
  assert.equal(sacados(derrota).includes("matagigantes"), false);
});

test("las gestas se cuentan sobre todas las transacciones, no sobre las cinco que se enseñan", () => {
  // `mejoresVictorias` está recortada a cinco para pintar. Contar sobre ella daría
  // un máximo de cinco y un logro de seis nunca se sacaría.
  const muchas = Array.from({ length: 8 }, (_, i) =>
    transaccion({
      match_id: `m${i}`,
      fecha: `2026-09-0${i + 1}`,
      probabilidad_esperada: 0.1,
      rating_rivales: 1900,
    }),
  );
  const conMuchas = perfil({ transacciones: muchas });

  assert.equal(conMuchas.mejoresVictorias.length, 5);
  assert.equal(conMuchas.gestas, 8);
});

test("matagigantes compara con el rating que tenía entonces, no con el de hoy", () => {
  // Si comparara con el de hoy, subir de rating le borraría gestas del pasado.
  const antigua = perfil({
    transacciones: [
      transaccion({ rating_antes: 1400, rating_despues: 1450, rating_rivales: 1500 }),
      transaccion({
        match_id: "m2",
        fecha: "2026-09-05",
        rating_antes: 1450,
        rating_despues: 1900,
        delta: 450,
        rating_rivales: 1500,
      }),
    ],
  });

  assert.equal(antigua.victoriasContraMasFuertes, 2, "las dos fueron contra 1500");
  assert.equal(sacados(antigua).includes("matagigantes"), true);
});

// ------------------------------------------------------------- el orden

test("los conseguidos van primero y entre los que faltan, los más cerca", () => {
  const algo = perfil({
    partidos: Array.from({ length: 9 }, (_, i) =>
      partido({ id: `m${i}`, fecha: `2026-09-0${i + 1}` }),
    ),
  });

  const lista = ordenados(logrosDelPerfil(algo));
  const primerPendiente = lista.findIndex((l) => !l.conseguido);

  assert.equal(
    lista.slice(0, primerPendiente).every((l) => l.conseguido),
    true,
    "no hay ningún conseguido después del primer pendiente",
  );

  // Nueve de diez partidos: "Habitual" es el más cerca y va primero de los que faltan.
  assert.equal(lista[primerPendiente].logro.id, "diez_partidos");
  assert.equal(lista[primerPendiente].falta, 1);
});

// ------------------------------------------------------------ el resumen

test("el resumen cuenta por familia y dice cuál es el siguiente", () => {
  const algo = perfil({
    partidos: Array.from({ length: 9 }, (_, i) =>
      partido({ id: `m${i}`, fecha: `2026-09-0${i + 1}` }),
    ),
  });

  const resumen = resumirLogros(logrosDelPerfil(algo));

  assert.equal(resumen.total, CATALOGO.length);
  assert.equal(resumen.conseguidos >= 1, true);
  assert.equal(resumen.porFamilia.honestidad.conseguidos, 0, "no ha confirmado amistosos");
  assert.equal(resumen.porFamilia.constancia.total, 6);
  assert.equal(resumen.siguiente?.logro.id, "diez_partidos");
});

test("con todo sacado, no hay siguiente", () => {
  const todos = logrosDelPerfil(perfil()).map((l) => ({
    ...l,
    conseguido: true,
    falta: 0,
    fraccion: 1,
  }));

  assert.equal(resumirLogros(todos).siguiente, null);
});

// ----------------------------------------------------------- las cuentas

test("las cuentas leen del perfil y no vuelven a la base de datos", () => {
  const cuentas = cuentasDe(
    perfil({
      partidos: [
        partido(),
        amistoso("f1", "2026-08-15", ["ana", "marta"]),
        { ...amistoso("f2", "2026-07-10", ["ana", "marta"]), origen: "sin_puntuar" },
      ],
    }),
  );

  assert.equal(cuentas.jugados, 3, "los tres cuentan para actividad");
  assert.equal(cuentas.amistososConfirmados, 1, "sólo uno está confirmado");
  assert.equal(cuentas.meses, 3);
  assert.equal(cuentas.companeros, 1, "siempre con Juan");
  assert.equal(cuentas.gente, 5, "Juan, Santi, Tincho, Ana y Marta");
});
