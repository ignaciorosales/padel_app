"use client";

import { useRef } from "react";
import { cambiarEstadoClub } from "./actions";
import { ETIQUETA_ESTADO, type SubscriptionStatus } from "@/lib/types";

const ORDEN: SubscriptionStatus[] = ["trial", "active", "past_due", "suspended"];

export function EstadoSelector({
  clubId,
  estado,
}: {
  clubId: string;
  estado: SubscriptionStatus;
}) {
  const form = useRef<HTMLFormElement>(null);

  function alCambiar(event: React.ChangeEvent<HTMLSelectElement>) {
    const nuevo = event.target.value as SubscriptionStatus;

    // Cortar a un cliente en mitad de un sábado es difícil de deshacer a tiempo:
    // que cueste un clic más.
    if (nuevo === "suspended") {
      const sigue = window.confirm(
        "El club pasará a sólo lectura de inmediato: no podrá crear ni modificar nada. ¿Suspender?",
      );
      if (!sigue) {
        event.target.value = estado;
        return;
      }
    }

    form.current?.requestSubmit();
  }

  return (
    <form ref={form} action={cambiarEstadoClub}>
      <input type="hidden" name="clubId" value={clubId} />
      <select
        name="status"
        defaultValue={estado}
        onChange={alCambiar}
        aria-label="Estado de la suscripción"
        className="rounded-sm border border-rule-strong bg-surface px-2 py-1 text-sm text-ink"
      >
        {ORDEN.map((clave) => (
          <option key={clave} value={clave}>
            {ETIQUETA_ESTADO[clave].texto}
          </option>
        ))}
      </select>
    </form>
  );
}
