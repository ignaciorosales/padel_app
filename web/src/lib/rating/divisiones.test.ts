import test from "node:test";
import assert from "node:assert/strict";
import {
  divisionDe,
  ESCALA_UY,
  estadoInicial,
  evaluarDivision,
  progresoDeDivision,
  REGLAS,
  ratingInicialDe,
  type EscalaDeDivisiones,
} from "./divisiones.ts";

/** Aplica una serie de ratings seguidos y devuelve dónde acaba. */
function recorrer(ratings: number[], desde = 1525) {
  let estado = estadoInicial(ESCALA_UY, desde);
  const cambios = [];
  for (const rating of ratings) {
    const paso = evaluarDivision(estado, rating);
    estado = paso.estado;
    if (paso.cambio) cambios.push(paso.cambio);
  }
  return { estado, cambios };
}

// ------------------------------------------------------------- la escala

test("cada rating cae en su división", () => {
  assert.equal(divisionDe(ESCALA_UY, 1672).nombre, "3ª");
  assert.equal(divisionDe(ESCALA_UY, 1600).nombre, "3ª", "el suelo entra");
  assert.equal(divisionDe(ESCALA_UY, 1599).nombre, "4ª");
});

test("las dos puntas no se salen de la escala", () => {
  assert.equal(divisionDe(ESCALA_UY, 400).nombre, "8ª");
  assert.equal(divisionDe(ESCALA_UY, 9000).nombre, "1ª");
});

test("el rating de partida es el centro de la división declarada", () => {
  for (const division of ESCALA_UY.divisiones) {
    assert.equal(ratingInicialDe(ESCALA_UY, division.nombre), division.ratingInicial);
  }
});

// ------------------------------------------------------------ histéresis

test("cruzar el umbral una vez no asciende a nadie", () => {
  const { estado, cambios } = recorrer([1605]);

  assert.equal(estado.division, "4ª");
  assert.equal(estado.partidosEnZonaDeAscenso, 1);
  assert.deepEqual(cambios, []);
});

test("sostener el umbral los partidos que pide la regla sí asciende", () => {
  const sostenido = Array(REGLAS.partidosParaAscender).fill(1605);
  const { estado, cambios } = recorrer(sostenido);

  assert.equal(estado.division, "3ª");
  assert.equal(cambios.length, 1);
  assert.equal(cambios[0].tipo, "ascenso");
});

test("un solo partido por debajo reinicia la cuenta", () => {
  const { estado, cambios } = recorrer([1605, 1605, 1590, 1605, 1605]);

  assert.equal(estado.division, "4ª", "no llegó a encadenar cinco");
  assert.equal(estado.partidosEnZonaDeAscenso, 2);
  assert.deepEqual(cambios, []);
});

test("rozar el límite desde arriba no descabalga a nadie", () => {
  // Un tercera que baja a 1590 sigue por encima de 1600 - 50: no desciende por
  // mucho que se quede ahí. Bajar tiene que costar más que rozar el límite.
  const { estado, cambios } = recorrer(Array(10).fill(1590), 1605);

  assert.equal(estado.division, "3ª");
  assert.equal(estado.partidosEnZonaDeDescenso, 0);
  assert.deepEqual(cambios, []);
});

test("caer del margen y sostenerlo sí desciende", () => {
  let estado = estadoInicial(ESCALA_UY, 1610);
  estado = { ...estado, division: "3ª" };

  const cambios = [];
  for (let i = 0; i < REGLAS.partidosParaDescender; i++) {
    const paso = evaluarDivision(estado, 1540); // por debajo de 1600 - 50
    estado = paso.estado;
    if (paso.cambio) cambios.push(paso.cambio);
  }

  assert.equal(estado.division, "4ª");
  assert.equal(cambios[0].tipo, "descenso");
  assert.equal(cambios[0].anterior, "3ª");
});

test("ir y venir alrededor del límite no cambia de división ni una vez", () => {
  const bailando = [1598, 1603, 1597, 1604, 1599, 1602, 1596, 1605];
  const { estado, cambios } = recorrer(bailando);

  assert.equal(estado.division, "4ª");
  assert.deepEqual(cambios, []);
});

test("de la división más baja no se puede descender", () => {
  let estado = estadoInicial(ESCALA_UY, 900);
  assert.equal(estado.division, "8ª");

  for (let i = 0; i < 20; i++) estado = evaluarDivision(estado, 200).estado;
  assert.equal(estado.division, "8ª");
});

test("de la más alta no se puede ascender", () => {
  let estado = estadoInicial(ESCALA_UY, 1950);
  for (let i = 0; i < 20; i++) estado = evaluarDivision(estado, 2400).estado;
  assert.equal(estado.division, "1ª");
});

test("se sube de una en una, aunque el rating pegue un salto enorme", () => {
  const { estado, cambios } = recorrer(Array(REGLAS.partidosParaAscender).fill(1980));

  assert.equal(estado.division, "3ª", "de 4ª sólo se sube a 3ª");
  assert.equal(cambios.length, 1);
});

// -------------------------------------------------------------- progreso

test("el progreso dice cuánto falta para la siguiente división", () => {
  const p = progresoDeDivision(estadoInicial(ESCALA_UY, 1556), 1556);

  assert.equal(p.division.nombre, "4ª");
  assert.equal(p.siguiente?.nombre, "3ª");
  assert.equal(p.faltan, 44);
  assert.ok(p.fraccion > 0.6 && p.fraccion < 0.8);
  assert.equal(p.enZonaDeAscenso, false);
});

test("en zona de ascenso dice cuántos partidos hay que sostener", () => {
  const estado = { division: "4ª", partidosEnZonaDeAscenso: 2, partidosEnZonaDeDescenso: 0 };
  const p = progresoDeDivision(estado, 1612);

  assert.equal(p.enZonaDeAscenso, true);
  assert.equal(p.faltan, 0);
  assert.equal(p.partidosParaConfirmar, REGLAS.partidosParaAscender - 2);
});

test("en lo más alto no falta nada", () => {
  const p = progresoDeDivision(estadoInicial(ESCALA_UY, 2000), 2000);

  assert.equal(p.division.nombre, "1ª");
  assert.equal(p.siguiente, null);
  assert.equal(p.faltan, 0);
  assert.equal(p.fraccion, 1);
});

test("la división más baja también tiene barra", () => {
  const p = progresoDeDivision(estadoInicial(ESCALA_UY, 940), 940);

  assert.equal(p.division.nombre, "8ª");
  assert.equal(p.faltan, 60);
  assert.ok(p.fraccion > 0 && p.fraccion < 1);
});

// ---------------------------------------------------------- otra escala

test("una escala con otras divisiones y otros rangos funciona igual", () => {
  const espana: EscalaDeDivisiones = {
    id: "es-v1",
    divisiones: [
      { nombre: "5ª", desde: 0, ratingInicial: 1200 },
      { nombre: "4ª", desde: 1400, ratingInicial: 1500 },
      { nombre: "3ª", desde: 1600, ratingInicial: 1700 },
      { nombre: "2ª", desde: 1800, ratingInicial: 1900 },
      { nombre: "1ª", desde: 2000, ratingInicial: 2100 },
    ],
  };

  assert.equal(divisionDe(espana, 1700).nombre, "3ª");
  assert.equal(ratingInicialDe(espana, "3ª"), 1700);

  let estado = estadoInicial(espana, 1500);
  for (let i = 0; i < REGLAS.partidosParaAscender; i++) {
    estado = evaluarDivision(estado, 1650, espana).estado;
  }
  assert.equal(estado.division, "3ª");
});
