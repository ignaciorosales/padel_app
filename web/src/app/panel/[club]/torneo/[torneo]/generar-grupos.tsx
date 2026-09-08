"use client";

import { useActionState } from "react";
import { generarGrupos, type EstadoGeneracion } from "../../actions";
import { SubmitButton } from "@/components/submit-button";

const INICIAL: EstadoGeneracion = {};

export function GenerarGrupos({
  clubSlug,
  torneoSlug,
  parejas,
  grupos,
  yaHayJornadas,
  hayResultados,
}: {
  clubSlug: string;
  torneoSlug: string;
  parejas: number;
  grupos: number;
  yaHayJornadas: boolean;
  hayResultados: boolean;
}) {
  const [estado, accion] = useActionState(generarGrupos, INICIAL);

  const porGrupo = parejas > 0 ? Math.floor(parejas / Math.min(grupos, parejas)) : 0;

  return (
    <form
      action={accion}
      onSubmit={(event) => {
        if (!hayResultados) return;
        const seguro = window.confirm(
          "Regenerar borra las jornadas y TODOS los resultados metidos. ¿Seguro?",
        );
        if (!seguro) event.preventDefault();
      }}
      className="flex flex-col gap-2"
    >
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="torneoSlug" value={torneoSlug} />

      {parejas < 2 ? (
        <p className="text-sm text-ink-faint">
          Añade al menos 2 parejas para poder generar la fase de grupos.
        </p>
      ) : (
        <p className="text-sm text-ink-soft">
          {parejas} parejas en {Math.min(grupos, parejas)} grupo
          {Math.min(grupos, parejas) === 1 ? "" : "s"} de {porGrupo} o {porGrupo + 1}.
          Cada pareja juega contra todas las de su grupo.
        </p>
      )}

      {hayResultados ? (
        <p className="text-xs text-warn">
          Ya hay resultados metidos: regenerar los borra.
        </p>
      ) : null}

      {estado.error ? (
        <p role="alert" className="text-sm font-medium text-danger">
          {estado.error}
        </p>
      ) : null}

      <div>
        <SubmitButton enCurso="Generando…" disabled={parejas < 2}>
          {yaHayJornadas ? "Regenerar la fase de grupos" : "Generar la fase de grupos"}
        </SubmitButton>
      </div>
    </form>
  );
}
