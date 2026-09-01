import type { Metadata } from "next";
import { Archivo, IBM_Plex_Mono } from "next/font/google";
import "./globals.css";

const archivo = Archivo({
  variable: "--font-archivo",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
  display: "swap",
});

const plexMono = IBM_Plex_Mono({
  variable: "--font-plex-mono",
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  display: "swap",
});

/**
 * Desde dónde se sirve el sitio. Hace falta para que las tarjetas de enlace
 * lleven URLs absolutas: WhatsApp descarta una `og:image` relativa, y sin esto
 * Next la resuelve contra localhost y la vista previa sale sin imagen.
 */
const base =
  process.env.NEXT_PUBLIC_SITE_URL ??
  (process.env.VERCEL_URL
    ? `https://${process.env.VERCEL_URL}`
    : "http://localhost:3000");

export const metadata: Metadata = {
  metadataBase: new URL(base),
  title: {
    default: "Puntazo",
    template: "%s · Puntazo",
  },
  description: "Torneos de pádel para clubes.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="es">
      <body className={`${archivo.variable} ${plexMono.variable} antialiased`}>
        {children}
      </body>
    </html>
  );
}
