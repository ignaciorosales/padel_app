/**
 * El orden y las decisiones de la pantalla de unificación.
 *
 * Lo que se prueba no es el parecido —eso ya tiene sus tests en unificar.test.ts—
 * sino lo que decide si la pantalla se usa o se abandona: qué sale primero, qué
 * viene marcado y qué no se marca nunca.
 */

import test from "node:test";
import assert from "node:assert/strict";
import {
  comoSeLlama,
  estadoDeUnificacion,
  nombreYApellidoDe,
  personasConSusTorneos,
  type FilaDeInscrito,
  type FilaDePersona,
} from "./panel.ts";

const inscrito = (p: Partial<FilaDeInscrito> = {}): FilaDeInscrito => ({
  id: "i1",
  tournament_id: "t1",
  nombre: "Nacho R.",
  telefono: null,
  player_id: null,
  ...p,
});

const persona = (p: Partial<FilaDePersona> = {}): FilaDePersona => ({
  id: "p1",
  nombre: "Ignacio",
  apellido: "Rosales",
  apodo: null,
  telefono: null,
  ...p,
});

// ------------------------------------------------------------ los torneos

test("una persona arrastra los torneos donde ya se le reconoció", () => {
  const personas = personasConSusTorneos(
    [persona()],
    [
      inscrito({ id: "i1", tournament_id: "t1", player_id: "p1" }),
      inscrito({ id: "i2", tournament_id: "t2", player_id: "p1" }),
      inscrito({ id: "i3", tournament_id: "t3", player_id: null }),
    ],
  );

  assert.deepEqual(personas[0].torneos, ["t1", "t2"]);
});

test("nadie se propone para un torneo en el que ya está", () => {
  // El mismo nombre exacto, pero esa persona ya tiene fila en t1: este inscrito
  // es necesariamente otra persona, porque nadie juega contra sí mismo.
  const estado = estadoDeUnificacion(
    [
      inscrito({ id: "i1", tournament_id: "t1", nombre: "Ignacio Rosales", player_id: "p1" }),
      inscrito({ id: "i2", tournament_id: "t1", nombre: "Ignacio Rosales" }),
    ],
    [persona()],
  );

  const pendiente = estado.pendientes.find((p) => p.inscrito.id === "i2")!;
  assert.deepEqual(pendiente.candidatos, []);
});

// -------------------------------------------------------------- el orden

test("lo dudoso va primero, y lo que no se parece a nadie al final", () => {
  const estado = estadoDeUnificacion(
    [
      // Nombre completo idéntico: claro.
      inscrito({ id: "claro", tournament_id: "t1", nombre: "Ignacio Rosales" }),
      // Nada que ver con nadie.
      inscrito({ id: "suelto", tournament_id: "t1", nombre: "Zulema Quintanilla" }),
      // Apodo más inicial del apellido: candidato de sobra, pero no para marcarlo
      // solo. Es el caso más común de todos y el que hay que mirar.
      inscrito({ id: "dudoso", tournament_id: "t2", nombre: "Nacho R." }),
    ],
    [persona()],
  );

  assert.deepEqual(
    estado.pendientes.map((p) => p.inscrito.id),
    ["dudoso", "claro", "suelto"],
  );
});

test("un candidato claro viene marcado; uno flojo no", () => {
  const estado = estadoDeUnificacion(
    [
      inscrito({ id: "claro", nombre: "Ignacio Rosales" }),
      inscrito({ id: "flojo", tournament_id: "t2", nombre: "Nacho R." }),
    ],
    [persona()],
  );

  const claro = estado.pendientes.find((p) => p.inscrito.id === "claro")!;
  const flojo = estado.pendientes.find((p) => p.inscrito.id === "flojo")!;

  assert.equal(claro.claro, true);
  assert.equal(flojo.claro, false);
  assert.equal(flojo.candidatos.length > 0, true, "flojo sigue siendo un candidato");
});

test("dos candidatos igual de buenos no se marcan, aunque los dos puntúen alto", () => {
  // Los dos hermanos con el mismo apellido y el mismo teléfono de casa. Es el
  // error que no se deshace: marcar al primero de los dos.
  const estado = estadoDeUnificacion(
    [inscrito({ nombre: "Rosales", telefono: "600111222" })],
    [
      persona({ id: "p1", nombre: "Ignacio", apellido: "Rosales", telefono: "600111222" }),
      persona({ id: "p2", nombre: "Martín", apellido: "Rosales", telefono: "600111222" }),
    ],
  );

  const pendiente = estado.pendientes[0];
  assert.equal(pendiente.candidatos.length, 2);
  assert.equal(
    pendiente.candidatos[0].puntuacion,
    pendiente.candidatos[1].puntuacion,
    "empatados: el caso que importa",
  );
  assert.equal(pendiente.claro, false);
});

