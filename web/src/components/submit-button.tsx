"use client";

import { useFormStatus } from "react-dom";
import { Button, type VarianteBoton } from "./ui";

export function SubmitButton({
  children,
  enCurso = "Guardando…",
  variante = "primario",
  className,
  disabled = false,
}: {
  children: React.ReactNode;
  enCurso?: string;
  variante?: VarianteBoton;
  className?: string;
  /** Para cuando aún faltan datos y enviar no tendría sentido. */
  disabled?: boolean;
}) {
  const { pending } = useFormStatus();

  return (
    <Button
      type="submit"
      variante={variante}
      className={className}
      disabled={pending || disabled}
    >
      {pending ? enCurso : children}
    </Button>
  );
}
