"use client";

import { useActionState } from "react";
import { iniciarSesion, type EstadoLogin } from "./actions";
import { SubmitButton } from "@/components/submit-button";
import { Field, Input } from "@/components/ui";

const INICIAL: EstadoLogin = {};

export function LoginForm({ volver }: { volver: string }) {
  const [estado, accion] = useActionState(iniciarSesion, INICIAL);

  return (
    <form action={accion} className="flex flex-col gap-4">
      <input type="hidden" name="volver" value={volver} />

      <Field label="Correo">
        <Input
          name="email"
          type="email"
          autoComplete="username"
          required
          autoFocus
          placeholder="recepcion@tuclub.com"
        />
      </Field>

      <Field label="Contraseña">
        <Input name="password" type="password" autoComplete="current-password" required />
      </Field>

      {estado.error ? (
        <p role="alert" className="text-sm font-medium text-danger">
          {estado.error}
        </p>
      ) : null}

      <SubmitButton enCurso="Entrando…" className="mt-1 w-full">
        Entrar
      </SubmitButton>
    </form>
  );
}
