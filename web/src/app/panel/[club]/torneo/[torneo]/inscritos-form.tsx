"use client";

import { useActionState, useState } from "react";
import { anadirInscritos, type EstadoInscritos } from "../../actions";
import { SubmitButton } from "@/components/submit-button";
import { parsearLista } from "@/lib/torneo/lista";

const INICIAL: EstadoInscritos = {};

export function InscritosForm({
  clubSlug,
  torneoSlug,
}: {
  clubSlug: string;
  torneoSlug: string;
}) {
  const [estado, accion] = useActionState(anadirInscritos, INICIAL);
  const [texto, setTexto] = useState("");

  // El mismo parseo que hará el servidor, para que se vea antes de guardar.
  const detectados = parsearLista(texto);

  return (
    <form action={accion} className="flex flex-col gap-3">
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="torneoSlug" value={torneoSlug} />

      <label className="block">
        <span className="mb-1.5 block text-sm font-semibold text-ink">
          Pega la lista
        </span>
        <textarea
          name="lista"
          rows={8}
          value={texto}
          onChange={(e) => setTexto(e.target.value)}
          placeholder={"Juan Pérez 600123456\nAna López\n3. Luis\n- Marta"}
          className="w-full rounded-sm border border-rule-strong bg-surface px-3 py-2 font-mono text-sm text-ink placeholder:text-ink-faint"
        />
        <span className="mt-1.5 block text-xs text-ink-faint">
          Vale tal cual sale del grupo: numerada, con guiones, con teléfonos o
          separada por comas. Los repetidos se descartan solos.
        </span>
      </label>

      {texto.trim() ? (
        <div className="rounded-sm border border-rule bg-surface-alt px-3 py-2 text-sm">
          {detectados.length === 0 ? (
            <span className="text-ink-faint">No he encontrado ningún nombre.</span>
          ) : (
            <>
              <p className="font-semibold text-ink">
                {detectados.length} nombre{detectados.length === 1 ? "" : "s"} detectado
                {detectados.length === 1 ? "" : "s"}
              </p>
              <p className="mt-1 text-ink-soft">
                {detectados.map((j) => j.nombre).join(" · ")}
              </p>
            </>
          )}
        </div>
      ) : null}

      {estado.error ? (
        <p role="alert" className="text-sm font-medium text-danger">
          {estado.error}
        </p>
      ) : null}

      {estado.anadidos ? (
        <p role="status" className="text-sm font-medium text-ok">
          {estado.anadidos} inscrito{estado.anadidos === 1 ? "" : "s"} añadido
          {estado.anadidos === 1 ? "" : "s"}.
        </p>
      ) : null}

      <div>
        <SubmitButton enCurso="Añadiendo…">
          {detectados.length > 0 ? `Añadir ${detectados.length}` : "Añadir"}
        </SubmitButton>
      </div>
    </form>
  );
}