test("cada candidato trae por qué, no sólo un número", () => {
  const estado = estadoDeUnificacion(
    [inscrito({ nombre: "Ignacio Rosales", telefono: "600111222" })],
    [persona({ telefono: "600111222" })],
  );

  const motivos = estado.pendientes[0].candidatos[0].motivos;
  assert.equal(motivos.length > 0, true);
  assert.equal(motivos.includes("mismo teléfono"), true);
});

// ------------------------------------------------------------- los grupos

test("el primer día no hay personas: los nombres se agrupan entre ellos", () => {
  const estado = estadoDeUnificacion(
    [
      inscrito({ id: "i1", tournament_id: "t1", nombre: "Ignacio Rosales" }),
      inscrito({ id: "i2", tournament_id: "t2", nombre: "Ignacio Rosales" }),
      inscrito({ id: "i3", tournament_id: "t3", nombre: "Zulema Quintanilla" }),
    ],
    [],
  );

  assert.equal(estado.grupos.length, 1);
  assert.deepEqual(
    estado.grupos[0].inscritos.map((i) => i.id),
    ["i1", "i2"],
  );
  assert.equal(estado.grupos[0].nombrePropuesto, "Ignacio Rosales");
  assert.equal(estado.sueltos, 1, "Zulema no se agrupa con nadie");
});

test("un nombre suelto no forma grupo de uno", () => {
  const estado = estadoDeUnificacion(
    [inscrito({ nombre: "Zulema Quintanilla" })],
    [],
  );

  assert.deepEqual(estado.grupos, []);
  assert.equal(estado.sueltos, 1);
});

test("quien ya se parece a una persona existente no entra en un grupo nuevo", () => {
  // Ofrecer las dos cosas —«es Ignacio» y «crea a Ignacio»— es ofrecer dos
  // caminos para lo mismo, y uno de los dos duplica la ficha.
  const estado = estadoDeUnificacion(
    [
      inscrito({ id: "i1", tournament_id: "t1", nombre: "Ignacio Rosales" }),
      inscrito({ id: "i2", tournament_id: "t2", nombre: "Ignacio Rosales" }),
    ],
    [persona()],
  );

  assert.deepEqual(estado.grupos, []);
  assert.equal(estado.pendientes.every((p) => p.candidatos.length > 0), true);
});

test("el progreso se cuenta sobre todos los inscritos, unificados incluidos", () => {
  const estado = estadoDeUnificacion(
    [
      inscrito({ id: "i1", player_id: "p1" }),
      inscrito({ id: "i2", tournament_id: "t2", player_id: "p1" }),
      inscrito({ id: "i3", tournament_id: "t3", nombre: "Zulema Quintanilla" }),
    ],
    [persona()],
  );

  assert.equal(estado.total, 3);
  assert.equal(estado.unificados, 2);
  assert.equal(estado.pendientes.length, 1);
});

test("sin nada que unificar, la pantalla está vacía y lo dice", () => {
  const estado = estadoDeUnificacion([], []);

  assert.deepEqual(estado.pendientes, []);
  assert.deepEqual(estado.grupos, []);
  assert.equal(estado.total, 0);
  assert.equal(estado.unificados, 0);
  assert.equal(estado.sueltos, 0);
});

// ---------------------------------------------------------------- nombres

test("el apodo se enseña además del nombre, no en su lugar", () => {
  assert.equal(comoSeLlama(persona({ apodo: "Nacho" })), "Ignacio Rosales «Nacho»");
  assert.equal(comoSeLlama(persona()), "Ignacio Rosales");
  assert.equal(comoSeLlama(persona({ apellido: null })), "Ignacio");
});

test("el nombre de una persona nueva se parte en pila y apellidos", () => {
  assert.deepEqual(nombreYApellidoDe("Ignacio Rosales"), {
    nombre: "Ignacio",
    apellido: "Rosales",
  });
  assert.deepEqual(nombreYApellidoDe("Ignacio Rosales Pérez"), {
    nombre: "Ignacio",
    apellido: "Rosales Pérez",
  });
  assert.deepEqual(nombreYApellidoDe("Nacho"), { nombre: "Nacho", apellido: null });
  assert.deepEqual(nombreYApellidoDe("  Ana   López  "), {
    nombre: "Ana",
    apellido: "López",
  });
});
