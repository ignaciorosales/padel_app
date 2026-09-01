"use client";

/**
 * Ctrl+P existe, pero el encargado del club no lo va a descubrir el sábado a
 * las diez con 24 personas esperando. La hoja de estilos de impresión está en
 * globals.css: aquí sólo hace falta el botón.
 */
export function BotonImprimir({ children = "Imprimir" }: { children?: string }) {
  return (
    <button
      type="button"
      onClick={() => window.print()}
      className="text-xs font-semibold text-accent-ink underline-offset-4 hover:underline print:hidden"
    >
      {children}
    </button>
  );
}
