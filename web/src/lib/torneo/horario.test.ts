import test from "node:test";
import assert from "node:assert/strict";
import { cambiarHoraDeRonda, type RondaConHora } from "./horario.ts";

const RONDAS: RondaConHora[] = [
  { id: "r1", numero: 1, hora: "10:00" },
  { id: "r2", numero: 2, hora: "10:20" },
  { id: "r3", numero: 3, hora: "10:40" },
  { id: "r4", numero: 4, hora: "11:00" },
];

test("retrasar una ronda arrastra las siguientes el mismo rato", () => {
  assert.deepEqual(cambiarHoraDeRonda(RONDAS, "r1", "10:30"), [
    { id: "r1", hora: "10:30" },
    { id: "r2", hora: "10:50" },
    { id: "r3", hora: "11:10" },
    { id: "r4", hora: "11:30" },
  ]);
});

test("las rondas ya jugadas no se tocan", () => {
  assert.deepEqual(cambiarHoraDeRonda(RONDAS, "r3", "11:00"), [
    { id: "r3", hora: "11:00" },
    { id: "r4", hora: "11:20" },
  ]);
});

test("adelantar tambien arrastra, en el otro sentido", () => {
  assert.deepEqual(cambiarHoraDeRonda(RONDAS, "r2", "10:10"), [
    { id: "r2", hora: "10:10" },
    { id: "r3", hora: "10:30" },
    { id: "r4", hora: "10:50" },
  ]);
});

test("la ronda que viene con la hora que ya tenia no cambia nada", () => {
  assert.deepEqual(cambiarHoraDeRonda(RONDAS, "r2", "10:20"), []);
});

test("vaciar la hora no arrastra a nadie: no define ningun desplazamiento", () => {
  assert.deepEqual(cambiarHoraDeRonda(RONDAS, "r2", null), [{ id: "r2", hora: null }]);
});

test("ponerle hora a una ronda que no la tenia tampoco arrastra", () => {
  const sinHora: RondaConHora[] = [
    { id: "r1", numero: 1, hora: null },
    { id: "r2", numero: 2, hora: null },
  ];
  assert.deepEqual(cambiarHoraDeRonda(sinHora, "r1", "10:00"), [{ id: "r1", hora: "10:00" }]);
});

test("una ronda posterior sin hora se queda sin hora", () => {
  const mezcla: RondaConHora[] = [
    { id: "r1", numero: 1, hora: "10:00" },
    { id: "r2", numero: 2, hora: null },
    { id: "r3", numero: 3, hora: "10:40" },
  ];
  assert.deepEqual(cambiarHoraDeRonda(mezcla, "r1", "10:10"), [
    { id: "r1", hora: "10:10" },
    { id: "r3", hora: "10:50" },
  ]);
});

test("la hora larga de Postgres se entiende igual", () => {
  const conSegundos: RondaConHora[] = [
    { id: "r1", numero: 1, hora: "10:00:00" },
    { id: "r2", numero: 2, hora: "10:20:00" },
  ];
  assert.deepEqual(cambiarHoraDeRonda(conSegundos, "r1", "10:30"), [
    { id: "r1", hora: "10:30" },
    { id: "r2", hora: "10:50" },
  ]);
});

test("arrastrar mas alla de medianoche se queda pegado al final del dia", () => {
  const tarde: RondaConHora[] = [
    { id: "r1", numero: 1, hora: "23:00" },
    { id: "r2", numero: 2, hora: "23:40" },
  ];
  assert.deepEqual(cambiarHoraDeRonda(tarde, "r1", "23:30"), [
    { id: "r1", hora: "23:30" },
    { id: "r2", hora: "23:59" },
  ]);
});

test("una ronda que no es de este torneo no cambia nada", () => {
  assert.deepEqual(cambiarHoraDeRonda(RONDAS, "inventada", "10:00"), []);
});
