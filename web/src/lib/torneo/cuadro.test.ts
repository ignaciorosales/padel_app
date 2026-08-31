import test from "node:test";
import assert from "node:assert/strict";
import { describirCuadro, formatearDuracion } from "./cuadro.ts";

test("20 jugadores en 5 pistas: juegan todos, nadie descansa", () => {
  const c = describirCuadro({
    inscritos: 20,
    pistas: 5,
    rondas: 8,
    minutosPorRonda: 20,
    horaInicio: "10:00",
  });

  assert.equal(c.pistasUtiles, 5);
  assert.equal(c.jugadoresPorRonda, 20);
  assert.equal(c.descansanPorRonda, 0);
  assert.deepEqual(c.partidosPorJugador, { min: 8, max: 8 });
  assert.equal(c.horaFin, "12:40");
  assert.equal(formatearDuracion(c.duracionMinutos), "2 h 40 min");
});

test("14 jugadores en 3 pistas: 12 juegan y 2 descansan por ronda", () => {
  // 7 rondas x 12 plazas = 84, que entre 14 jugadores sale exacto: 6 cada uno.
  const exacto = describirCuadro({
    inscritos: 14,
    pistas: 3,
    rondas: 7,
    minutosPorRonda: 20,
  });

  assert.equal(exacto.jugadoresPorRonda, 12);
  assert.equal(exacto.descansanPorRonda, 2);
  assert.deepEqual(exacto.partidosPorJugador, { min: 6, max: 6 });
  assert.ok(exacto.avisos.some((a) => a.texto.includes("Descansan 2 por ronda")));

  // 6 rondas x 12 = 72 entre 14 no es exacto: unos juegan 5 y otros 6.
  const desigual = describirCuadro({
    inscritos: 14,
    pistas: 3,
    rondas: 6,
    minutosPorRonda: 20,
  });

  assert.deepEqual(desigual.partidosPorJugador, { min: 5, max: 6 });
  assert.ok(desigual.avisos.some((a) => a.texto.includes("5 o 6 partidos")));
});

test("avisa cuando sobran pistas", () => {
  const c = describirCuadro({
    inscritos: 9,
    pistas: 4,
    rondas: 5,
    minutosPorRonda: 20,
  });

  assert.equal(c.pistasUtiles, 2);
  assert.ok(c.avisos.some((a) => a.texto.includes("Sobran pistas")));
});

test("avisa cuando repetir compañero es inevitable", () => {
  // 8 jugadores en 2 pistas: todos juegan siempre, así que el tope son 7 rondas.
  const pocas = describirCuadro({ inscritos: 8, pistas: 2, rondas: 7, minutosPorRonda: 20 });
  assert.equal(pocas.maxRondasSinRepetir, 7);
  assert.ok(!pocas.avisos.some((a) => a.texto.includes("repetir compañero")));

  const demasiadas = describirCuadro({ inscritos: 8, pistas: 2, rondas: 9, minutosPorRonda: 20 });
  assert.ok(demasiadas.avisos.some((a) => a.texto.includes("repetir compañero")));
});

test("con descansos caben más rondas antes de repetir", () => {
  // Cada jugador juega menos rondas, así que gasta compañeros más despacio.
  const c = describirCuadro({ inscritos: 24, pistas: 4, rondas: 10, minutosPorRonda: 20 });
  assert.equal(c.jugadoresPorRonda, 16);
  assert.equal(c.maxRondasSinRepetir, Math.floor((24 * 23) / 16));
  assert.ok(c.maxRondasSinRepetir > 10);
});

test("menos de 4 inscritos es un aviso rojo", () => {
  const c = describirCuadro({ inscritos: 3, pistas: 2, rondas: 5, minutosPorRonda: 20 });

  assert.equal(c.pistasUtiles, 0);
  assert.equal(c.jugadoresPorRonda, 0);
  assert.equal(c.maxRondasSinRepetir, 0);
  assert.ok(c.avisos.some((a) => a.tono === "danger"));
});

test("sin hora de inicio no se inventa hora de fin", () => {
  const c = describirCuadro({ inscritos: 8, pistas: 2, rondas: 4, minutosPorRonda: 15 });
  assert.equal(c.horaFin, null);
  assert.equal(c.duracionMinutos, 60);
});

test("la duración se lee en horas y minutos", () => {
  assert.equal(formatearDuracion(45), "45 min");
  assert.equal(formatearDuracion(120), "2 h");
  assert.equal(formatearDuracion(155), "2 h 35 min");
});
