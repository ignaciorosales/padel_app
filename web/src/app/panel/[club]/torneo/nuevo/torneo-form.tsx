"use client";

import { useActionState, useState } from "react";
import { crearTorneo, type EstadoTorneoForm } from "../../actions";
import { SubmitButton } from "@/components/submit-button";
import { Field, Input, Select } from "@/components/ui";

const INICIAL: EstadoTorneoForm = {};

type Formato = "americano" | "parejas";

/**
 * Es la única pantalla donde hay que explicar la diferencia entre los dos
 * formatos, porque es donde se elige y donde casi nadie la tiene clara. La
 * explicación va en la propia pantalla y no en una ayuda escondida.
 */
const EXPLICACION: Record<Formato, string> = {
  americano:
    "Cada jugador se apunta solo y cambia de compañero en cada ronda. La clasificación es individual y gana una persona. Nadie queda eliminado.",
  parejas:
    "La pareja se apunta junta y no cambia. Primero una fase de grupos, y las mejores parejas pasan al cuadro: cuartos, semifinal y final. Gana una pareja.",
};

export function TorneoForm({ clubSlug }: { clubSlug: string }) {
  const [estado, accion] = useActionState(crearTorneo, INICIAL);
  const [formato, setFormato] = useState<Formato>("americano");
  const hoy = new Date().toISOString().slice(0, 10);

  const esAmericano = formato === "americano";

  return (
    <form action={accion} className="flex flex-col gap-5">
      <input type="hidden" name="clubSlug" value={clubSlug} />

      <Field label="Formato">
        <Select
          name="formato"
          value={formato}
          onChange={(e) => setFormato(e.target.value as Formato)}
        >
          <option value="americano">Americano</option>
          <option value="parejas">Torneo de parejas</option>
        </Select>
      </Field>

      <p className="-mt-2 rounded-r border-l-[3px] border-l-accent bg-accent-soft px-4 py-3 text-sm text-ink-soft">
        {EXPLICACION[formato]}
      </p>

      <Field
        label="Nombre"
        hint={
          esAmericano
            ? "El que va a ver la gente. «Americano del sábado», por ejemplo."
            : "El que va a ver la gente. «Torneo de primavera», por ejemplo."
        }
      >
        <Input
          name="nombre"
          required
          autoFocus
          placeholder={esAmericano ? "Americano del sábado" : "Torneo de primavera"}
        />
      </Field>

      <div className="grid gap-5 sm:grid-cols-2">
        <Field label="Fecha">
          <Input name="fecha" type="date" required defaultValue={hoy} />
        </Field>

        <Field label="Hora de inicio" hint="Opcional. Sirve para calcular la hora de cada ronda.">
          <Input name="hora_inicio" type="time" defaultValue="10:00" />
        </Field>
      </div>

      <div className="grid gap-5 sm:grid-cols-3">
        <Field label="Pistas">
          <Input name="pistas" type="number" min={1} max={30} required defaultValue={3} />
        </Field>

        {esAmericano ? (
          <Field label="Rondas">
            <Input name="rondas" type="number" min={1} max={40} required defaultValue={6} />
          </Field>
        ) : (
          <Field label="Grupos" hint="Las parejas se reparten solas.">
            <Input name="grupos" type="number" min={1} max={16} required defaultValue={2} />
          </Field>
        )}

        <Field label="Minutos por ronda">
          <Input
            name="minutos_por_ronda"
            type="number"
            min={5}
            max={180}
            required
            defaultValue={20}
          />
        </Field>
      </div>

      {esAmericano ? null : (
        <div className="grid gap-5 sm:grid-cols-2">
          <Field
            label="Pasan al cuadro, por grupo"
            hint="Con 2 grupos y 2 que pasan, el cuadro son semifinales."
          >
            <Input
              name="clasifican_por_grupo"
              type="number"
              min={1}
              max={8}
              required
              defaultValue={2}
            />
          </Field>

          <Field label="El marcador son…" hint="Sólo cambia cómo se llama en pantalla.">
            <Select name="unidad_marcador" defaultValue="juegos">
              <option value="juegos">Juegos</option>
              <option value="sets">Sets</option>
              <option value="puntos">Puntos</option>
            </Select>
          </Field>
        </div>
      )}

      {estado.error ? (
        <p role="alert" className="text-sm font-medium text-danger">
          {estado.error}
        </p>
      ) : null}

      <div>
        <SubmitButton enCurso="Creando…">Crear torneo</SubmitButton>
      </div>

      <p className="text-sm text-ink-faint">
        {esAmericano
          ? "Los jugadores se añaden después, y las rondas se generan cuando estén todos."
          : "Las parejas se añaden después, y la fase de grupos se genera cuando estén todas."}{" "}
        Todo esto se puede cambiar mientras el torneo siga en borrador.
      </p>
    </form>
  );
}
