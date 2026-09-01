"use client";

import { useActionState, useState } from "react";
import { anadirParejas, type EstadoParejas } from "../../actions";
import { SubmitButton } from "@/components/submit-button";
import { parsearParejas } from "@/lib/torneo/lista";

const INICIAL: EstadoParejas = {};

/**
 * Inscribir parejas pegando la lista, una por línea.
 *
 * La diferencia con la de jugadores sueltos es que aquí **las líneas malas se
 * enseñan**. En una lista de nombres, descartar uno raro casi siempre acierta;
 * en una de parejas, una línea sin compañero es una pareja entera que se queda
 * fuera del cuadro y nadie lo nota hasta el sábado.
 */
export function ParejasForm({
  clubSlug,
  torneoSlug,
}: {
  clubSlug: string;
  torneoSlug: string;
}) {
  const [estado, accion] = useActionState(anadirParejas, INICIAL);
  const [texto, setTexto] = useState("");

  // El mismo parseo que hará el servidor, para verlo antes de guardar.
  const { parejas, problemas } = parsearParejas(texto);

  return (
    <form action={accion} className="flex flex-col gap-3">
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="torneoSlug" value={torneoSlug} />

      <label className="block">
        <span className="mb-1.5 block text-sm font-semibold text-ink">
          Pega las parejas, una por línea
        </span>
        <textarea
          name="lista"
          rows={8}
          value={texto}
          onChange={(e) => setTexto(e.target.value)}
          placeholder={"Ana Ruiz / Luis Gómez\nMarta y Pedro\nSara + Iván\n4. Nuria - Toni"}
          className="w-full rounded-sm border border-rule-strong bg-surface px-3 py-2 font-mono text-sm text-ink placeholder:text-ink-faint"
        />
        <span className="mt-1.5 block text-xs text-ink-faint">
          Separa los dos nombres con «/», «y», «+» o un guion. Vale numerada y
          con viñetas.
        </span>
      </label>

      {texto.trim() ? (
        <div className="rounded-sm border border-rule bg-surface-alt px-3 py-2 text-sm">
          {parejas.length === 0 ? (
            <span className="text-ink-faint">No he encontrado ninguna pareja.</span>
          ) : (
            <>
              <p className="font-semibold text-ink">
                {parejas.length} pareja{parejas.length === 1 ? "" : "s"} detectada
                {parejas.length === 1 ? "" : "s"}
              </p>
              <ul className="mt-1 text-ink-soft">
                {parejas.map((p, i) => (
                  <li key={i}>
                    {p.uno} / {p.dos}
                  </li>
                ))}
              </ul>
            </>
          )}

          {problemas.length > 0 ? (
            <div className="mt-3 border-t border-rule pt-2">
              <p className="font-semibold text-warn">
                {problemas.length} línea{problemas.length === 1 ? "" : "s"} sin leer
              </p>
              <ul className="mt-1 flex flex-col gap-0.5 text-xs text-warn">
                {problemas.map((p, i) => (
                  <li key={i}>
                    <span className="font-mono">{p.linea}</span> — {p.motivo}
                  </li>
                ))}
              </ul>
            </div>
          ) : null}
        </div>
      ) : null}

      {estado.error ? (
        <p role="alert" className="text-sm font-medium text-danger">
          {estado.error}
        </p>
      ) : null}

      {estado.anadidas ? (
        <p role="status" className="text-sm font-medium text-ok">
          {estado.anadidas} pareja{estado.anadidas === 1 ? "" : "s"} añadida
          {estado.anadidas === 1 ? "" : "s"}.
        </p>
      ) : null}

      {estado.problemas && estado.problemas.length > 0 ? (
        <ul className="flex flex-col gap-0.5 text-xs text-warn">
          {estado.problemas.map((p, i) => (
            <li key={i}>
              <span className="font-mono">{p.linea}</span> — {p.motivo}
            </li>
          ))}
        </ul>
      ) : null}

      <div>
        <SubmitButton enCurso="Añadiendo…">
          {parejas.length > 0 ? `Añadir ${parejas.length}` : "Añadir"}
        </SubmitButton>
      </div>
    </form>
  );
}
