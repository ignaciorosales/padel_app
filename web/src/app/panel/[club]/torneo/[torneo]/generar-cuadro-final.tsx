"use client";

import { useActionState } from "react";
import { generarCuadroFinal, type EstadoGeneracion } from "../../actions";
import { SubmitButton } from "@/components/submit-button";

const INICIAL: EstadoGeneracion = {};

/**
 * El cuadro se genera cuando el club dice, no automáticamente al cerrarse el
 * último resultado de grupos: a veces falta una pareja por llegar, o hay que
 * repetir un partido. Que lo decida una persona evita que el cuadro salga solo
 * en mitad de una discusión.
 */
export function GenerarCuadroFinal({
  clubSlug,
  torneoSlug,
  clasificados,
  gruposCompletos,
  yaHayCuadro,
}: {
  clubSlug: string;
  torneoSlug: string;
  clasificados: number;
  gruposCompletos: boolean;
  yaHayCuadro: boolean;
}) {
  const [estado, accion] = useActionState(generarCuadroFinal, INICIAL);

  return (
    <form
      action={accion}
      onSubmit={(event) => {
        if (!yaHayCuadro) return;
        const seguro = window.confirm(
          "Regenerar el cuadro borra los resultados del cuadro. La fase de grupos no se toca. ¿Seguro?",
        );
        if (!seguro) event.preventDefault();
      }}
      className="flex flex-col gap-2"
    >
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="torneoSlug" value={torneoSlug} />

      <p className="text-sm text-ink-soft">
        Pasan {clasificados} pareja{clasificados === 1 ? "" : "s"} al cuadro.
      </p>

      {!gruposCompletos ? (
        <p className="text-xs text-warn">
          Quedan partidos de grupos sin resultado. Se puede generar igual, pero
          la clasificación todavía puede cambiar.
        </p>
      ) : null}

      {estado.error ? (
        <p role="alert" className="text-sm font-medium text-danger">
          {estado.error}
        </p>
      ) : null}

      <div>
        <SubmitButton enCurso="Generando…" disabled={clasificados < 2}>
          {yaHayCuadro ? "Regenerar el cuadro" : "Generar el cuadro"}
        </SubmitButton>
      </div>
    </form>
  );
}
