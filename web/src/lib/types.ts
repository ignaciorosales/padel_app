export type SubscriptionStatus = "trial" | "active" | "past_due" | "suspended";

export type ClubRole = "owner" | "staff";

export type Club = {
  id: string;
  slug: string;
  name: string;
  status: SubscriptionStatus;
  trial_ends_at: string | null;
  contact_name: string | null;
  contact_phone: string | null;
  notes: string | null;
  created_at: string;
};

export type Profile = {
  id: string;
  email: string | null;
  full_name: string | null;
  is_platform_admin: boolean;
  created_at: string;
};

export type Membership = {
  club: Club;
  role: ClubRole;
};

/**
 * Estados que permiten escribir. Es el reflejo en la interfaz de lo que hace
 * `can_write_club()` en la base de datos — la que manda es la de la base de
 * datos; esto sólo sirve para no enseñar botones que van a fallar.
 */
export const ESTADOS_CON_ESCRITURA: SubscriptionStatus[] = [
  "trial",
  "active",
  "past_due",
];

export function puedeEscribir(status: SubscriptionStatus): boolean {
  return ESTADOS_CON_ESCRITURA.includes(status);
}

export const ETIQUETA_ESTADO: Record<
  SubscriptionStatus,
  { texto: string; tono: "ok" | "warn" | "danger" | "neutro"; ayuda: string }
> = {
  trial: {
    texto: "Prueba",
    tono: "neutro",
    ayuda: "Periodo de prueba. Funciona con normalidad.",
  },
  active: {
    texto: "Al día",
    tono: "ok",
    ayuda: "Suscripción al corriente.",
  },
  past_due: {
    texto: "Pago pendiente",
    tono: "warn",
    ayuda: "Sigue funcionando, pero el club ve un aviso en su panel.",
  },
  suspended: {
    texto: "Suspendido",
    tono: "danger",
    ayuda: "Sólo lectura: no puede crear ni modificar nada.",
  },
};
