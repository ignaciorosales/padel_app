"use client";

import { useActionState, useState } from "react";
import { borrarClub, type EstadoBorrado } from "../actions";
import { SubmitButton } from "@/components/submit-button";
import { Input } from "@/components/ui";

const INICIAL: EstadoBorrado = {};

export function BorrarClub({
  clubId,
  slug,
  usuarios,
}: {
  clubId: string;
  slug: string;
  usuarios: number;
}) {
  const [estado, accion] = useActionState(borrarClub, INICIAL);
  const [escrito, setEscrito] = useState("");

  const coincide = escrito.trim().toLowerCase() === slug;

  return (
    // Cerrado va discreto: sólo se pone rojo cuando lo abres a propósito.
    <details className="group rounded border border-rule open:border-danger/40 open:bg-danger-soft/40">
      <summary
        className="flex cursor-pointer list-none items-center gap-2 px-5 py-3 text-sm text-ink-faint group-open:pb-1 group-open:font-semibold group-open:text-danger [&::-webkit-details-marker]:hidden"
      >
        <span
          aria-hidden="true"
          className="inline-block transition-transform group-open:rotate-90"
        >
          ▸
        </span>
        Borrar este club
      </summary>

      <div className="px-5 pb-5">
        <p className="mt-2 max-w-[60ch] text-sm text-ink-soft">
          Desaparece para siempre, junto con{" "}
          {usuarios === 0
            ? "sus accesos"
            : `el acceso de ${usuarios} usuario${usuarios === 1 ? "" : "s"}`}{" "}
          y todos sus torneos. No hay papelera.
        </p>

        <p className="mt-2 max-w-[60ch] text-sm text-ink-soft">
          Si sólo quieres que dejen de usarlo porque no han pagado,{" "}
          <strong className="text-ink">suspéndelo</strong> en vez de borrarlo: es
          reversible y conserva sus datos.
        </p>

        <form action={accion} className="mt-4 flex flex-wrap items-end gap-3">
          <input type="hidden" name="clubId" value={clubId} />

          <label className="block">
            <span className="mb-1.5 block text-sm font-semibold text-ink">
              Escribe <code className="font-mono text-danger">{slug}</code> para
              confirmar
            </span>
            <Input
              name="confirmacion"
              value={escrito}
              onChange={(e) => setEscrito(e.target.value)}
              autoComplete="off"
              spellCheck={false}
              aria-label={`Escribe ${slug} para confirmar el borrado`}
              className="w-64"
            />
          </label>

          <SubmitButton
            variante="peligro"
            enCurso="Borrando…"
            className={coincide ? "" : "pointer-events-none opacity-50"}
          >
            Borrar el club
          </SubmitButton>
        </form>

        {estado.error ? (
          <p role="alert" className="mt-3 text-sm font-medium text-danger">
            {estado.error}
          </p>
        ) : null}
      </div>
    </details>
  );
}
