import { ImageResponse } from "next/og";
import { cargarTorneoPublico, fechaLarga } from "@/lib/torneo/publico";

export const size = { width: 1200, height: 630 };
export const contentType = "image/png";
export const alt = "Torneo";

/**
 * La tarjeta que enseña WhatsApp al pegar el enlace en el grupo del club.
 *
 * Es la primera impresión del producto y llega antes que la página: mucha
 * gente decide aquí si abre el enlace. Por eso lleva el marcador del torneo
 * —jugadores, rondas, y el campeón si ya terminó— y no sólo un logotipo.
 *
 * Los colores van a mano porque satori no entiende Tailwind ni las variables
 * CSS de globals.css. Son los mismos tokens, en su versión clara.
 */
const GROUND = "#f5f7f5";
const INK = "#131b1d";
const INK_SOFT = "#4c5d5f";
const ACCENT = "#0e6e78";
const RULE = "#d9e0dd";

export default async function Image({
  params,
}: {
  params: Promise<{ club: string; torneo: string }>;
}) {
  const { club: clubSlug, torneo: torneoSlug } = await params;
  const datos = await cargarTorneoPublico(clubSlug, torneoSlug);

  if (!datos) {
    return new ImageResponse(
      (
        <div
          style={{
            width: "100%",
            height: "100%",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            background: GROUND,
            color: INK_SOFT,
            fontSize: 48,
          }}
        >
          Puntazo
        </div>
      ),
      size,
    );
  }

  const { club, torneo, inscritos, jugados, total, campeon } = datos;

  const datoDerecha = campeon
    ? { valor: campeon, etiqueta: "Campeón" }
    : total > 0
      ? { valor: `${jugados}/${total}`, etiqueta: "Partidos jugados" }
      : { valor: `${torneo.rondas}`, etiqueta: "Rondas" };

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          background: GROUND,
          padding: "72px 80px",
        }}
      >
        <div style={{ display: "flex", flexDirection: "column" }}>
          <div
            style={{
              fontSize: 26,
              letterSpacing: 4,
              textTransform: "uppercase",
              color: ACCENT,
              fontWeight: 600,
            }}
          >
            {club.nombre}
          </div>
          <div
            style={{
              marginTop: 20,
              fontSize: torneo.nombre.length > 34 ? 76 : 96,
              lineHeight: 1.05,
              fontWeight: 800,
              letterSpacing: -2,
              color: INK,
            }}
          >
            {torneo.nombre}
          </div>
          <div style={{ marginTop: 20, fontSize: 32, color: INK_SOFT }}>
            {fechaLarga(torneo.fecha)}
          </div>
        </div>

        <div
          style={{
            display: "flex",
            alignItems: "flex-end",
            justifyContent: "space-between",
            borderTop: `2px solid ${RULE}`,
            paddingTop: 32,
          }}
        >
          <div style={{ display: "flex", gap: 64 }}>
            <div style={{ display: "flex", flexDirection: "column" }}>
              <div style={{ fontSize: 56, fontWeight: 700, color: INK }}>
                {inscritos.length}
              </div>
              <div style={{ fontSize: 24, color: INK_SOFT }}>Jugadores</div>
            </div>
            <div style={{ display: "flex", flexDirection: "column" }}>
              <div
                style={{
                  fontSize: campeon ? 44 : 56,
                  fontWeight: 700,
                  color: campeon ? ACCENT : INK,
                }}
              >
                {datoDerecha.valor}
              </div>
              <div style={{ fontSize: 24, color: INK_SOFT }}>
                {datoDerecha.etiqueta}
              </div>
            </div>
          </div>

          <div style={{ fontSize: 26, fontWeight: 600, color: INK_SOFT }}>
            Puntazo
          </div>
        </div>
      </div>
    ),
    size,
  );
}
