"use client";

import { useState } from "react";
import { guardarResultado } from "../../actions";

export function ResultadoForm({
  clubSlug,
  torneoSlug,
  partidoId,
  juegosA,
  juegosB,
  bloqueado,
}: {
  clubSlug: string;
  torneoSlug: string;
  partidoId: string;
  juegosA: number | null;
  juegosB: number | null;
  bloqueado: boolean;
}) {
  const inicialA = juegosA?.toString() ?? "";
  const inicialB = juegosB?.toString() ?? "";
  const [a, setA] = useState(inicialA);
  const [b, setB] = useState(inicialB);

  const cambiado = a !== inicialA || b !== inicialB;

  const claseCasilla =
    "w-12 rounded-sm border border-rule-strong bg-surface px-2 py-1 text-center tabular text-ink disabled:opacity-60";

  return (
    <form action={guardarResultado} className="flex items-center gap-2">
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="torneoSlug" value={torneoSlug} />
      <input type="hidden" name="partidoId" value={partidoId} />

      <input
        name="juegos_a"
        inputMode="numeric"
        value={a}
        onChange={(e) => setA(e.target.value.replace(/\D/g, "").slice(0, 2))}
        disabled={bloqueado}
        aria-label="Juegos del primer equipo"
        className={claseCasilla}
      />
      <span className="text-ink-faint">–</span>
      <input
        name="juegos_b"
        inputMode="numeric"
        value={b}
        onChange={(e) => setB(e.target.value.replace(/\D/g, "").slice(0, 2))}
        disabled={bloqueado}
        aria-label="Juegos del segundo equipo"
        className={claseCasilla}
      />

      {cambiado && !bloqueado ? (
        <button
          type="submit"
          className="rounded-sm bg-accent px-3 py-1 text-sm font-semibold text-white hover:bg-accent-ink"
        >
          Guardar
        </button>
      ) : null}
    </form>
  );
}
