import Link from "next/link";
import type { ReactNode } from "react";
import { cerrarSesion } from "@/app/actions";
import { Badge } from "./ui";

export function Shell({
  children,
  email,
  esAdminPlataforma,
  contexto,
}: {
  children: ReactNode;
  email: string | null;
  esAdminPlataforma: boolean;
  contexto?: ReactNode;
}) {
  return (
    <div className="min-h-screen">
      <header className="border-b border-rule bg-surface">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-5 gap-y-2 px-6 py-3">
          <Link
            href="/"
            className="font-mono text-sm font-semibold tracking-[0.2em] text-ink uppercase"
          >
            Puntazo
          </Link>

          {esAdminPlataforma ? (
            <Link href="/admin" className="text-sm text-ink-soft hover:text-ink">
              Clubes
            </Link>
          ) : null}

          {contexto ? <div className="min-w-0">{contexto}</div> : null}

          <div className="ml-auto flex items-center gap-4">
            {esAdminPlataforma ? <Badge tono="acento">Plataforma</Badge> : null}
            <span className="hidden text-sm text-ink-faint sm:inline">{email}</span>
            <form action={cerrarSesion}>
              <button
                type="submit"
                className="text-sm text-ink-soft underline-offset-4 hover:text-ink hover:underline"
              >
                Salir
              </button>
            </form>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-6 py-10">{children}</main>
    </div>
  );
}
