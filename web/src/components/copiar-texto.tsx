"use client";

import { useRef, useState } from "react";

/**
 * Copiar al portapapeles, o abrir WhatsApp con el texto ya escrito.
 *
 * El portapapeles falla sin https y en algunos navegadores empotrados, y falla
 * justo el día que se usa. Cuando pasa, en vez de un error se cae a un
 * `<textarea>` con el texto seleccionado: un Ctrl+C (o «Copiar» del menú largo
 * en móvil) lo resuelve sin que nadie tenga que entender qué ha ido mal.
 */
export function CopiarTexto({
  texto,
  etiqueta = "Copiar",
  whatsapp = false,
}: {
  texto: string;
  etiqueta?: string;
  whatsapp?: boolean;
}) {
  const [copiado, setCopiado] = useState(false);
  const [alDescubierto, setAlDescubierto] = useState(false);
  const area = useRef<HTMLTextAreaElement>(null);

  async function copiar() {
    try {
      await navigator.clipboard.writeText(texto);
      setCopiado(true);
      setTimeout(() => setCopiado(false), 2000);
    } catch {
      setAlDescubierto(true);
      // El textarea aún no está pintado en este tick.
      setTimeout(() => area.current?.select(), 0);
    }
  }

  return (
    <div className="print:hidden">
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={copiar}
          className="text-xs font-semibold text-accent-ink underline-offset-4 hover:underline"
        >
          {copiado ? "Copiado" : etiqueta}
        </button>

        {whatsapp ? (
          <a
            href={`https://wa.me/?text=${encodeURIComponent(texto)}`}
            target="_blank"
            rel="noopener noreferrer"
            className="text-xs text-ink-faint underline-offset-4 hover:text-ink hover:underline"
          >
            WhatsApp
          </a>
        ) : null}
      </div>

      {alDescubierto ? (
        <textarea
          ref={area}
          readOnly
          value={texto}
          rows={5}
          aria-label="Texto para copiar a mano"
          onFocus={(e) => e.currentTarget.select()}
          className="mt-2 w-full rounded-sm border border-rule-strong bg-surface-alt p-2 font-mono text-xs text-ink-soft"
        />
      ) : null}
    </div>
  );
}
