"use client";

import { useActionState, useRef } from "react";
import {
  corregirHora,
  corregirJugador,
  corregirPista,
  type EstadoHora,
} from "../../actions";
import type { Inscrito } from "@/lib/torneo/tipos";
import { POSICIONES, type Posicion } from "@/lib/torneo/correccion";

const ETIQUETA: Record<Posicion, string> = {
  a1: "Primer equipo, jugador 1",
  a2: "Primer equipo, jugador 2",
  b1: "Segundo equipo, jugador 1",
  b2: "Segundo equipo, jugador 2",
};

/**
 * Corregir un partido con desplegables. Decidido así en el plan de producto:
 * arrastrar y soltar es una librería entera y una interacción mala justo en el
 * móvil, que es donde se corrige el día del torneo.
 *
 * Va detrás de un `<details>` cerrado porque corregir es la excepción; lo
 * normal es meter el resultado, y eso tiene que seguir siendo dos toques.
 *
 * Cada desplegable ofrece a **todos** los inscritos, incluidos los que ya
 * juegan en otra pista: elegir a uno de ésos los intercambia. Filtrarlos
 * obligaría a hacer sitio primero, que es la corrección en dos pasos que
 * `lib/torneo/correccion.ts` existe para evitar.
 */
export function CorregirPartido({
  clubSlug,
  torneoSlug,
  partidoId,
  pista,
  pistasDisponibles,
  jugadores,
  inscritos,
}: {
  clubSlug: string;
  torneoSlug: string;
  partidoId: string;
  pista: number;
  pistasDisponibles: number[];
  jugadores: Record<Posicion, string>;
  inscritos: Inscrito[];
}) {
  return (
    <details className="group mt-1">
      <summary className="cursor-pointer list-none text-xs text-ink-faint hover:text-accent-ink [&::-webkit-details-marker]:hidden print:hidden">
        <span className="inline-block transition-transform group-open:rotate-90">▸</span>{" "}
        Corregir
      </summary>

      <div className="mt-2 flex flex-wrap items-center gap-2 rounded-sm bg-surface-alt p-2 print:hidden">
        <SelectorPista
          clubSlug={clubSlug}
          torneoSlug={torneoSlug}
          partidoId={partidoId}
          pista={pista}
          disponibles={pistasDisponibles}
        />

        {POSICIONES.map((pos) => (
          <span key={pos} className="flex items-center gap-2">
            {pos === "b1" ? (
              <span className="text-xs text-ink-faint">vs</span>
            ) : null}
            <SelectorJugador
              clubSlug={clubSlug}
              torneoSlug={torneoSlug}
              partidoId={partidoId}
              posicion={pos}
              actual={jugadores[pos]}
              inscritos={inscritos}
            />
          </span>
        ))}
      </div>
    </details>
  );
}

const HORA_INICIAL: EstadoHora = {};

/**
 * La hora de una ronda, corregible en el sitio donde se lee.
 *
 * Se va con retraso casi siempre: la ronda que iba a las 18:20 empieza a las
 * 18:35 y el texto que se pega en WhatsApp tiene que decir la verdad, no lo
 * que se planificó el jueves. Un `<input type="time">` en vez de desplegable
 * porque el teclado del móvil ya trae su propio selector.
 *
 * Tocar una hora arrastra las rondas siguientes, y la pantalla lo dice: mover
 * seis rondas de golpe sin avisar asusta más que el retraso. Si aun así algo no
 * cabe en el calendario del club, sale aquí en vez de perderse.
 */
export function CorregirHora({
  clubSlug,
  torneoSlug,
  rondaId,
  hora,
}: {
  clubSlug: string;
  torneoSlug: string;
  rondaId: string;
  hora: string | null;
}) {
  const form = useRef<HTMLFormElement>(null);
  const [estado, accion] = useActionState(corregirHora, HORA_INICIAL);

  return (
    <form ref={form} action={accion} className="print:hidden">
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="torneoSlug" value={torneoSlug} />
      <input type="hidden" name="rondaId" value={rondaId} />
      <input
        type="time"
        name="hora"
        defaultValue={hora ?? ""}
        onChange={() => form.current?.requestSubmit()}
        aria-label="Hora de la ronda"
        className="rounded-sm border border-transparent bg-transparent px-1 py-0.5 font-mono text-xs text-ink-faint tabular hover:border-rule-strong hover:bg-surface"
      />

      {estado.arrastradas ? (
        <p role="status" className="mt-1 text-xs text-ink-faint">
          {estado.arrastradas === 1
            ? "La ronda siguiente se movió con ésta."
            : `Las ${estado.arrastradas} rondas siguientes se movieron con ésta.`}
        </p>
      ) : null}

      {estado.aviso ? (
        <p role="alert" className="mt-1 max-w-[16rem] text-xs font-medium text-warn">
          {estado.aviso}
        </p>
      ) : null}
    </form>
  );
}

const CLASE_SELECT =
  "max-w-[10rem] rounded-sm border border-rule-strong bg-surface px-2 py-1 text-xs text-ink";

function SelectorJugador({
  clubSlug,
  torneoSlug,
  partidoId,
  posicion,
  actual,
  inscritos,
}: {
  clubSlug: string;
  torneoSlug: string;
  partidoId: string;
  posicion: Posicion;
  actual: string;
  inscritos: Inscrito[];
}) {
  const form = useRef<HTMLFormElement>(null);

  return (
    <form ref={form} action={corregirJugador}>
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="torneoSlug" value={torneoSlug} />
      <input type="hidden" name="partidoId" value={partidoId} />
      <input type="hidden" name="posicion" value={posicion} />
      <select
        name="jugadorId"
        defaultValue={actual}
        onChange={() => form.current?.requestSubmit()}
        aria-label={ETIQUETA[posicion]}
        className={CLASE_SELECT}
      >
        {inscritos.map((j) => (
          <option key={j.id} value={j.id}>
            {j.nombre}
          </option>
        ))}
      </select>
    </form>
  );
}

function SelectorPista({
  clubSlug,
  torneoSlug,
  partidoId,
  pista,
  disponibles,
}: {
  clubSlug: string;
  torneoSlug: string;
  partidoId: string;
  pista: number;
  disponibles: number[];
}) {
  const form = useRef<HTMLFormElement>(null);

  return (
    <form ref={form} action={corregirPista}>
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="torneoSlug" value={torneoSlug} />
      <input type="hidden" name="partidoId" value={partidoId} />
      <select
        name="pista"
        defaultValue={pista}
        onChange={() => form.current?.requestSubmit()}
        aria-label="Pista"
        className="rounded-sm border border-rule-strong bg-surface px-2 py-1 font-mono text-xs text-ink"
      >
        {disponibles.map((n) => (
          <option key={n} value={n}>
            P{n}
          </option>
        ))}
      </select>
    </form>
  );
}
