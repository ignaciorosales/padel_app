import type { FilaClasificacion } from "@/lib/torneo/clasificacion";

export type NombreDePareja = (parejaId: string) => string;

/**
 * Una tabla por grupo, que es como se lee y como se decide quién pasa.
 *
 * Las que se clasifican van marcadas desde el primer resultado, no al final:
 * el organizador y los jugadores quieren saber quién va pasando mientras se
 * juega, que es la mitad de la gracia de una fase de grupos.
 */
export function ClasificacionGrupos({
  tablas,
  nombre,
  clasificanPorGrupo,
  unidad,
}: {
  tablas: FilaClasificacion[][];
  nombre: NombreDePareja;
  clasificanPorGrupo: number;
  unidad: string;
}) {
  return (
    <div className="grid gap-6 sm:grid-cols-2">
      {tablas.map((filas, i) => (
        <div key={i} className="print:break-inside-avoid">
          <h3 className="mb-2 border-b border-rule pb-1 font-semibold text-ink">
            Grupo {i + 1}
          </h3>

          <table className="w-full border-collapse text-sm">
            <thead>
              <tr className="border-b border-rule text-left">
                <th className="pb-1.5 pr-2" />
                <th className="pb-1.5 pr-3 font-mono text-[0.67rem] tracking-[0.13em] text-ink-faint uppercase">
                  Pareja
                </th>
                {["PJ", "G", "Dif"].map((h) => (
                  <th
                    key={h}
                    className="pb-1.5 pr-2 text-right font-mono text-[0.67rem] tracking-[0.13em] text-ink-faint uppercase"
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filas.map((fila, indice) => {
                const pasa = indice < clasificanPorGrupo;
                return (
                  <tr
                    key={fila.jugadorId}
                    className={`border-b border-rule ${pasa ? "bg-accent-soft" : ""}`}
                  >
                    <td className="py-2 pr-2 font-mono text-xs text-ink-faint tabular">
                      {fila.puesto}
                    </td>
                    <td className="py-2 pr-3 text-ink">
                      <span className={pasa ? "font-semibold" : ""}>
                        {nombre(fila.jugadorId)}
                      </span>
                    </td>
                    <td className="py-2 pr-2 text-right tabular text-ink-soft">
                      {fila.partidos}
                    </td>
                    <td className="py-2 pr-2 text-right tabular font-semibold text-ink">
                      {fila.ganados}
                    </td>
                    <td className="py-2 pr-2 text-right tabular text-ink-soft">
                      {fila.diferencia > 0 ? `+${fila.diferencia}` : fila.diferencia}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      ))}

      <p className="font-mono text-[0.67rem] text-ink-faint sm:col-span-2">
        PJ jugados · G ganados · Dif diferencia de {unidad} · en color, las que
        pasan al cuadro
      </p>
    </div>
  );
}
