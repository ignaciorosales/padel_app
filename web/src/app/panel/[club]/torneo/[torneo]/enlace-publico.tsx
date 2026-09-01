"use client";

import { useRef, useState } from "react";
import { cambiarVisibilidad } from "../../actions";

/**
 * El enlace que el club pega en el grupo de WhatsApp.
 *
 * La URL entera llega ya hecha desde el servidor (ver lib/url.ts). Componerla
 * aquí con `window.location.origin` obligaría a un efecto, y el primer render
 * saldría con el campo vacío: justo el momento en que el organizador va a
 * copiarlo con prisa.
 */
export function EnlacePublico({
  clubSlug,
  torneoSlug,
  nombre,
  url,
  publico,
  editable,
}: {
  clubSlug: string;
  torneoSlug: string;
  nombre: string;
  url: string;
  publico: boolean;
  editable: boolean;
}) {
  const [copiado, setCopiado] = useState(false);
  const formVisibilidad = useRef<HTMLFormElement>(null);
  const campo = useRef<HTMLInputElement>(null);

  const ruta = `/t/${clubSlug}/${torneoSlug}`;

  async function copiar() {
    try {
      await navigator.clipboard.writeText(url);
      setCopiado(true);
      setTimeout(() => setCopiado(false), 2000);
    } catch {
      // Sin permiso de portapapeles (o sin https): al menos dejarlo
      // seleccionado para que un Ctrl+C lo resuelva.
      campo.current?.select();
    }
  }

  if (!publico) {
    return (
      <div>
        <p className="text-sm text-ink-soft">
          La página pública está retirada. Quien tenga el enlace no ve nada.
        </p>
        {editable ? (
          <form ref={formVisibilidad} action={cambiarVisibilidad} className="mt-3">
            <input type="hidden" name="clubSlug" value={clubSlug} />
            <input type="hidden" name="torneoSlug" value={torneoSlug} />
            <input type="hidden" name="publico" value="si" />
            <button
              type="submit"
              className="text-sm font-semibold text-accent-ink underline-offset-4 hover:underline"
            >
              Publicar la página
            </button>
          </form>
        ) : null}
      </div>
    );
  }

  return (
    <div>
      <div className="flex gap-2">
        <input
          ref={campo}
          readOnly
          value={url}
          aria-label="Enlace público del torneo"
          onFocus={(e) => e.currentTarget.select()}
          className="min-w-0 flex-1 rounded-sm border border-rule-strong bg-surface-alt px-2 py-1.5 font-mono text-xs text-ink-soft"
        />
        <button
          type="button"
          onClick={copiar}
          className="shrink-0 rounded-sm border border-rule-strong bg-surface px-3 py-1.5 text-sm font-semibold text-ink hover:bg-surface-alt"
        >
          {copiado ? "Copiado" : "Copiar"}
        </button>
      </div>

      <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2 text-sm">
        <a
          href={`https://wa.me/?text=${encodeURIComponent(`${nombre}\n${url}`)}`}
          target="_blank"
          rel="noopener noreferrer"
          className="font-semibold text-accent-ink underline-offset-4 hover:underline"
        >
          Enviar por WhatsApp
        </a>
        <a
          href={ruta}
          target="_blank"
          rel="noopener noreferrer"
          className="text-ink-soft underline-offset-4 hover:underline"
        >
          Ver la página
        </a>
      </div>

      {editable ? (
        <form ref={formVisibilidad} action={cambiarVisibilidad} className="mt-3">
          <input type="hidden" name="clubSlug" value={clubSlug} />
          <input type="hidden" name="torneoSlug" value={torneoSlug} />
          <input type="hidden" name="publico" value="no" />
          <button
            type="submit"
            className="text-xs text-ink-faint underline-offset-4 hover:text-danger hover:underline"
          >
            Retirar la página pública
          </button>
        </form>
      ) : null}
    </div>
  );
}
