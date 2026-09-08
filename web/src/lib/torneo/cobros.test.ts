import test from "node:test";
import assert from "node:assert/strict";
import {
  euros,
  fraseCobros,
  leerImporte,
  masRepetido,
  resumirCobros,
  type InscripcionCobrable,
} from "./cobros.ts";

const gente = (...filas: [string, number | null, boolean][]): InscripcionCobrable[] =>
  filas.map(([nombre, importe, pagado], i) => ({
    id: `j${i}`,
    nombre,
    importe,
    pagado,
  }));

test("un torneo sin importes no dice nada de dinero", () => {
  const r = resumirCobros(gente(["Ana", null, false], ["Luis", null, false]));
  assert.equal(r.hayImportes, false);
  assert.equal(fraseCobros(r), null);
});

test("separa lo cobrado de lo pendiente", () => {
  const r = resumirCobros(
    gente(["Ana", 12, true], ["Luis", 12, false], ["Marta", 12, true]),
  );
  assert.equal(r.cobrado, 24);
  assert.equal(r.pendiente, 12);
  assert.equal(r.total, 36);
  assert.deepEqual(r.pendientes, ["Luis"]);
});

test("los decimales no se van por la coma flotante", () => {
  // 12.10 * 3 en coma flotante da 36.299999999999997.
  const r = resumirCobros(
    gente(["Ana", 12.1, true], ["Luis", 12.1, true], ["Marta", 12.1, true]),
  );
  assert.equal(r.cobrado, 36.3);
  assert.equal(r.total, 36.3);
});

test("quien paga 0 no es un moroso: esta invitado", () => {
  const r = resumirCobros(gente(["Ana", 12, false], ["El organizador", 0, false]));
  assert.deepEqual(r.pendientes, ["Ana"]);
  assert.equal(r.total, 12);
});

test("quien no tiene importe no cuenta para nada", () => {
  const r = resumirCobros(gente(["Ana", 12, true], ["Luis", null, false]));
  assert.equal(r.total, 12);
  assert.deepEqual(r.pendientes, []);
});

test("una fila sin la columna todavia no cuenta como importe", () => {
  // Entre desplegar el codigo y aplicar la 0013, Postgres no devuelve la
  // columna y el importe llega como undefined. Colandose como importe, el
  // total del club salia «NaN €».
  const sinColumna = [
    { id: "j0", nombre: "Ana", pagado: false },
    { id: "j1", nombre: "Luis", pagado: false },
  ] as InscripcionCobrable[];

  const r = resumirCobros(sinColumna);
  assert.equal(r.hayImportes, false);
  assert.equal(r.total, 0);
  assert.equal(fraseCobros(r), null);
});

// El espacio antes del € es duro (U+00A0), como manda `Intl` y como conviene
// para que la cifra no se parta de su moneda al final de una línea.
const NB = " ";

test("con todo cobrado la frase lo dice y no habla de pendientes", () => {
  const r = resumirCobros(gente(["Ana", 12, true], ["Luis", 12, true]));
  assert.equal(fraseCobros(r), `Todo cobrado: 24,00${NB}€.`);
});

test("la frase concuerda en singular", () => {
  const r = resumirCobros(gente(["Ana", 12, true], ["Luis", 12, false]));
  assert.equal(
    fraseCobros(r),
    `12,00${NB}€ cobrados · 12,00${NB}€ de 1 persona sin cobrar.`,
  );
});

test("la frase concuerda en plural", () => {
  const r = resumirCobros(gente(["Ana", 12, false], ["Luis", 12, false]));
  assert.equal(
    fraseCobros(r),
    `0,00${NB}€ cobrados · 24,00${NB}€ de 2 personas sin cobrar.`,
  );
});

test("los euros se escriben como en España, con espacio duro", () => {
  assert.equal(euros(12.5), `12,50${NB}€`);
  assert.equal(euros(0), `0,00${NB}€`);
});

test("un importe con coma decimal se entiende", () => {
  assert.equal(leerImporte("12,50"), 12.5);
  assert.equal(leerImporte("12.50"), 12.5);
  assert.equal(leerImporte(" 12,50 € "), 12.5);
});

test("el campo vacio significa que este torneo no cobra", () => {
  assert.equal(leerImporte(""), null);
  assert.equal(leerImporte("   "), null);
});

test("lo que no es un importe se rechaza, no se convierte en cero", () => {
  assert.equal(leerImporte("gratis"), undefined);
  assert.equal(leerImporte("-5"), undefined);
  assert.equal(leerImporte("1000000"), undefined);
});

test("cero es un importe valido: el invitado paga cero", () => {
  assert.equal(leerImporte("0"), 0);
});

test("el precio del torneo es el importe que mas se repite", () => {
  assert.equal(masRepetido([12, 12, 12, 0]), 12);
});

test("sin importes no hay precio que ofrecer", () => {
  assert.equal(masRepetido([]), null);
});

test("en empate gana el mayor: bajar un precio es mas facil que acordarse de subirlo", () => {
  assert.equal(masRepetido([10, 15]), 15);
});
