"use client";

import { useActionState } from "react";
import { generarRondas, type EstadoGeneracion } from "../../actions";
import { SubmitButton } from "@/components/submit-button";

const INICIAL: EstadoGeneracion = {};

export function GenerarRondas({
  clubSlug,
  torneoSlug,
  inscritos,
  yaHayRondas,
  hayResultados,
}: {
  clubSlug: string;
  torneoSlug: string;
  inscritos: number;
  yaHayRondas: boolean;
  hayResultados: boolean;
}) {
  const [estado, accion] = useActionState(generarRondas, INICIAL);
  const suficientes = inscritos >= 4;

  function confirmarSiHaceFalta(event: React.FormEvent<HTMLFormElement>) {
    if (!yaHayRondas) return;

    const mensaje = hayResultados
      ? "Se van a borrar las rondas actuales Y LOS RESULTADOS ya metidos. ¿Seguro?"
      : "Se van a reemplazar las rondas actuales por unas nuevas. ¿Seguro?";

    if (!window.confirm(mensaje)) event.preventDefault();
  }

  return (
    <form action={accion} onSubmit={confirmarSiHaceFalta} className="flex flex-col gap-3">
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="torneoSlug" value={torneoSlug} />

      {!suficientes ? (
        <p className="text-sm text-ink-faint">
          Con {inscritos} inscrito{inscritos === 1 ? "" : "s"} no se puede montar un
          partido. Hacen falta 4 como mínimo.
        </p>
      ) : null}

      {estado.error ? (
        <p role="alert" className="text-sm font-medium text-danger">
          {estado.error}
        </p>
      ) : null}

      <div>
        <SubmitButton
          enCurso="Generando…"
          variante={yaHayRondas ? "suave" : "primario"}
          className={suficientes ? "" : "pointer-events-none opacity-50"}
        >
          {yaHayRondas ? "Regenerar rondas" : "Generar rondas"}
        </SubmitButton>
      </div>
    </form>
  );
}
