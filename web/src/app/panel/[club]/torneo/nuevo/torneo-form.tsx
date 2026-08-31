"use client";

import { useActionState } from "react";
import { crearTorneo, type EstadoTorneoForm } from "../../actions";
import { SubmitButton } from "@/components/submit-button";
import { Field, Input } from "@/components/ui";

const INICIAL: EstadoTorneoForm = {};

export function TorneoForm({ clubSlug }: { clubSlug: string }) {
  const [estado, accion] = useActionState(crearTorneo, INICIAL);
  const hoy = new Date().toISOString().slice(0, 10);

  return (
    <form action={accion} className="flex flex-col gap-5">
      <input type="hidden" name="clubSlug" value={clubSlug} />

      <Field label="Nombre" hint="El que va a ver la gente. «Americano del sábado», por ejemplo.">
        <Input name="nombre" required autoFocus placeholder="Americano del sábado" />
      </Field>

      <div className="grid gap-5 sm:grid-cols-2">
        <Field label="Fecha">
          <Input name="fecha" type="date" required defaultValue={hoy} />
        </Field>

        <Field label="Hora de inicio" hint="Opcional. Sirve para calcular la hora de cada ronda.">
          <Input name="hora_inicio" type="time" defaultValue="10:00" />
        </Field>
      </div>

      <div className="grid gap-5 sm:grid-cols-3">
        <Field label="Pistas">
          <Input name="pistas" type="number" min={1} max={30} required defaultValue={3} />
        </Field>

        <Field label="Rondas">
          <Input name="rondas" type="number" min={1} max={40} required defaultValue={6} />
        </Field>

        <Field label="Minutos por ronda">
          <Input
            name="minutos_por_ronda"
            type="number"
            min={5}
            max={180}
            required
            defaultValue={20}
          />
        </Field>
      </div>

      {estado.error ? (
        <p role="alert" className="text-sm font-medium text-danger">
          {estado.error}
        </p>
      ) : null}

      <div>
        <SubmitButton enCurso="Creando…">Crear torneo</SubmitButton>
      </div>

      <p className="text-sm text-ink-faint">
        Los jugadores se añaden después, y las rondas se generan cuando estén todos.
        Todo esto se puede cambiar mientras el torneo siga en borrador.
      </p>
    </form>
  );
}
