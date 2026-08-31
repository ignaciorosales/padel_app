"use client";

import { useActionState } from "react";
import { crearClub, type EstadoClub } from "./actions";
import { SubmitButton } from "@/components/submit-button";
import { Field, Input } from "@/components/ui";

const INICIAL: EstadoClub = {};

export function ClubForm() {
  const [estado, accion] = useActionState(crearClub, INICIAL);

  return (
    <form action={accion} className="flex flex-col gap-4">
      <Field label="Nombre del club">
        <Input name="name" required placeholder="Club Pádel Las Encinas" />
      </Field>

      <Field
        label="Identificador"
        hint="Se usa en la dirección web. Si lo dejas vacío se saca del nombre."
      >
        <Input name="slug" placeholder="las-encinas" />
      </Field>

      {estado.error ? (
        <p role="alert" className="text-sm font-medium text-danger">
          {estado.error}
        </p>
      ) : null}

      {estado.ok ? (
        <p role="status" className="text-sm font-medium text-ok">
          {estado.ok}
        </p>
      ) : null}

      <SubmitButton enCurso="Creando…">Crear club</SubmitButton>
    </form>
  );
}
