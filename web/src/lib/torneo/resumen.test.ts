import test from "node:test";
import assert from "node:assert/strict";
import { fechaLarga, resumenPublico, type DatosResumen } from "./resumen.ts";

const BASE: DatosResumen = {
  estado: "borrador",
  fecha: "2026-09-05",
  jugadores: 16,
  jugados: 0,
  total: 0,
  campeon: null,
};

test("antes de empezar dice cuándo es y cuánta gente viene", () => {
  const texto = resumenPublico(BASE);
  assert.match(texto, /5 de septiembre de 2026/);
  assert.match(texto, /16 jugadores/);
});

test("con rondas generadas pero sin resultados sigue anunciando la fecha", () => {
  const texto = resumenPublico({ ...BASE, estado: "en_juego", total: 12 });
  assert.match(texto, /5 de septiembre/);
  assert.doesNotMatch(texto, /En juego/);
});

test("a mitad de torneo cuenta por dónde va", () => {
  const texto = resumenPublico({
    ...BASE,
    estado: "en_juego",
    jugados: 5,
    total: 12,
  });
  assert.equal(
    texto,
    "En juego: 5 de 12 partidos. Cruces y clasificación en directo.",
  );
});

test("con todo jugado pero sin cerrar, no inventa un campeón", () => {
  const texto = resumenPublico({
    ...BASE,
    estado: "en_juego",
    jugados: 12,
    total: 12,
  });
  assert.match(texto, /Todos los partidos jugados/);
  assert.doesNotMatch(texto, /Ganó/);
});

test("terminado con campeón lo pone primero: es lo que hace abrir el enlace", () => {
  const texto = resumenPublico({
    ...BASE,
    estado: "terminado",
    jugados: 12,
    total: 12,
    campeon: "Ana Ruiz",
  });
  assert.match(texto, /^Ganó Ana Ruiz\./);
});

test("terminado sin nadie en la clasificación no dice 'Ganó null'", () => {
  const texto = resumenPublico({
    ...BASE,
    estado: "terminado",
    jugadores: 0,
    campeon: null,
  });
  assert.doesNotMatch(texto, /null|undefined|Ganó/);
});

test("fechaLarga no se va de día por la zona horaria", () => {
  // Sin la hora explícita, "2026-09-05" se interpreta como UTC y en un huso
  // negativo se enseñaría el día 4.
  assert.match(fechaLarga("2026-09-05"), /5 de septiembre de 2026/);
  assert.match(fechaLarga("2026-01-01"), /1 de enero de 2026/);
});
