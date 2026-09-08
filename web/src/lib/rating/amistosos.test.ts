/**
 * El amistoso y su confirmación.
 *
 * Lo que se prueba aquí es una regla de producto, no una fórmula: **un amistoso
 * no puntúa hasta que los cuatro lo aceptan, y uno que dice que no lo tumba.**
 * Si esto se rompe, el rating se puede inflar escribiendo victorias inventadas
 * desde el móvil, que es la única forma de matar un sistema de rating.
 */

import test from "node:test";
import assert from "node:assert/strict";
import {
  confirmacionesDe,
  necesitaConfirmacion,
  origenDelAmistoso,
  partidosDeLosAmistosos,
  type FilaDeAmistoso,
  type FilaDeRespuesta,
} from "./amistosos.ts";
import { CONFIANZA_POR_ORIGEN, puntua } from "./algoritmo.ts";
import { procesar } from "./motor.ts";
import { paraGuardar } from "./consultas.ts";
import { paraRating } from "../jugador/desde-el-panel.ts";

const amistoso = (p: Partial<FilaDeAmistoso> = {}): FilaDeAmistoso => ({
  id: "f1",
  club_id: "c1",
  fecha: "2026-08-18",
  a1: "nacho",
  a2: "juan",
  b1: "santi",
  b2: "tincho",
  marcador_a: 6,
  marcador_b: 3,
  unidad: "juegos",
  estado: "pendiente",
  origen_confirmado: "confirmado",
  ...p,
});

const respuesta = (
  player_id: string,
  respuesta: string,
  match_id = "f1",
): FilaDeRespuesta => ({ match_id, player_id, respuesta });

// ------------------------------------------------------------- el origen

test("un amistoso pendiente no puntúa", () => {
  assert.equal(origenDelAmistoso("pendiente", "confirmado"), "sin_puntuar");
  assert.equal(puntua(origenDelAmistoso("pendiente", "confirmado")), false);
});

test("uno rechazado tampoco, aunque tenga marcador", () => {
  assert.equal(origenDelAmistoso("rechazado", "confirmado"), "sin_puntuar");
});

test("confirmado por los cuatro puntúa, y vale menos que uno del club", () => {
  assert.equal(origenDelAmistoso("confirmado", "confirmado"), "confirmado");
  assert.equal(origenDelAmistoso("confirmado", "club"), "club");
  assert.equal(
    CONFIANZA_POR_ORIGEN.confirmado < CONFIANZA_POR_ORIGEN.club,
    true,
    "el club no tiene por qué haber jugado, y no gana nada mintiendo",
  );
});

test("un estado o un origen que no se reconoce no puntúa", () => {
  assert.equal(origenDelAmistoso("lo_que_sea", "confirmado"), "sin_puntuar");
  assert.equal(origenDelAmistoso("confirmado", "inventado"), "sin_puntuar");
});

// -------------------------------------------------- de fila a partido

test("un amistoso se convierte en un partido suelto, sin torneo", () => {
  const { partidos, descartes } = partidosDeLosAmistosos([amistoso()]);

  assert.equal(descartes.length, 0);
  assert.equal(partidos.length, 1);
  assert.equal(partidos[0].eventoId, null);
  assert.equal(partidos[0].formato, "amistoso");
  assert.deepEqual(partidos[0].a, ["nacho", "juan"]);
  assert.equal(partidos[0].marcadorA, 6);
});

test("los pendientes también salen: cuentan para cuánto has jugado", () => {
  const { partidos } = partidosDeLosAmistosos([
    amistoso({ id: "f1", estado: "pendiente" }),
    amistoso({ id: "f2", estado: "confirmado" }),
  ]);

  assert.equal(partidos.length, 2);
  assert.equal(partidos[0].origen, "sin_puntuar");
  assert.equal(partidos[1].origen, "confirmado");
});

test("un 0-0 no es un partido", () => {
  const { partidos, descartes } = partidosDeLosAmistosos([
    amistoso({ marcador_a: 0, marcador_b: 0 }),
  ]);

  assert.equal(partidos.length, 0);
  assert.equal(descartes[0].motivo, "sin_juego");
});

test("la misma persona a los dos lados se descarta con su motivo", () => {
  const { partidos, descartes } = partidosDeLosAmistosos([
    amistoso({ b2: "nacho" }),
  ]);

  assert.equal(partidos.length, 0);
  assert.equal(descartes[0].motivo, "jugadores_repetidos");
});

test("una unidad de marcador desconocida no se adivina", () => {
  const { partidos, descartes } = partidosDeLosAmistosos([
    amistoso({ unidad: "tantos" }),
  ]);

  assert.equal(partidos.length, 0);
  assert.equal(descartes[0].motivo, "unidad_desconocida");
});

test("salen ordenados por fecha, que es el orden en que puntúan", () => {
  const { partidos } = partidosDeLosAmistosos([
    amistoso({ id: "f2", fecha: "2026-08-20" }),
    amistoso({ id: "f1", fecha: "2026-08-18" }),
  ]);

  assert.deepEqual(
    partidos.map((p) => p.id),
    ["f1", "f2"],
  );
});

// --------------------------------------------------- quién falta por decir

test("recién cargado, faltan los cuatro", () => {
  const c = confirmacionesDe(amistoso(), []);

  assert.deepEqual(c.faltan, ["nacho", "juan", "santi", "tincho"]);
  assert.equal(c.listo, false);
});

