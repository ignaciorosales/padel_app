"use client";

import { useRef } from "react";
import { actualizarDesempates } from "../../actions";
import { CRITERIOS, type Criterio } from "@/lib/torneo/clasificacion";

const CLAVES = Object.keys(CRITERIOS) as Criterio[];

/**
 * En qué orden se deshacen los empates.
 *
 * Tres desplegables en vez de una lista reordenable: el plan de producto
 * descarta arrastrar y soltar, y esto se toca desde el móvil. El segundo y el
 * tercero pueden quedarse vacíos — con un solo criterio, quien empate en él
 * comparte puesto, que es una respuesta legítima.
 *
 * Se puede cambiar con el torneo empezado: sólo reordena la tabla, no toca
 * ningún resultado. Es justo lo que hace falta cuando la discusión aparece a
 * mitad de la mañana.
 */
export function Desempates({
  clubSlug,
  torneoSlug,
  actuales,
  editable,
}: {
  clubSlug: string;
  torneoSlug: string;
  actuales: string[];
  editable: boolean;
}) {
  const form = useRef<HTMLFormElement>(null);

  if (!editable) {
    return (
      <p className="text-sm text-ink-soft">
        {actuales
          .map((c, i) => `${i + 1}. ${CRITERIOS[c as Criterio]?.texto ?? c}`)
          .join(" · ")}
      </p>
    );
  }

  return (
    <form ref={form} action={actualizarDesempates} className="flex flex-col gap-2">
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="torneoSlug" value={torneoSlug} />

      {[0, 1, 2].map((i) => (
        <label key={i} className="flex items-center gap-2 text-sm">
          <span className="w-5 shrink-0 font-mono text-xs text-ink-faint">
            {i + 1}.
          </span>
          <select
            name={`criterio${i + 1}`}
            defaultValue={actuales[i] ?? ""}
            onChange={() => form.current?.requestSubmit()}
            aria-label={`Criterio de desempate ${i + 1}`}
            className="min-w-0 flex-1 rounded-sm border border-rule-strong bg-surface px-2 py-1 text-sm text-ink"
          >
            {/* El primero es obligatorio: sin ningún criterio el orden sería
                arbitrario y la clasificación no significaría nada. */}
            {i > 0 ? <option value="">(ninguno)</option> : null}
            {CLAVES.map((c) => (
              <option key={c} value={c}>
                {CRITERIOS[c].texto}
              </option>
            ))}
          </select>
        </label>
      ))}
    </form>
  );
}
