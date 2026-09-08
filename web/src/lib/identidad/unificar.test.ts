import test from "node:test";
import assert from "node:assert/strict";
import {
  agruparInscritos,
  comparar,
  proponerPersonas,
  UMBRAL_CLARO,
  UMBRAL_PROPUESTA,
  type Inscrito,
  type Persona,
} from "./unificar.ts";

const inscrito = (p: Partial<Inscrito> = {}): Inscrito => ({
  id: "i1",
  tournamentId: "t1",
  nombre: "Ignacio Rosales",
  telefono: null,
  ...p,
});

const persona = (p: Partial<Persona> = {}): Persona => ({
  id: "j1",
  nombre: "Ignacio",
  apellido: "Rosales",
  telefono: null,
  ...p,
});

// ------------------------------------------------------------------ el caso

test("«Nacho R.» y «Ignacio Rosales» se proponen como la misma persona", () => {
  const c = comparar(inscrito({ nombre: "Nacho R." }), persona());

  assert.ok(c.puntuacion >= UMBRAL_PROPUESTA, `puntuación ${c.puntuacion}`);
  assert.ok(c.motivos.some((m) => m.includes("apodo")));
});

test("el mismo nombre entero es lo más claro que hay", () => {
  const c = comparar(inscrito(), persona());

  assert.ok(c.puntuacion >= UMBRAL_CLARO);
  assert.ok(c.motivos.includes("mismo nombre completo"));
});

test("dos desconocidos no se parecen", () => {
  const c = comparar(inscrito({ nombre: "Martín Gómez" }), persona());
  assert.ok(c.puntuacion < UMBRAL_PROPUESTA);
});

test("el mismo nombre de pila, solo, no basta para proponer", () => {
  const c = comparar(inscrito({ nombre: "Ignacio Gómez" }), persona());
  assert.ok(c.puntuacion < UMBRAL_PROPUESTA, `puntuación ${c.puntuacion}`);
});

// ------------------------------------------------------------- el teléfono

test("el teléfono une aunque el nombre esté escrito de otra forma", () => {
  const c = comparar(
    inscrito({ nombre: "nacho", telefono: "099 123 456" }),
    persona({ telefono: "+598 99 123 456" }),
  );

  assert.ok(c.puntuacion >= UMBRAL_PROPUESTA);
  assert.ok(c.motivos.includes("mismo teléfono"));
});

test("dos teléfonos distintos separan a dos que se llaman igual", () => {
  const conTelefono = comparar(
    inscrito({ telefono: "099111111" }),
    persona({ telefono: "099222222" }),
  );
  const sinTelefono = comparar(inscrito(), persona());

  assert.ok(conTelefono.puntuacion < sinTelefono.puntuacion);
  assert.ok(conTelefono.motivos.includes("teléfonos distintos"));
});

test("mismo teléfono y otro apellido avisa de que puede ser un familiar", () => {
  const c = comparar(
    inscrito({ nombre: "Lucía Fernández", telefono: "099123456" }),
    persona({ nombre: "Ignacio", apellido: "Rosales", telefono: "099123456" }),
  );

  assert.ok(c.puntuacion < UMBRAL_CLARO, "no puede darse por seguro");
  assert.ok(c.motivos.some((m) => m.includes("familiar")));
});

// ---------------------------------------------------------------- el apodo

test("el apodo guardado en la ficha sirve para reconocer al inscrito", () => {
  const c = comparar(
    inscrito({ nombre: "Tincho Gómez" }),
    persona({ nombre: "Martín", apellido: "Gómez", apodo: "Tincho" }),
  );

  assert.ok(c.puntuacion >= UMBRAL_PROPUESTA);
  assert.ok(c.motivos.some((m) => m.includes("Tincho")));
});

// ----------------------------------------------------- la regla del torneo

