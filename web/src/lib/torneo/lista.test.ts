import test from "node:test";
import assert from "node:assert/strict";
import { parsearLista } from "./lista.ts";

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
