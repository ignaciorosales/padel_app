"use client";

import { useRef } from "react";
import { borrarTorneo, cambiarEstadoTorneo } from "../../actions";
import type { EstadoTorneo } from "@/lib/torneo/tipos";

const ESTADOS: { valor: EstadoTorneo; texto: string }[] = [
  { valor: "borrador", texto: "Borrador" },
  { valor: "en_juego", texto: "En juego" },
  { valor: "terminado", texto: "Terminado" },
];

export function AccionesTorneo({
  clubSlug,
  torneoSlug,
  estado,
  nombre,
}: {
  clubSlug: string;
  torneoSlug: string;
  estado: EstadoTorneo;
  nombre: string;
}) {
  const formEstado = useRef<HTMLFormElement>(null);

  return (
    <div className="flex flex-wrap items-center gap-4">
      <form ref={formEstado} action={cambiarEstadoTorneo}>
        <input type="hidden" name="clubSlug" value={clubSlug} />
        <input type="hidden" name="torneoSlug" value={torneoSlug} />
        <select
          name="estado"
          defaultValue={estado}
          onChange={() => formEstado.current?.requestSubmit()}
          aria-label="Estado del torneo"
          className="rounded-sm border border-rule-strong bg-surface px-2 py-1 text-sm text-ink"
        >
          {ESTADOS.map((e) => (
            <option key={e.valor} value={e.valor}>
              {e.texto}
            </option>
          ))}
        </select>
      </form>

      <form
        action={borrarTorneo}
        onSubmit={(event) => {
          const seguro = window.confirm(
            `Se borra «${nombre}» con sus rondas y resultados. No hay vuelta atrás. ¿Seguro?`,
          );
          if (!seguro) event.preventDefault();
        }}
      >
        <input type="hidden" name="clubSlug" value={clubSlug} />
        <input type="hidden" name="torneoSlug" value={torneoSlug} />
        <button
          type="submit"
          className="text-sm text-ink-faint underline-offset-4 hover:text-danger hover:underline"
        >
          Borrar torneo
        </button>
      </form>
    </div>
  );
}