test("quien ya está en ese torneo no se propone: sería jugar contra sí mismo", () => {
  const candidatos = proponerPersonas(inscrito({ tournamentId: "t1" }), [
    persona({ torneos: ["t1"] }),
  ]);

  assert.deepEqual(candidatos, []);
});

test("la misma persona sí se propone si el torneo es otro", () => {
  const candidatos = proponerPersonas(inscrito({ tournamentId: "t2" }), [
    persona({ torneos: ["t1"] }),
  ]);

  assert.equal(candidatos.length, 1);
  assert.equal(candidatos[0].personaId, "j1");
});

test("los candidatos salen de más a menos parecido", () => {
  const candidatos = proponerPersonas(inscrito({ nombre: "Ignacio Rosales" }), [
    persona({ id: "flojo", nombre: "Nacho", apellido: "R" }),
    persona({ id: "clavado", nombre: "Ignacio", apellido: "Rosales" }),
  ]);

  assert.equal(candidatos[0].personaId, "clavado");
  assert.ok(candidatos[0].puntuacion > candidatos[1].puntuacion);
});

test("cada candidato viene con el porqué, no sólo con el número", () => {
  const [candidato] = proponerPersonas(inscrito(), [persona()]);
  assert.ok(candidato.motivos.length > 0);
});

// --------------------------------------------------------------- agrupar

test("el mismo jugador en tres torneos acaba en un solo grupo", () => {
  const grupos = agruparInscritos([
    inscrito({ id: "a", tournamentId: "t1", nombre: "Ignacio Rosales" }),
    inscrito({ id: "b", tournamentId: "t2", nombre: "Nacho Rosales" }),
    inscrito({ id: "c", tournamentId: "t3", nombre: "IGNACIO ROSALES" }),
  ]);

  assert.equal(grupos.length, 1);
  assert.equal(grupos[0].inscritos.length, 3);
});

test("el grupo propone el nombre más completo de los que tiene", () => {
  const grupos = agruparInscritos([
    inscrito({ id: "a", tournamentId: "t1", nombre: "Nacho R." }),
    inscrito({ id: "b", tournamentId: "t2", nombre: "Ignacio Rosales" }),
  ]);

  assert.equal(grupos[0].nombrePropuesto, "Ignacio Rosales");
});

test("dos personas distintas no se mezclan", () => {
  const grupos = agruparInscritos([
    inscrito({ id: "a", tournamentId: "t1", nombre: "Ignacio Rosales" }),
    inscrito({ id: "b", tournamentId: "t1", nombre: "Martín Gómez" }),
    inscrito({ id: "c", tournamentId: "t2", nombre: "Martín Gómez" }),
  ]);

  assert.equal(grupos.length, 2);
  assert.equal(grupos.find((g) => g.nombrePropuesto.includes("Gómez"))!.inscritos.length, 2);
});

test("dos inscritos del mismo torneo nunca caen en el mismo grupo", () => {
  // Dos hermanos con el mismo apellido en el mismo americano.
  const grupos = agruparInscritos([
    inscrito({ id: "a", tournamentId: "t1", nombre: "Ignacio Rosales" }),
    inscrito({ id: "b", tournamentId: "t1", nombre: "Ignacio Rosales" }),
  ]);

  assert.equal(grupos.length, 2);
});

test("una lista vacía no da grupos", () => {
  assert.deepEqual(agruparInscritos([]), []);
});

test("el grupo dice de qué se fía: con un apodo, menos que con el nombre entero", () => {
  const flojo = agruparInscritos([
    inscrito({ id: "a", tournamentId: "t1", nombre: "Nacho R." }),
    inscrito({ id: "b", tournamentId: "t2", nombre: "Ignacio Rosales" }),
  ]);
  const claro = agruparInscritos([
    inscrito({ id: "a", tournamentId: "t1", nombre: "Ignacio Rosales" }),
    inscrito({ id: "b", tournamentId: "t2", nombre: "Ignacio Rosales" }),
  ]);

  assert.ok(flojo[0].confianza < claro[0].confianza);
});
