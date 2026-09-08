"use client";

/**
 * Los controles de la pantalla de nivel.
 *
 * El formulario de restricción enseña el cartel mientras se escribe —"Sólo 4ª y
 * 5ª, rating desde 1500"— y es a propósito: es como se descubre que se ha puesto
 * el mínimo y el máximo al revés, antes de guardar y no cuando alguien se queja.
 */

import { useActionState, useState } from "react";
import { SubmitButton } from "@/components/submit-button";
import { Button, Field, Input } from "@/components/ui";
import { describirRestriccion } from "@/lib/torneo/admision";
import { cambiarExcepcion, guardarRestriccion, type EstadoNivel } from "./actions";

const INICIAL: EstadoNivel = {};

function Mensaje({ estado }: { estado: EstadoNivel }) {
  if (estado.error) return <p className="text-sm text-danger">{estado.error}</p>;
  if (estado.hecho) return <p className="text-sm text-ok">{estado.hecho}</p>;
  return null;
}

export function RestriccionForm({
  clubSlug,
  torneoSlug,
  divisiones,
  ratingMinimo,
  ratingMaximo,
  admitidas,
  editable,
}: {
  clubSlug: string;
  torneoSlug: string;
  /** Todas las de la escala, de la más alta a la más baja. */
  divisiones: string[];
  ratingMinimo: number | null;
  ratingMaximo: number | null;
  admitidas: string[];
  editable: boolean;
}) {
  const [estado, accion] = useActionState(guardarRestriccion, INICIAL);

  const [minimo, setMinimo] = useState(ratingMinimo === null ? "" : String(ratingMinimo));
  const [maximo, setMaximo] = useState(ratingMaximo === null ? "" : String(ratingMaximo));
  const [elegidas, setElegidas] = useState<string[]>(admitidas);

  const alternar = (division: string) => {
    setElegidas((previas) =>
      previas.includes(division)
        ? previas.filter((d) => d !== division)
        : [...previas, division],
    );
  };

  // El mismo texto que verá la página pública, calculado con la misma función.
  const numero = (texto: string) => {
    const n = Number.parseInt(texto.trim(), 10);
    return Number.isFinite(n) ? n : null;
  };

  const cartel = describirRestriccion({
    ratingMinimo: numero(minimo),
    ratingMaximo: numero(maximo),
    // En el orden de la escala, no en el de los clics.
    divisionesAdmitidas: divisiones.filter((d) => elegidas.includes(d)),
  });

  const alRevés = numero(minimo) !== null && numero(maximo) !== null && numero(minimo)! > numero(maximo)!;

  return (
    <form action={accion} className="flex flex-col gap-4">
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="torneoSlug" value={torneoSlug} />
      {elegidas.map((d) => (
        <input key={d} type="hidden" name="division" value={d} />
      ))}

      <div>
        <span className="mb-1.5 block text-sm font-semibold text-ink">Divisiones</span>
        <div className="flex flex-wrap gap-2">
          {divisiones.map((division) => (
            <button
              key={division}
              type="button"
              disabled={!editable}
              onClick={() => alternar(division)}
              className={`rounded-sm px-2.5 py-1 font-mono text-xs ${
                elegidas.includes(division)
                  ? "bg-accent text-white"
                  : "border border-rule-strong bg-surface text-ink-soft hover:bg-surface-alt"
              } disabled:opacity-50`}
            >
              {division}
            </button>
          ))}
        </div>
        <span className="mt-1.5 block text-xs text-ink-faint">
          Ninguna marcada es «cualquier división», que es lo normal.
        </span>
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        <Field label="Rating mínimo" hint="Vacío es sin mínimo.">
          <Input
            name="rating_minimo"
            inputMode="numeric"
            value={minimo}
            disabled={!editable}
            onChange={(e) => setMinimo(e.target.value)}
            placeholder="1450"
          />
        </Field>
        <Field label="Rating máximo" hint="Vacío es sin máximo.">
          <Input
            name="rating_maximo"
            inputMode="numeric"
            value={maximo}
            disabled={!editable}
            onChange={(e) => setMaximo(e.target.value)}
            placeholder="1750"
          />
        </Field>
      </div>

      <div className="rounded-sm border border-rule bg-surface-alt px-3 py-2">
        <p className="text-xs text-ink-faint">Así se contará el torneo:</p>
        <p className="mt-0.5 text-sm font-semibold text-ink">{cartel}</p>
        {alRevés ? (
          <p className="mt-1 text-sm text-danger">
            El mínimo es mayor que el máximo: así no entraría nadie.
          </p>
        ) : null}
      </div>

      {editable ? (
        <div className="flex items-center gap-3">
          <SubmitButton disabled={alRevés}>Guardar</SubmitButton>
          <Mensaje estado={estado} />
        </div>
      ) : (
        <Mensaje estado={estado} />
      )}
    </form>
  );
}

/**
 * Aprobar o retirar la excepción de un inscrito.
 *
 * El motivo se pide al aprobar, no después: un torneo de cuarta con seis
 * excepciones sin explicar no es un torneo de cuarta, y el momento en que el
 * organizador sabe por qué la aprueba es justo ése.
 */
export function ExcepcionForm({
  clubSlug,
  torneoSlug,
  inscritoId,
  aprobada,
  motivo,
}: {
  clubSlug: string;
  torneoSlug: string;
  inscritoId: string;
  aprobada: boolean;
  motivo: string | null;
}) {
  const [estado, accion] = useActionState(cambiarExcepcion, INICIAL);
  const [abierto, setAbierto] = useState(false);

  if (aprobada) {
    return (
      <form action={accion} className="flex flex-col items-end gap-1">
        <input type="hidden" name="clubSlug" value={clubSlug} />
        <input type="hidden" name="torneoSlug" value={torneoSlug} />
        <input type="hidden" name="inscritoId" value={inscritoId} />
        <input type="hidden" name="aprobar" value="no" />
        {motivo ? (
          <span className="text-xs text-ink-faint italic">«{motivo}»</span>
        ) : null}
        <SubmitButton variante="suave" enCurso="Retirando…" className="!px-2 !py-1 !text-xs">
          Retirar excepción
        </SubmitButton>
        <Mensaje estado={estado} />
      </form>
    );
  }

  if (!abierto) {
    return (
      <div className="flex flex-col items-end gap-1">
        <Button
          variante="suave"
          className="!px-2 !py-1 !text-xs"
          onClick={() => setAbierto(true)}
        >
          Dejarle entrar
        </Button>
        <Mensaje estado={estado} />
      </div>
    );
  }

  return (
    <form action={accion} className="flex w-full max-w-xs flex-col gap-2">
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="torneoSlug" value={torneoSlug} />
      <input type="hidden" name="inscritoId" value={inscritoId} />
      <input type="hidden" name="aprobar" value="si" />

      <Field label="Por qué" hint="Queda escrito en el torneo.">
        <Input name="motivo" placeholder="Completa la pareja de Ana" autoFocus />
      </Field>

      <div className="flex items-center gap-2">
        <SubmitButton enCurso="Aprobando…" className="!px-2 !py-1 !text-xs">
          Aprobar
        </SubmitButton>
        <Button
          variante="suave"
          type="button"
          className="!px-2 !py-1 !text-xs"
          onClick={() => setAbierto(false)}
        >
          Cancelar
        </Button>
      </div>

      <Mensaje estado={estado} />
    </form>
  );
}
