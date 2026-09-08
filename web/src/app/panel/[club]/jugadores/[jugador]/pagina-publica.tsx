"use client";

/**
 * El interruptor de la página pública, con el enlace al lado.
 *
 * Encendido y enlace van juntos a propósito: el enlace es para lo que se enciende,
 * y separarlos deja al club encendiendo algo sin ver qué acaba de publicar.
 *
 * El texto del botón dice lo que va a pasar, no el estado actual: "Encender" es
 * una acción, "Encendido" es una etiqueta, y confundirlas es como se apaga sin
 * querer lo que se quería dejar encendido.
 */

import { useActionState } from "react";
import { SubmitButton } from "@/components/submit-button";
import { CopiarTexto } from "@/components/copiar-texto";
import { cambiarPaginaPublica, type EstadoPublico } from "./actions";

const INICIAL: EstadoPublico = {};

export function PaginaPublica({
  clubSlug,
  personaId,
  encendida,
  nombre,
  editable,
}: {
  clubSlug: string;
  personaId: string;
  encendida: boolean;
  nombre: string;
  editable: boolean;
}) {
  const [estado, accion] = useActionState(cambiarPaginaPublica, INICIAL);

  // El origen sale del navegador y no de una variable de entorno: el panel se abre
  // en localhost, en la vista previa y en producción, y el enlace tiene que ser el
  // de donde estás mirando.
  const enlace =
    typeof window === "undefined" ? `/j/${personaId}` : `${window.location.origin}/j/${personaId}`;

  return (
    <div className="flex flex-col gap-3">
      <div>
        <p className="text-sm font-semibold text-ink">Página pública</p>
        <p className="mt-0.5 text-sm text-ink-soft">
          {encendida
            ? "Cualquiera con el enlace puede ver su rating, su división y sus logros. No se ven los nombres de las personas con las que ha jugado."
            : "Apagada. Un rating es un dato personal: se enciende cuando el jugador lo pide, no por defecto."}
        </p>
      </div>

      {encendida ? (
        <CopiarTexto
          texto={`${nombre} en Puntazo: ${enlace}`}
          etiqueta="Copiar el enlace"
          whatsapp
        />
      ) : null}

      {editable ? (
        <form action={accion} className="flex flex-wrap items-center gap-3">
          <input type="hidden" name="clubSlug" value={clubSlug} />
          <input type="hidden" name="personaId" value={personaId} />
          <input type="hidden" name="encender" value={encendida ? "no" : "si"} />

          <SubmitButton
            variante={encendida ? "peligro" : "primario"}
            enCurso="Cambiando…"
            className="!px-3 !py-1.5 !text-sm"
          >
            {encendida ? "Apagar la página" : "Encender la página"}
          </SubmitButton>

          {estado.error ? <span className="text-sm text-danger">{estado.error}</span> : null}
          {estado.hecho ? <span className="text-sm text-ok">{estado.hecho}</span> : null}
        </form>
      ) : null}
    </div>
  );
}
