import test from "node:test";
import assert from "node:assert/strict";
import {
  compararApellidos,
  esDiminutivo,
  esInicialDe,
  normalizar,
  normalizarTelefono,
  partirNombre,
  pilaCompatible,
} from "./nombres.ts";

// ------------------------------------------------------------- normalizar

test("mayúsculas, tildes y espacios de más dan igual", () => {
  assert.equal(normalizar("  IGNACIO   ROSALÉS "), "ignacio rosales");
});

test("la eñe se compara como ene, que es como se teclea", () => {
  assert.equal(normalizar("Muñoz"), normalizar("Munoz"));
});

test("el punto de una inicial no estorba", () => {
  assert.equal(normalizar("Nacho R."), "nacho r");
});

// ----------------------------------------------------------------- partir

test("la primera palabra es el nombre y el resto apellidos", () => {
  assert.deepEqual(partirNombre("Ignacio Rosales Pérez"), {
    pila: "ignacio",
    apellidos: ["rosales", "perez"],
  });
});

test("con coma se entiende al revés", () => {
  assert.deepEqual(partirNombre("Rosales, Ignacio"), {
    pila: "ignacio",
    apellidos: ["rosales"],
  });
});

test("quien se apunta sólo con el nombre no tiene apellidos", () => {
  assert.deepEqual(partirNombre("Nacho"), { pila: "nacho", apellidos: [] });
});

test("un nombre vacío no revienta", () => {
  assert.deepEqual(partirNombre("   "), { pila: "", apellidos: [] });
});

// --------------------------------------------------------------- teléfono

test("el mismo número escrito de tres formas es el mismo número", () => {
  const uno = normalizarTelefono("+598 99 123 456");
  assert.equal(normalizarTelefono("099123456"), uno);
  assert.equal(normalizarTelefono("099 123 456"), uno);
});

test("un teléfono que no lo es se descarta", () => {
  assert.equal(normalizarTelefono("s/n"), null);
  assert.equal(normalizarTelefono(null), null);
  assert.equal(normalizarTelefono("123"), null);
});

// ------------------------------------------------------------ diminutivos

test("los diminutivos regulares salen de la propia palabra", () => {
  assert.ok(esDiminutivo("santi", "santiago"));
  assert.ok(esDiminutivo("javi", "javier"));
  assert.ok(esDiminutivo("fede", "federico"));
});

test("los irregulares están en la lista", () => {
  assert.ok(esDiminutivo("nacho", "ignacio"));
  assert.ok(esDiminutivo("pepe", "jose"));
  assert.ok(esDiminutivo("tincho", "martin"));
});

test("una letra suelta no es un diminutivo", () => {
  assert.equal(esDiminutivo("a", "andres"), false);
  assert.equal(esDiminutivo("an", "andres"), false);
});

test("nadie es diminutivo de sí mismo", () => {
  assert.equal(esDiminutivo("martin", "martin"), false);
});

test("la compatibilidad funciona en los dos sentidos", () => {
  assert.ok(pilaCompatible("nacho", "ignacio"));
  assert.ok(pilaCompatible("ignacio", "nacho"));
  assert.ok(pilaCompatible("martin", "martin"));
  assert.equal(pilaCompatible("martin", "santiago"), false);
});

// --------------------------------------------------------------- apellidos

test("comparten apellido aunque uno lleve dos", () => {
  assert.equal(compararApellidos(["rosales"], ["rosales", "perez"]), "igual");
});

test("una inicial encaja con el apellido entero", () => {
  assert.equal(compararApellidos(["r"], ["rosales"]), "inicial");
});

test("sin apellido no hay desacuerdo, hay falta de datos", () => {
  assert.equal(compararApellidos([], ["rosales"]), "ninguno");
});

test("dos apellidos que no se parecen son distintos", () => {
  assert.equal(compararApellidos(["rosales"], ["gomez"]), "distinto");
});

test("esInicialDe no confunde una palabra con otra", () => {
  assert.ok(esInicialDe("r", "rosales"));
  assert.equal(esInicialDe("ro", "rosales"), false);
  assert.equal(esInicialDe("r", "r"), false);
});
