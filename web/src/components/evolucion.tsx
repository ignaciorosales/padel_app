/**
 * El gráfico de evolución del rating.
 *
 * SVG a mano y no una librería de gráficos, por tres razones que en este caso
 * pesan más que la comodidad: es una sola línea, se pinta en el servidor sin
 * enviar JavaScript, y una librería de gráficos son doscientos kilobytes para
 * dibujar una polilínea.
 *
 * Lo que sí tiene cuidado:
 *
 * - **El eje vertical no empieza en cero.** Un rating vive entre 900 y 2000, y
 *   un eje desde cero convierte cualquier historia en una línea plana. Se ajusta
 *   a lo que hay, con un margen para que la línea no toque los bordes.
 * - **Los umbrales de división se dibujan detrás**, porque son lo que da sentido
 *   a la subida: "pasé de 1590 a 1610" no dice nada; "cruzó la línea de 3ª" sí.
 * - **Un solo punto no es una línea.** Con un partido se dibuja el punto y se
 *   dice que hace falta más historia, en vez de una línea horizontal falsa.
 */

import type { EscalaDeDivisiones } from "@/lib/rating/divisiones";
import type { PuntoDeEvolucion } from "@/lib/jugador/perfil";

const ANCHO = 640;
const ALTO = 180;
const MARGEN = { arriba: 12, abajo: 22, izquierda: 40, derecha: 8 };

export function Evolucion({
  puntos,
  escala,
}: {
  puntos: PuntoDeEvolucion[];
  escala: EscalaDeDivisiones;
}) {
  if (puntos.length === 0) {
    return (
      <p className="text-sm text-ink-faint">
        Todavía no hay ningún partido que haya movido el rating.
      </p>
    );
  }

  const valores = puntos.map((p) => p.rating);
  const crudoMin = Math.min(...valores);
  const crudoMax = Math.max(...valores);

  // Con poca variación el rango se abre a la fuerza: si no, ±2 puntos de ruido
  // se pintan como una montaña.
  const centro = (crudoMin + crudoMax) / 2;
  const mitad = Math.max(40, (crudoMax - crudoMin) / 2 + 15);
  const min = Math.min(crudoMin - 10, centro - mitad);
  const max = Math.max(crudoMax + 10, centro + mitad);

  const dentro = {
    ancho: ANCHO - MARGEN.izquierda - MARGEN.derecha,
    alto: ALTO - MARGEN.arriba - MARGEN.abajo,
  };

  const x = (i: number) =>
    MARGEN.izquierda +
    (puntos.length === 1 ? dentro.ancho / 2 : (i / (puntos.length - 1)) * dentro.ancho);
  const y = (valor: number) =>
    MARGEN.arriba + dentro.alto - ((valor - min) / (max - min)) * dentro.alto;

  const linea = puntos.map((p, i) => `${x(i).toFixed(1)},${y(p.rating).toFixed(1)}`).join(" ");

  // Sólo los umbrales que caen dentro de la ventana: dibujar los ocho llenaría el
  // gráfico de líneas que no dicen nada de este jugador.
  const umbrales = escala.divisiones.filter((d) => d.desde > min && d.desde < max);

  const ultimo = puntos[puntos.length - 1];
  const primero = puntos[0];
  const subio = ultimo.rating >= primero.rating;

  return (
    <div className="overflow-x-auto">
      <svg
        viewBox={`0 0 ${ANCHO} ${ALTO}`}
        className="h-auto w-full min-w-[420px]"
        role="img"
        aria-label={`Evolución del rating: de ${Math.round(primero.rating)} a ${Math.round(
          ultimo.rating,
        )} en ${puntos.length} partidos.`}
      >
        {umbrales.map((division) => (
          <g key={division.nombre}>
            <line
              x1={MARGEN.izquierda}
              x2={ANCHO - MARGEN.derecha}
              y1={y(division.desde)}
              y2={y(division.desde)}
              stroke="currentColor"
              strokeWidth="1"
              strokeDasharray="3 3"
              className="text-rule-strong"
            />
            <text
              x={MARGEN.izquierda - 6}
              y={y(division.desde) + 3.5}
              textAnchor="end"
              className="fill-current font-mono text-[9px] text-ink-faint"
            >
              {division.nombre}
            </text>
          </g>
        ))}

        {puntos.length === 1 ? (
          <circle cx={x(0)} cy={y(primero.rating)} r="4" className="fill-current text-accent" />
        ) : (
          <>
            <polyline
              points={linea}
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinejoin="round"
              strokeLinecap="round"
              className={subio ? "text-ok" : "text-danger"}
            />
            <circle
              cx={x(puntos.length - 1)}
              cy={y(ultimo.rating)}
              r="3.5"
              className={`fill-current ${subio ? "text-ok" : "text-danger"}`}
            />
          </>
        )}

        <text
          x={MARGEN.izquierda}
          y={ALTO - 6}
          className="fill-current font-mono text-[9px] text-ink-faint"
        >
          {primero.fecha}
        </text>
        <text
          x={ANCHO - MARGEN.derecha}
          y={ALTO - 6}
          textAnchor="end"
          className="fill-current font-mono text-[9px] text-ink-faint"
        >
          {ultimo.fecha}
        </text>
      </svg>

      {puntos.length === 1 ? (
        <p className="mt-1 text-xs text-ink-faint">
          Un solo partido no dibuja una línea. Con tres ya se ve la tendencia.
        </p>
      ) : null}
    </div>
  );
}

/**
 * La barra de progreso dentro de la división.
 *
 * Lo que mueve a la gente no es "1656 de rating": es "te faltan 94 para segunda".
 * Y cuando ya está por encima del umbral, lo que hace falta decir no es un número
 * sino una tarea — "mantenlo tres partidos más".
 */
export function BarraDeProgreso({
  fraccion,
  division,
  siguiente,
  faltan,
  partidosParaConfirmar,
}: {
  fraccion: number;
  division: string;
  siguiente: string | null;
  faltan: number;
  partidosParaConfirmar: number | null;
}) {
  const porcentaje = Math.round(fraccion * 100);

  return (
    <div>
      <div className="mb-1.5 flex items-baseline justify-between text-xs">
        <span className="font-mono font-medium text-ink">{division}</span>
        {siguiente ? (
          <span className="font-mono text-ink-faint">{siguiente}</span>
        ) : (
          <span className="text-ink-faint">la más alta</span>
        )}
      </div>

      <div className="h-2 w-full overflow-hidden rounded-full bg-surface-alt">
        <div
          className={`h-full rounded-full ${
            partidosParaConfirmar !== null ? "bg-ok" : "bg-accent"
          }`}
          style={{ width: `${Math.max(2, porcentaje)}%` }}
        />
      </div>

      <p className="mt-1.5 text-sm text-ink-soft">
        {siguiente === null ? (
          <>Ya está en la división más alta.</>
        ) : partidosParaConfirmar !== null ? (
          partidosParaConfirmar === 0 ? (
            <>Ya tiene el ascenso a {siguiente}: sube en el próximo recuento.</>
          ) : (
            <>
              Por encima del umbral de {siguiente}. Le faltan{" "}
              <strong className="text-ink">{partidosParaConfirmar}</strong>{" "}
              {partidosParaConfirmar === 1 ? "partido" : "partidos"} sosteniéndolo.
            </>
          )
        ) : (
          <>
            Le faltan <strong className="text-ink">{faltan}</strong> puntos para{" "}
            {siguiente}.
          </>
        )}
      </p>
    </div>
  );
}
