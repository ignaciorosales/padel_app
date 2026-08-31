import Link from "next/link";
import type { ComponentProps, ReactNode } from "react";

type Tono = "ok" | "warn" | "danger" | "neutro" | "acento";

const TONO_BADGE: Record<Tono, string> = {
  ok: "bg-ok-soft text-ok",
  warn: "bg-warn-soft text-warn",
  danger: "bg-danger-soft text-danger",
  neutro: "bg-surface-alt text-ink-faint",
  acento: "bg-accent-soft text-accent-ink",
};

export function Badge({
  children,
  tono = "neutro",
}: {
  children: ReactNode;
  tono?: Tono;
}) {
  return (
    <span
      className={`inline-block rounded-sm px-2 py-[3px] font-mono text-[0.67rem] font-medium tracking-wide uppercase ${TONO_BADGE[tono]}`}
    >
      {children}
    </span>
  );
}

export function Card({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={`rounded border border-rule bg-surface p-5 shadow-[0_1px_2px_rgba(19,27,29,0.05)] ${className}`}
    >
      {children}
    </div>
  );
}

export function Eyebrow({ children }: { children: ReactNode }) {
  return (
    <p className="mb-2 font-mono text-[0.69rem] font-medium tracking-[0.17em] text-accent uppercase">
      {children}
    </p>
  );
}

export function PageHeader({
  eyebrow,
  title,
  description,
  actions,
}: {
  eyebrow?: ReactNode;
  title: string;
  description?: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <header className="mb-8 flex flex-wrap items-end justify-between gap-4 border-b border-rule pb-6">
      <div className="min-w-0">
        {eyebrow ? <Eyebrow>{eyebrow}</Eyebrow> : null}
        <h1 className="text-3xl font-extrabold tracking-[-0.028em] text-balance">
          {title}
        </h1>
        {description ? (
          <p className="mt-2 max-w-[60ch] text-ink-soft">{description}</p>
        ) : null}
      </div>
      {actions ? <div className="flex gap-2">{actions}</div> : null}
    </header>
  );
}

const BOTON_BASE =
  "inline-flex items-center justify-center gap-2 rounded-sm px-4 py-2 text-sm font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-55";

const BOTON_VARIANTE = {
  primario: "bg-accent text-white hover:bg-accent-ink",
  suave: "border border-rule-strong bg-surface text-ink hover:bg-surface-alt",
  peligro: "border border-danger/40 bg-danger-soft text-danger hover:bg-danger/15",
} as const;

export type VarianteBoton = keyof typeof BOTON_VARIANTE;

export function Button({
  variante = "primario",
  className = "",
  ...props
}: ComponentProps<"button"> & { variante?: VarianteBoton }) {
  return (
    <button
      {...props}
      className={`${BOTON_BASE} ${BOTON_VARIANTE[variante]} ${className}`}
    />
  );
}

export function LinkButton({
  variante = "suave",
  className = "",
  ...props
}: ComponentProps<typeof Link> & { variante?: VarianteBoton }) {
  return (
    <Link
      {...props}
      className={`${BOTON_BASE} ${BOTON_VARIANTE[variante]} ${className}`}
    />
  );
}

export function Field({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: ReactNode;
  children: ReactNode;
}) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-sm font-semibold text-ink">{label}</span>
      {children}
      {hint ? <span className="mt-1.5 block text-xs text-ink-faint">{hint}</span> : null}
    </label>
  );
}

export function Input({ className = "", ...props }: ComponentProps<"input">) {
  return (
    <input
      {...props}
      className={`w-full rounded-sm border border-rule-strong bg-surface px-3 py-2 text-ink placeholder:text-ink-faint ${className}`}
    />
  );
}

export function Select({ className = "", ...props }: ComponentProps<"select">) {
  return (
    <select
      {...props}
      className={`w-full rounded-sm border border-rule-strong bg-surface px-3 py-2 text-ink ${className}`}
    />
  );
}

export function Aviso({
  tono = "warn",
  titulo,
  children,
}: {
  tono?: "warn" | "danger" | "ok";
  titulo: string;
  children?: ReactNode;
}) {
  const estilos = {
    warn: "border-l-warn bg-warn-soft text-warn",
    danger: "border-l-danger bg-danger-soft text-danger",
    ok: "border-l-ok bg-ok-soft text-ok",
  }[tono];

  return (
    <div className={`mb-6 rounded-r border-l-[3px] px-5 py-4 ${estilos}`}>
      <p className="font-semibold">{titulo}</p>
      {children ? <div className="mt-1 text-sm opacity-90">{children}</div> : null}
    </div>
  );
}

export function Vacio({ children }: { children: ReactNode }) {
  return (
    <div className="rounded border border-dashed border-rule-strong px-6 py-10 text-center text-ink-faint">
      {children}
    </div>
  );
}
