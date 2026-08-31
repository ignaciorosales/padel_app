import type { Metadata } from "next";
import { LoginForm } from "./login-form";
import { Card } from "@/components/ui";

export const metadata: Metadata = { title: "Entrar" };

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ volver?: string }>;
}) {
  const { volver = "" } = await searchParams;

  return (
    <div className="flex min-h-screen items-center justify-center px-6 py-16">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <p className="font-mono text-sm font-semibold tracking-[0.24em] text-ink uppercase">
            Puntazo
          </p>
          <p className="mt-2 text-sm text-ink-soft">Panel del club</p>
        </div>

        <Card>
          <LoginForm volver={volver} />
        </Card>

        <p className="mt-6 text-center text-xs text-ink-faint">
          Las cuentas las crea Puntazo. Si no tienes uno, pídelo a tu contacto.
        </p>
      </div>
    </div>
  );
}
