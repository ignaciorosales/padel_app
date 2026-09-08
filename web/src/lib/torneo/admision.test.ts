/**
 * Quién entra en un torneo restringido.
 *
 * Las dos reglas que se prueban aquí son de producto y las dos van en la misma
 * dirección: **no saber no es motivo para dejar fuera a nadie.** Si se rompen, un
 * torneo de cuarta se queda sin la mitad de los inscritos el primer sábado, y el
 * club deja de usar la función.
 */

import test from "node:test";
import assert from "node:assert/strict";
import {
  admision,
  describirRestriccion,
  listar,
  recontar,
  restringe,
  restriccionDeLaFila,
  SIN_RESTRICCION,
  type Candidato,
  type Restriccion,
} from "./admision.ts";
import { OPCIONES, type RatingJugador } from "../rating/algoritmo.ts";

const ASENTADO = OPCIONES.partidosProvisionales + 5;

const ratingDe = (valor: number, partidos = ASENTADO): RatingJugador => ({
  jugadorId: "nacho",
  rating: valor,
  desviacion: 90,
  confianza: 0.7,
  partidosPuntuados: partidos,
  ultimoPartido: "2026-09-01",
});

const candidato = (p: Partial<Candidato> = {}): Candidato => ({
  rating: ratingDe(1520),
  division: "4ª",
  excepcionAprobada: false,
  ...p,
});

const DE_CUARTA_Y_QUINTA: Restriccion = {
  ratingMinimo: null,
  ratingMaximo: null,
  divisionesAdmitidas: ["4ª", "5ª"],
};

const DE_RANGO: Restriccion = {
  ratingMinimo: 1450,
  ratingMaximo: 1750,
  divisionesAdmitidas: [],
};

// -------------------------------------------------- el torneo sin restricción

test("un torneo abierto no restringe nada, y todos encajan", () => {
  assert.equal(restringe(SIN_RESTRICCION), false);

  const sinFicha = admision(SIN_RESTRICCION, candidato({ rating: null, division: null }));
  assert.equal(sinFicha.veredicto, "encaja");
  assert.equal(sinFicha.motivo, null, "lo que no llama la atención no se explica");
});

// ------------------------------------------------------ no saber no es un no

test("un inscrito sin identificar no queda fuera: queda sin datos", () => {
  const resultado = admision(DE_CUARTA_Y_QUINTA, candidato({ rating: null, division: null }));

  assert.equal(resultado.veredicto, "sin_datos");
  assert.notEqual(resultado.veredicto, "fuera");
  assert.equal(resultado.motivo !== null, true);
});

test("un rating provisional no echa a nadie de un torneo", () => {
  // Su 1975 es el rating de partida de la 1ª que declaró, no su juego. Echarle de
  // un torneo de cuarta por un número que el propio sistema marca como poco fiable
  // es usar el rating contra el jugador.
  const resultado = admision(
    DE_CUARTA_Y_QUINTA,
    candidato({ rating: ratingDe(1975, 3), division: "1ª" }),
  );

  assert.equal(resultado.veredicto, "sin_datos");
  assert.equal(resultado.motivo?.includes("provisional"), true);
});

test("con quince partidos ya se le puede juzgar", () => {
  const resultado = admision(
    DE_CUARTA_Y_QUINTA,
    candidato({
      rating: ratingDe(1975, OPCIONES.partidosProvisionales),
      division: "1ª",
    }),
  );

  assert.equal(resultado.veredicto, "fuera");
});

// --------------------------------------------------------------- el rango

test("por debajo del mínimo queda fuera, y se dice el número", () => {
  const resultado = admision(DE_RANGO, candidato({ rating: ratingDe(1300) }));

  assert.equal(resultado.veredicto, "fuera");
  assert.equal(resultado.motivo?.includes("1300"), true);
  assert.equal(resultado.motivo?.includes("1450"), true);
});

test("por encima del máximo también", () => {
  const resultado = admision(DE_RANGO, candidato({ rating: ratingDe(1900) }));

  assert.equal(resultado.veredicto, "fuera");
  assert.equal(resultado.motivo?.includes("1750"), true);
});

test("dentro del rango encaja", () => {
  assert.equal(admision(DE_RANGO, candidato({ rating: ratingDe(1600) })).veredicto, "encaja");
});

test("los extremos del rango entran: 'de 1450 a 1750' incluye 1450 y 1750", () => {
  assert.equal(admision(DE_RANGO, candidato({ rating: ratingDe(1450) })).veredicto, "encaja");
  assert.equal(admision(DE_RANGO, candidato({ rating: ratingDe(1750) })).veredicto, "encaja");
});

test("el rating se compara sin redondear pero se enseña redondeado", () => {
  const resultado = admision(DE_RANGO, candidato({ rating: ratingDe(1449.6) }));

  assert.equal(resultado.veredicto, "fuera");
  assert.equal(resultado.motivo?.includes("1450 está"), true);
});

// ----------------------------------------------------------- las divisiones

