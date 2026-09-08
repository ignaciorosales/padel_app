"use client";

/**
 * Los tres controles de la pantalla de unificación.
 *
 * Todo lo que se ve aquí obedece a la misma idea: **el club confirma, no
 * teclea.** El parecido ya está calculado y el motivo ya está escrito; lo único
 * que hace falta es un botón por candidato y que el motivo esté al lado del
 * botón, no escondido en un desplegable. Un número a secas —"0,82"— no se
 * confirma con confianza; "mismo teléfono · el apellido encaja con la inicial"
 * sí.
 */

import { useActionState, useState } from "react";
import { SubmitButton } from "@/components/submit-button";
import { Button, Field, Input } from "@/components/ui";
import {
  crearPersonaConInscritos,
  separarInscrito,
  unificarInscrito,
  type EstadoUnificar,
} from "./actions";
import type { Candidato } from "@/lib/identidad/panel";

const INICIAL: EstadoUnificar = {};

function Error({ estado }: { estado: EstadoUnificar }) {
  if (!estado.error) return null;
  return <p className="mt-1.5 text-sm text-danger">{estado.error}</p>;
}

/**
 * Un candidato, un botón, y su propio formulario.
 *
 * Un formulario por botón en lugar de uno con varios `submit` con `value`: así el
 * `personaId` va en un campo oculto y no depende de qué botón se pulsó, que es
 * frágil y se rompe con el primer `Enter` en el teclado.
 */
export function BotonCandidato({
  clubSlug,
  inscritoId,
  candidato,
  nombre,
  destacado,
}: {
  clubSlug: string;
  inscritoId: string;
  candidato: Candidato;
  nombre: string;
  destacado: boolean;
}) {
  const [estado, accion] = useActionState(unificarInscrito, INICIAL);

  return (
    <form action={accion} className="flex flex-col gap-1">
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="inscritoId" value={inscritoId} />
      <input type="hidden" name="personaId" value={candidato.personaId} />

      <SubmitButton
        variante={destacado ? "primario" : "suave"}
        enCurso="Uniendo…"
        className="!px-3 !py-1.5 !text-sm"
      >
        Es {nombre}
      </SubmitButton>

      <span className="text-xs text-ink-faint">{candidato.motivos.join(" · ")}</span>

      <Error estado={estado} />
    </form>
  );
}

/**
 * Crear una persona nueva a partir de uno o varios inscritos.
 *
 * El nombre viene puesto con el más largo del grupo —entre "Nacho R." e "Ignacio
 * Rosales", la ficha se crea con el segundo— y es editable, porque el encargado
 * sabe cómo se llama de verdad y el algoritmo no.
 */
export function CrearPersona({
  clubSlug,
  inscritoIds,
  nombrePropuesto,
  etiqueta = "Crear persona",
}: {
  clubSlug: string;
  inscritoIds: string[];
  nombrePropuesto: string;
  etiqueta?: string;
}) {
  const [estado, accion] = useActionState(crearPersonaConInscritos, INICIAL);
  const [abierto, setAbierto] = useState(false);

  if (!abierto) {
    return (
      <div className="flex flex-col gap-1">
        <Button variante="suave" className="!px-3 !py-1.5 !text-sm" onClick={() => setAbierto(true)}>
          {etiqueta}
        </Button>
        <Error estado={estado} />
      </div>
    );
  }

  return (
    <form action={accion} className="flex w-full max-w-md flex-col gap-3">
      <input type="hidden" name="clubSlug" value={clubSlug} />
      {inscritoIds.map((id) => (
        <input key={id} type="hidden" name="inscritoId" value={id} />
      ))}

      <Field
        label="Nombre y apellidos"
        hint="La primera palabra es el nombre; el resto, apellidos."
      >
        <Input name="nombre" defaultValue={nombrePropuesto} required autoFocus />
      </Field>

      <div className="grid gap-3 sm:grid-cols-2">
        <Field label="Apodo" hint="Cómo le llaman en el club. Opcional.">
          <Input name="apodo" placeholder="Nacho" />
        </Field>
        <Field label="Teléfono" hint="Es la llave con la que reclamará su ficha.">
          <Input name="telefono" inputMode="tel" placeholder="600123456" />
        </Field>
      </div>

      <div className="flex items-center gap-2">
        <SubmitButton enCurso="Creando…">
          Crear
          {inscritoIds.length > 1 ? ` y unir ${inscritoIds.length} nombres` : ""}
        </SubmitButton>
        <Button variante="suave" type="button" onClick={() => setAbierto(false)}>
          Cancelar
        </Button>
      </div>

      <Error estado={estado} />
    </form>
  );
}

/** Deshacer una unificación. Sin confirmación: es la acción reversible. */
export function Separar({
  clubSlug,
  inscritoId,
}: {
  clubSlug: string;
  inscritoId: string;
}) {
  const [estado, accion] = useActionState(separarInscrito, INICIAL);

  return (
    <form action={accion}>
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="inscritoId" value={inscritoId} />
      <SubmitButton variante="suave" enCurso="Separando…" className="!px-2 !py-1 !text-xs">
        Separar
      </SubmitButton>
      <Error estado={estado} />
    </form>
  );
}
