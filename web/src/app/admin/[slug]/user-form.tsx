"use client";

import { useActionState } from "react";
import { crearUsuarioDeClub, type EstadoUsuario } from "../actions";
import { SubmitButton } from "@/components/submit-button";
import { Field, Input, Select } from "@/components/ui";

const INICIAL: EstadoUsuario = {};

export function UserForm({ clubId }: { clubId: string }) {
  const [estado, accion] = useActionState(crearUsuarioDeClub, INICIAL);

  return (
    <form action={accion} className="flex flex-col gap-4">
      <input type="hidden" name="clubId" value={clubId} />

      <Field label="Correo">
        <Input name="email" type="email" required placeholder="recepcion@club.com" />
      </Field>

      <Field label="Nombre">
        <Input name="fullName" placeholder="María López" />
      </Field>

      <Field label="Papel" hint="El dueño podrá gestionar el club entero.">
        <Select name="role" defaultValue="staff">
          <option value="staff">Personal</option>
          <option value="owner">Dueño</option>
        </Select>
      </Field>

      {estado.error ? (
        <p role="alert" className="text-sm font-medium text-warn">
          {estado.error}
        </p>
      ) : null}

      {estado.creado ? (
        <div
          role="status"
          className="rounded-r border-l-[3px] border-l-ok bg-ok-soft px-4 py-3 text-sm"
        >
          <p className="font-semibold text-ok">Usuario creado</p>
          <p className="mt-1 text-ink-soft">
            Pásale estos datos. La contraseña no se vuelve a mostrar.
          </p>
          <p className="mt-2 font-mono text-sm break-all text-ink">
            {estado.creado.email}
            <br />
            {estado.creado.password}
          </p>
        </div>
      ) : null}

      <SubmitButton enCurso="Creando…">Crear usuario</SubmitButton>
    </form>
  );
}