test("una división admitida encaja y otra no", () => {
  assert.equal(
    admision(DE_CUARTA_Y_QUINTA, candidato({ division: "5ª" })).veredicto,
    "encaja",
  );
  const fuera = admision(DE_CUARTA_Y_QUINTA, candidato({ division: "2ª" }));
  assert.equal(fuera.veredicto, "fuera");
  assert.equal(fuera.motivo?.includes("4ª y 5ª"), true);
});

test("las dos restricciones a la vez exigen las dos", () => {
  // Un torneo de cuarta que además pide 1500 mínimo excluye la mitad baja de
  // cuarta a propósito, y eso es legítimo.
  const exigente: Restriccion = {
    ratingMinimo: 1500,
    ratingMaximo: null,
    divisionesAdmitidas: ["4ª"],
  };

  assert.equal(
    admision(exigente, candidato({ rating: ratingDe(1470), division: "4ª" })).veredicto,
    "fuera",
    "es de cuarta pero no llega al mínimo",
  );
  assert.equal(
    admision(exigente, candidato({ rating: ratingDe(1800), division: "2ª" })).veredicto,
    "fuera",
    "pasa el mínimo pero no es de cuarta",
  );
  assert.equal(
    admision(exigente, candidato({ rating: ratingDe(1550), division: "4ª" })).veredicto,
    "encaja",
  );
});

// ------------------------------------------------------------ la excepción

test("la excepción del organizador gana a todo", () => {
  const resultado = admision(
    DE_CUARTA_Y_QUINTA,
    candidato({ rating: ratingDe(1975), division: "1ª", excepcionAprobada: true }),
  );

  assert.equal(resultado.veredicto, "excepcion");
  assert.equal(resultado.motivo?.includes("organizador"), true);
});

test("la excepción no se calla: sale marcada, no como 'encaja'", () => {
  // Si se contara como encaja, un torneo de cuarta con seis excepciones parecería
  // un torneo de cuarta limpio y nadie podría revisarlo.
  const resultado = admision(
    DE_CUARTA_Y_QUINTA,
    candidato({ division: "4ª", excepcionAprobada: true }),
  );

  assert.equal(resultado.veredicto, "excepcion");
});

// ------------------------------------------------------------ los textos

test("una lista se lee, no se enumera", () => {
  assert.equal(listar([]), "cualquier división");
  assert.equal(listar(["4ª"]), "4ª");
  assert.equal(listar(["4ª", "5ª"]), "4ª y 5ª");
  assert.equal(listar(["3ª", "4ª", "5ª"]), "3ª, 4ª y 5ª");
});

test("el cartel se genera del dato", () => {
  assert.equal(describirRestriccion(SIN_RESTRICCION), "Abierto a cualquier nivel.");
  assert.equal(describirRestriccion(DE_CUARTA_Y_QUINTA), "Sólo 4ª y 5ª.");
  assert.equal(describirRestriccion(DE_RANGO), "Sólo rating de 1450 a 1750.");
  assert.equal(
    describirRestriccion({ ratingMinimo: 1600, ratingMaximo: null, divisionesAdmitidas: [] }),
    "Sólo rating desde 1600.",
  );
  assert.equal(
    describirRestriccion({ ratingMinimo: null, ratingMaximo: 1600, divisionesAdmitidas: [] }),
    "Sólo rating hasta 1600.",
  );
  assert.equal(
    describirRestriccion({
      ratingMinimo: 1500,
      ratingMaximo: null,
      divisionesAdmitidas: ["4ª"],
    }),
    "Sólo 4ª, rating desde 1500.",
  );
});

// -------------------------------------------------------------- el recuento

test("el recuento separa los cuatro casos", () => {
  const cuenta = recontar([
    admision(DE_CUARTA_Y_QUINTA, candidato({ division: "4ª" })),
    admision(DE_CUARTA_Y_QUINTA, candidato({ division: "5ª" })),
    admision(DE_CUARTA_Y_QUINTA, candidato({ division: "1ª" })),
    admision(DE_CUARTA_Y_QUINTA, candidato({ rating: null, division: null })),
    admision(DE_CUARTA_Y_QUINTA, candidato({ division: "1ª", excepcionAprobada: true })),
  ]);

  assert.deepEqual(cuenta, { encajan: 2, fuera: 1, excepciones: 1, sinDatos: 1 });
});

// ------------------------------------------------------------ la fila cruda

test("una fila sin restricciones da la restricción vacía", () => {
  assert.deepEqual(restriccionDeLaFila({}), SIN_RESTRICCION);
  assert.deepEqual(
    restriccionDeLaFila({
      rating_minimo: null,
      rating_maximo: null,
      divisiones_admitidas: null,
    }),
    SIN_RESTRICCION,
  );
});

test("un array con basura dentro se limpia en vez de romper", () => {
  const restriccion = restriccionDeLaFila({
    rating_minimo: 1450,
    divisiones_admitidas: ["4ª", null, "  ", "5ª"],
  });

  assert.deepEqual(restriccion.divisionesAdmitidas, ["4ª", "5ª"]);
  assert.equal(restriccion.ratingMinimo, 1450);
  assert.equal(restriccion.ratingMaximo, null);
});
