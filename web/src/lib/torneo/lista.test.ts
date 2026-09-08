import test from "node:test";
import assert from "node:assert/strict";
import { parsearLista, parsearParejas } from "./lista.ts";

const nombres = (texto: string) => parsearLista(texto).map((j) => j.nombre);

test("una lista limpia, un nombre por línea", () => {
  assert.deepEqual(nombres("Juan\nAna\nLuis"), ["Juan", "Ana", "Luis"]);
});

test("quita la numeración de las listas", () => {
  assert.deepEqual(
    nombres("1. Juan\n2. Ana\n3) Luis\n4 - Marta"),
    ["Juan", "Ana", "Luis", "Marta"],
  );
});

test("quita viñetas y espacios de más", () => {
  assert.deepEqual(
    nombres("- Juan\n•   Ana \n*Luis"),
    ["Juan", "Ana", "Luis"],
  );
});

test("separa el teléfono del nombre", () => {
  const lista = parsearLista("Juan Pérez 600 12 34 56\nAna López +34 611223344\nLuis");

  assert.deepEqual(lista, [
    { nombre: "Juan Pérez", telefono: "600123456" },
    { nombre: "Ana López", telefono: "+34611223344" },
    { nombre: "Luis", telefono: null },
  ]);
});

test("un número corto es parte del nombre, no un teléfono", () => {
  assert.deepEqual(parsearLista("Equipo 3"), [{ nombre: "Equipo 3", telefono: null }]);
});

test("entiende una conversación exportada de WhatsApp", () => {
  const pegado = [
    "[12/03/2026, 10:04] Juan Pérez: me apunto",
    "[12/03/2026, 10:05] Ana López: yo también",
    "12/03/2026, 10:06 - Luis Díaz: y yo",
  ].join("\n");

  assert.deepEqual(nombres(pegado), ["Juan Pérez", "Ana López", "Luis Díaz"]);
});

test("una sola línea con comas se reparte", () => {
  assert.deepEqual(nombres("Juan, Ana, Luis, Marta"), ["Juan", "Ana", "Luis", "Marta"]);
});

test("no parte por comas cuando ya hay varias líneas", () => {
  // "Apellido, Nombre" es una forma normal de escribir una lista.
  assert.deepEqual(nombres("Pérez, Juan\nLópez, Ana"), ["Pérez, Juan", "López, Ana"]);
});

test("quita repetidos sin distinguir mayúsculas ni tildes", () => {
  assert.deepEqual(nombres("Juan\nJUAN\nJuán\nAna"), ["Juan", "Ana"]);
});

test("ignora líneas vacías y basura sin letras", () => {
  assert.deepEqual(nombres("Juan\n\n   \n---\n42\nAna"), ["Juan", "Ana"]);
});

test("texto vacío da lista vacía", () => {
  assert.deepEqual(parsearLista(""), []);
  assert.deepEqual(parsearLista("   \n  \n"), []);
});

test("un caso real: la línea de título también entra, y se quita a mano", () => {
  // El parseo no adivina qué línea es un título. La pantalla enseña la lista
  // resultante antes de guardar, precisamente para poder quitar esa fila.
  const pegado = `Americano sábado 🎾
1. Juan Pérez 600123456
2. Ana López
3. Luis
4- Marta Ruiz +34 611 22 33 44
- Carlos
Carlos
`;

  assert.deepEqual(nombres(pegado), [
    "Americano sábado 🎾",
    "Juan Pérez",
    "Ana López",
    "Luis",
    "Marta Ruiz",
    "Carlos",
  ]);
});

// ------------------------------------------------------------------ parejas

test("lee las parejas separadas como las escribe la gente", () => {
  const { parejas, problemas } = parsearParejas(
    [
      "Ana Ruiz / Luis Gómez",
      "Marta y Pedro",
      "Sara + Iván",
      "Nuria - Toni",
      "Eva | Juan",
    ].join("\n"),
  );

  assert.equal(problemas.length, 0);
  assert.deepEqual(parejas[0], { uno: "Ana Ruiz", dos: "Luis Gómez" });
  assert.deepEqual(parejas[1], { uno: "Marta", dos: "Pedro" });
  assert.deepEqual(parejas[2], { uno: "Sara", dos: "Iván" });
  assert.deepEqual(parejas[3], { uno: "Nuria", dos: "Toni" });
  assert.deepEqual(parejas[4], { uno: "Eva", dos: "Juan" });
});

test("quita numeración y viñetas igual que la lista de jugadores", () => {
  const { parejas } = parsearParejas("1. Ana / Luis\n2) Marta / Pedro\n- Eva / Juan");
  assert.equal(parejas.length, 3);
  assert.deepEqual(parejas[0], { uno: "Ana", dos: "Luis" });
});

test("una línea sin compañero se avisa, no se descarta en silencio", () => {
  const { parejas, problemas } = parsearParejas("Ana / Luis\nMartaSola\nEva / Juan");
  assert.equal(parejas.length, 2);
  assert.equal(problemas.length, 1);
  assert.match(problemas[0].linea, /MartaSola/);
  assert.match(problemas[0].motivo, /compañero/);
});

test("tres nombres en una línea se avisan con el número", () => {
  const { problemas } = parsearParejas("Ana / Luis / Pedro");
  assert.equal(problemas.length, 1);
  assert.match(problemas[0].motivo, /3 nombres/);
});

test("un jugador en dos parejas se avisa diciendo quién", () => {
  const { parejas, problemas } = parsearParejas("Ana / Luis\nAna / Pedro");
  assert.equal(parejas.length, 1);
  assert.equal(problemas.length, 1);
  assert.match(problemas[0].motivo, /Ana ya juega/);
});

test("el repetido se detecta sin importar tildes ni mayúsculas", () => {
  const { problemas } = parsearParejas("Iván / Luis\nIVAN / Pedro");
  assert.equal(problemas.length, 1);
  assert.match(problemas[0].motivo, /ya juega/);
});

test("la misma persona consigo misma no es una pareja", () => {
  const { parejas, problemas } = parsearParejas("Ana / Ana");
  assert.equal(parejas.length, 0);
  assert.match(problemas[0].motivo, /dos veces/);
});

test("las líneas en blanco no cuentan como problema", () => {
  const { parejas, problemas } = parsearParejas("Ana / Luis\n\n   \nEva / Juan\n");
  assert.equal(parejas.length, 2);
  assert.equal(problemas.length, 0);
});

test("una lista pegada de un chat exportado también se lee", () => {
  const { parejas } = parsearParejas(
    "[12/03/2026, 10:04] Recepción: Ana / Luis\n[12/03/2026, 10:05] Recepción: Marta / Pedro",
  );
  assert.deepEqual(parejas, [
    { uno: "Ana", dos: "Luis" },
    { uno: "Marta", dos: "Pedro" },
  ]);
});
