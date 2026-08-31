"use client";

import { useFormStatus } from "react-dom";
import { Button, type VarianteBoton } from "./ui";

export function SubmitButton({
  children,
  enCurso = "Guardando…",
  variante = "primario",
  className,
}: {
  children: React.ReactNode;
  enCurso?: string;
  variante?: VarianteBoton;
  className?: string;
}) {
  const { pending } = useFormStatus();

  return (
    <Button type="submit" variante={variante} className={className} disabled={pending}>
      {pending ? enCurso : children}
    </Button>
  );
}
