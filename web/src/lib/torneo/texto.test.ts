import test from "node:test";
import assert from "node:assert/strict";
import {
  textoClasificacion,
  textoRonda,
  type PartidoTexto,
  type RondaTexto,
} from "./texto.ts";

const P1: PartidoTexto = {
  pista: 1,
  a: ["Ana", "Luis"],
  b: ["Eva", "Juan"],
  juegosA: null,
  juegosB: null,
};

const RONDA: RondaTexto = {
  torneo: "Americano del Bosque",
  numero: 2,
  hora: "18:20",
  partidos: [P1],
  descansan: [],
};

test("una línea por partido: doce líneas por ronda no las lee nadie", () => {
  const texto = textoRonda({
    ...RONDA,
    partidos: [
      P1,
      { ...P1, pista: 2, a: ["Marta", "Pedro"], b: ["Sara", "Iván"] },
    ],
  });

  const partidos = texto.split("\n").filter((l) => l.startsWith("P"));
  assert.equal(partidos.length, 2);
  assert.equal(partidos[0], "P1  Ana / Luis  vs  Eva / Juan");
});

test("la cabecera lleva la hora cuando la hay, y no la inventa cuando no", () => {
  assert.match(textoRonda(RONDA), /^\*Americano del Bosque — Ronda 2\* \(18:20\)/);
  assert.match(textoRonda({ ...RONDA, hora: null }), /^\*Americano del Bosque — Ronda 2\*\n/);
});

test("con resultado enseña el marcador en vez de 'vs'", () => {
  const texto = textoRonda({
    ...RONDA,
    partidos: [{ ...P1, juegosA: 6, juegosB: 2 }],
  });
  assert.match(texto, /P1 {2}Ana \/ Luis {2}6-2 {2}Eva \/ Juan/);
  assert.doesNotMatch(texto, / vs /);
});

test("un 0-0 es un resultado, no un partido sin jugar", () => {
  const texto = textoRonda({
    ...RONDA,
    partidos: [{ ...P1, juegosA: 0, juegosB: 0 }],
  });
  assert.match(texto, /0-0/);
  assert.doesNotMatch(texto, / vs /);
});

test("los que descansan salen sólo si los hay", () => {
  assert.doesNotMatch(textoRonda(RONDA), /Descansan/);
  assert.match(
    textoRonda({ ...RONDA, descansan: ["Nuria", "Toni"] }),
    /Descansan: Nuria, Toni/,
  );
});

test("el enlace va al final, que es donde WhatsApp saca la vista previa", () => {
  const texto = textoRonda({ ...RONDA, url: "https://x.test/t/bosque/agosto" });
  assert.ok(texto.endsWith("https://x.test/t/bosque/agosto"));
});

test("la clasificación marca el signo de la diferencia en los dos sentidos", () => {
  const texto = textoClasificacion("Americano del Bosque", [
    { puesto: 1, nombre: "Ana", juegosFavor: 24, diferencia: 11 },
    { puesto: 2, nombre: "Luis", juegosFavor: 18, diferencia: 0 },
    { puesto: 3, nombre: "Eva", juegosFavor: 12, diferencia: -7 },
  ]);

  assert.match(texto, /1\. Ana {2}24 \(\+11\)/);
  assert.match(texto, /2\. Luis {2}18 \(0\)/);
  assert.match(texto, /3\. Eva {2}12 \(-7\)/);
});

test("una clasificación vacía lo dice, no sale un hueco", () => {
  const texto = textoClasificacion("Americano del Bosque", []);
  assert.match(texto, /Todavía no hay resultados/);
});