test("con tres aceptaciones sigue sin estar listo", () => {
  const c = confirmacionesDe(amistoso(), [
    respuesta("nacho", "acepta"),
    respuesta("juan", "acepta"),
    respuesta("santi", "acepta"),
  ]);

  assert.deepEqual(c.faltan, ["tincho"]);
  assert.equal(c.listo, false);
});

test("con los cuatro, listo", () => {
  const c = confirmacionesDe(amistoso(), [
    respuesta("nacho", "acepta"),
    respuesta("juan", "acepta"),
    respuesta("santi", "acepta"),
    respuesta("tincho", "acepta"),
  ]);

  assert.equal(c.faltan.length, 0);
  assert.equal(c.listo, true);
});

test("uno que dice que no lo tumba, aunque los otros tres acepten", () => {
  const c = confirmacionesDe(amistoso(), [
    respuesta("nacho", "acepta"),
    respuesta("juan", "acepta"),
    respuesta("santi", "acepta"),
    respuesta("tincho", "rechaza"),
  ]);

  assert.deepEqual(c.rechazan, ["tincho"]);
  assert.equal(c.listo, false);
});

test("no contestar no es lo mismo que decir que no", () => {
  const c = confirmacionesDe(amistoso(), [respuesta("nacho", "acepta")]);

  assert.deepEqual(c.rechazan, []);
  assert.deepEqual(c.faltan, ["juan", "santi", "tincho"]);
});

test("la respuesta de alguien que no jugó no cuenta para nada", () => {
  const c = confirmacionesDe(amistoso(), [
    respuesta("nacho", "acepta"),
    respuesta("juan", "acepta"),
    respuesta("santi", "acepta"),
    respuesta("tincho", "acepta"),
    respuesta("un_desconocido", "rechaza"),
  ]);

  assert.equal(c.listo, true);
  assert.deepEqual(c.rechazan, []);
});

test("las respuestas de otro partido no se mezclan", () => {
  const c = confirmacionesDe(amistoso(), [
    respuesta("nacho", "rechaza", "f9"),
  ]);

  assert.deepEqual(c.rechazan, []);
  assert.deepEqual(c.faltan, ["nacho", "juan", "santi", "tincho"]);
});

test("un amistoso del club no espera a nadie", () => {
  assert.equal(necesitaConfirmacion(amistoso({ origen_confirmado: "club" })), false);
  assert.equal(necesitaConfirmacion(amistoso()), true);
});

// ------------------------------------------- de punta a punta con el motor

test("confirmar es lo que hace que el amistoso mueva el rating", () => {
  const sinConfirmar = partidosDeLosAmistosos([amistoso()]).partidos.map(paraRating);
  const confirmado = partidosDeLosAmistosos([
    amistoso({ estado: "confirmado" }),
  ]).partidos.map(paraRating);

  const antes = procesar(sinConfirmar);
  const despues = procesar(confirmado);

  assert.equal(antes.transacciones.length, 0);
  assert.deepEqual(antes.ignorados, [{ partidoId: "f1", motivo: "sin_puntuar" }]);
  assert.equal(despues.transacciones.length, 4);
});

test("el id de un amistoso va a su columna, no a la de los torneos", () => {
  const partidos = partidosDeLosAmistosos([
    amistoso({ estado: "confirmado" }),
  ]).partidos.map(paraRating);

  const estado = procesar([
    ...partidos,
    {
      id: "m1",
      fecha: "2026-08-19",
      origen: "torneo",
      a: ["nacho", "juan"],
      b: ["santi", "tincho"],
      marcadorA: 6,
      marcadorB: 4,
    },
  ]);

  const payload = paraGuardar(estado, undefined, new Set(["f1"]));

  assert.deepEqual(payload.amistosos, ["f1"]);
  assert.deepEqual(payload.partidos, ["m1"]);

  const delAmistoso = payload.transacciones.filter((t) => t.friendly_match_id === "f1");
  const delTorneo = payload.transacciones.filter((t) => t.match_id === "m1");

  assert.equal(delAmistoso.length, 4);
  assert.equal(delTorneo.length, 4);

  // La restricción de la 0015: exactamente una de las dos columnas puesta.
  for (const t of payload.transacciones) {
    assert.equal(
      (t.match_id === null) !== (t.friendly_match_id === null),
      true,
      "una y sólo una de las dos columnas",
    );
  }
});

test("un amistoso confirmado vale menos que un partido de torneo", () => {
  const cuatro = { a: ["nacho", "juan"], b: ["santi", "tincho"] } as const;

  const deTorneo = procesar([
    { id: "m1", fecha: "2026-08-18", origen: "torneo", ...cuatro, marcadorA: 6, marcadorB: 3 },
  ]);
  const deAmistoso = procesar([
    { id: "f1", fecha: "2026-08-18", origen: "confirmado", ...cuatro, marcadorA: 6, marcadorB: 3 },
  ]);

  const subeEnTorneo = deTorneo.transacciones.find((t) => t.jugadorId === "nacho")!.delta;
  const subeEnAmistoso = deAmistoso.transacciones.find((t) => t.jugadorId === "nacho")!.delta;

  assert.equal(subeEnAmistoso > 0, true);
  assert.equal(subeEnAmistoso < subeEnTorneo, true);
});
