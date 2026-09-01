/**
 * Lo ve quien abre un enlace mal copiado del grupo de WhatsApp, o el de un
 * torneo que el club ha dejado de publicar. No dice cuál de las dos cosas es:
 * desde fuera no se puede distinguir un torneo inexistente de uno despublicado.
 */
export default function NoEncontrado() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col items-center justify-center px-6 text-center">
      <p className="font-mono text-[0.69rem] font-medium tracking-[0.17em] text-accent uppercase">
        Puntazo
      </p>
      <h1 className="mt-3 text-2xl font-extrabold tracking-[-0.02em]">
        Este torneo no está disponible
      </h1>
      <p className="mt-3 text-ink-soft">
        El enlace puede estar incompleto, o el club puede haber dejado de
        publicar el torneo. Pídeselo otra vez a quien te lo pasó.
      </p>
    </main>
  );
}
