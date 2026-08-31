"use client";

import { useActionState, useState } from "react";
import { actualizarAjustes, type EstadoAjustes } from "../../actions";
import { SubmitButton } from "@/components/submit-button";
import { describirCuadro, formatearDuracion } from "@/lib/torneo/cuadro";

const INICIAL: EstadoAjustes = {};

const TONO_AVISO = {
  info: "text-ink-soft",
  warn: "text-warn",
  danger: "text-danger",
} as const;

export function AjustesCuadro({
  clubSlug,
  torneoSlug,
  inscritos,
  pistas,
  rondas,
  minutosPorRonda,
  horaInicio,
  editable,
}: {
  clubSlug: string;
  torneoSlug: string;
  inscritos: number;
  pistas: number;
  rondas: number;
  minutosPorRonda: number;
  horaInicio: string | null;
  editable: boolean;
}) {
  const [estado, accion] = useActionState(actualizarAjustes, INICIAL);

  // Se recalcula mientras escribes, para decidir con los números delante.
  const [valores, setValores] = useState({
    pistas: String(pistas),
    rondas: String(rondas),
    minutos: String(minutosPorRonda),
    hora: horaInicio?.slice(0, 5) ?? "",
  });

  const cuadro = describirCuadro({
    inscritos,
    pistas: Number(valores.pistas) || 0,
    rondas: Number(valores.rondas) || 0,
    minutosPorRonda: Number(valores.minutos) || 0,
    horaInicio: valores.hora || null,
  });

  const campo =
    "w-full rounded-sm border border-rule-strong bg-surface px-2 py-1 text-sm text-ink tabular";

  const cambiado =
    valores.pistas !== String(pistas) ||
    valores.rondas !== String(rondas) ||
    valores.minutos !== String(minutosPorRonda) ||
    valores.hora !== (horaInicio?.slice(0, 5) ?? "");

  return (
    <form action={accion} className="flex flex-col gap-4">
      <input type="hidden" name="clubSlug" value={clubSlug} />
      <input type="hidden" name="torneoSlug" value={torneoSlug} />

      <div className="grid grid-cols-2 gap-3">
        {[
          { clave: "pistas", nombre: "pistas", etiqueta: "Pistas", min: 1, max: 30 },
          { clave: "rondas", nombre: "rondas", etiqueta: "Rondas", min: 1, max: 40 },
          { clave: "minutos", nombre: "minutos_por_ronda", etiqueta: "Min/ronda", min: 5, max: 180 },
        ].map((c) => (
          <label key={c.clave} className="block">
            <span className="mb-1 block text-xs font-semibold text-ink-soft">
              {c.etiqueta}
            </span>
            <input
              name={c.nombre}
              type="number"
              min={c.min}
              max={c.max}
              disabled={!editable}
              value={valores[c.clave as keyof typeof valores]}
              onChange={(e) =>
                setValores((v) => ({ ...v, [c.clave]: e.target.value }))
              }
              className={campo}
            />
          </label>
        ))}

        <label className="block">
          <span className="mb-1 block text-xs font-semibold text-ink-soft">Inicio</span>
          <input
            name="hora_inicio"
            type="time"
            disabled={!editable}
            value={valores.hora}
            onChange={(e) => setValores((v) => ({ ...v, hora: e.target.value }))}
            className={campo}
          />
        </label>
      </div>

      {/* ------------------------------------------- lo que sale de esos números */}
      <dl className="flex flex-col gap-1 border-t border-rule pt-3 text-sm">
        <div className="flex justify-between gap-3">
          <dt className="text-ink-soft">Juegan por ronda</dt>
          <dd className="tabular font-semibold text-ink">
            {cuadro.jugadoresPorRonda} en {cuadro.pistasUtiles} pista
            {cuadro.pistasUtiles === 1 ? "" : "s"}
          </dd>
        </div>
        <div className="flex justify-between gap-3">
          <dt className="text-ink-soft">Descansan</dt>
          <dd className="tabular font-semibold text-ink">{cuadro.descansanPorRonda}</dd>
        </div>
        <div className="flex justify-between gap-3">
          <dt className="text-ink-soft">Partidos por jugador</dt>
          <dd className="tabular font-semibold text-ink">
            {cuadro.partidosPorJugador.min === cuadro.partidosPorJugador.max
              ? cuadro.partidosPorJugador.min
              : `${cuadro.partidosPorJugador.min}–${cuadro.partidosPorJugador.max}`}
          </dd>
        </div>
        <div className="flex justify-between gap-3">
          <dt className="text-ink-soft">Dura</dt>
          <dd className="tabular font-semibold text-ink">
            {formatearDuracion(cuadro.duracionMinutos)}
            {cuadro.horaFin ? ` · acaba ${cuadro.horaFin}` : ""}
          </dd>
        </div>
      </dl>

      {cuadro.avisos.length > 0 ? (
        <ul className="flex flex-col gap-1.5 text-xs">
          {cuadro.avisos.map((a, i) => (
            <li key={i} className={TONO_AVISO[a.tono]}>
              {a.texto}
            </li>
          ))}
        </ul>
      ) : null}

      {estado.error ? (
        <p role="alert" className="text-sm font-medium text-danger">
          {estado.error}
        </p>
      ) : null}

      {editable && cambiado ? (
        <SubmitButton variante="suave" enCurso="Guardando…">
          Guardar ajustes
        </SubmitButton>
      ) : null}
    </form>
  );
}
