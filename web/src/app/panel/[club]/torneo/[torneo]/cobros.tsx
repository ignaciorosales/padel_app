"use client";

import { useActionState } from "react";
import { cambiarPago, ponerImporte, type EstadoImportes } from "../../actions";
import { SubmitButton } from "@/components/submit-button";
import { euros } from "@/lib/torneo/cobros";

/**
 * El dinero de la inscripción, en la lista de inscritos y no en otra pantalla.
 *
 * El club apunta quién ha pagado mientras la gente llega, con la lista delante.
 * Una pestaña de «cobros» aparte obligaría a buscar dos veces a la misma
 * persona, y eso es exactamente lo que hoy hace bien el cuaderno.
 */

const INICIAL: EstadoImportes = {};

/** Un toque: cobrado / sin cobrar. */
export function BotonPago({
  clubSlug,
  torneoSlug,
  jugadorId,
  nombre,
  importe,
  pagado,
}: {
  clubSlug: string;
  torneoSlug: string;
  jugadorId: string;
  nombre: string;
  importe: number;
  pagado: boolean;
}) {
  return (
    <form action={cambiarPago}>
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="torneoSlug" value={torneoSlug} />
      <input type="hidden" name="jugadorId" value={jugadorId} />
      <input type="hidden" name="pagado" value={pagado ? "no" : "si"} />
      <button
        type="submit"
        aria-label={
          pagado
            ? `${nombre} ha pagado ${euros(importe)}. Marcar como no cobrado.`
            : `${nombre} debe ${euros(importe)}. Marcar como cobrado.`
        }
        className={`rounded-sm border px-2 py-0.5 font-mono text-xs tabular ${
          pagado
            ? "border-transparent bg-ok-soft text-ok"
            : "border-rule-strong text-ink-faint hover:border-ok hover:text-ok"
        }`}
      >
        {euros(importe)}
      </button>
    </form>
  );
}

/**
 * El precio para todos de una vez. Vaciarlo deja el torneo sin cobros.
 */
export function PrecioInscripcion({
  clubSlug,
  torneoSlug,
  actual,
}: {
  clubSlug: string;
  torneoSlug: string;
  actual: number | null;
}) {
  const [estado, accion] = useActionState(ponerImporte, INICIAL);

  return (
    <form action={accion} className="flex flex-col gap-2">
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="torneoSlug" value={torneoSlug} />

      <div className="flex items-center gap-2">
        <input
          name="importe"
          type="text"
          inputMode="decimal"
          defaultValue={actual === null ? "" : String(actual).replace(".", ",")}
          placeholder="12,50"
          aria-label="Precio de la inscripción"
          className="w-24 rounded-sm border border-rule-strong bg-surface px-2 py-1 font-mono text-xs text-ink tabular"
        />
        <SubmitButton enCurso="Poniendo…" variante="suave">
          Poner precio
        </SubmitButton>
      </div>

      <p className="text-xs text-ink-faint">
        Se lo pone a quien no tenga uno ya. Vaciarlo quita los cobros del torneo.
      </p>

      {estado.error ? (
        <p role="alert" className="text-xs font-medium text-danger">
          {estado.error}
        </p>
      ) : null}

      {estado.puestos !== undefined && !estado.error ? (
        <p role="status" className="text-xs font-medium text-ok">
          {estado.puestos === 0
            ? "Nadie estaba sin precio."
            : `Precio puesto a ${estado.puestos} inscrito${
                estado.puestos === 1 ? "" : "s"
              }.`}
        </p>
      ) : null}
    </form>
  );
}
