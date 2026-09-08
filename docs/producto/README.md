# Plan de producto

Estado: **decidido, sin empezar a construir.** Última revisión: 2026-08-30.

Este documento existe para que cualquiera (o cualquier sesión de trabajo) entienda
**qué se va a construir después del marcador y por qué en ese orden**, sin tener
que rederivar las decisiones. Es un registro de decisiones, no una especificación.

Versión presentable del mismo plan, para enseñar a terceros:
<https://claude.ai/code/artifact/f2310bb9-e557-4d61-834c-7017e266c6e4>

---

## El contexto que no está en el código

- El marcador (`app/` + `firmware/`) **no es el producto final**: es la pieza que
  diferencia a un producto de gestión para clubes de pádel.
- Los clubes objetivo **no usan software hoy**. Gestionan torneos, pistas y clases
  con cuaderno, Excel y un grupo de WhatsApp. No hay Playtomic instalado, así que
  no hay migración ni incumbente — pero el listón es el papel, que es instantáneo.
- Quien paga es el club. El jugador nunca va a pagar al principio.
- La pista **no tiene wifi fiable** y no se puede contar con ella. Recepción sí
  suele tener conexión (vale la de un móvil).

## Orden de construcción, y por qué

| Fase | Qué | Por qué en este punto |
|---|---|---|
| 1 | **Torneos y americanos**, todo a mano | Evento aislado: si sale mal el club pierde una mañana, no su negocio. Riesgo bajo para él, y es donde el cuaderno peor funciona. |
| 2 | **Agenda de pistas** | Se usa a diario y toca el dinero. Cuesta más que se lo jueguen contigo, pero una vez dentro no se van. Llega cuando ya te han visto funcionar. |
| 3 | **Clases y escuela** + hardware conectado | Ingreso recurrente del club. Encaja sobre la agenda casi sin trabajo extra y justifica subir el precio. |
| 4 | **App del jugador** (perfil, historial, stats) — plan en [app-jugador.md](app-jugador.md), sistema de rating en [puntazo-rating.md](puntazo-rating.md) | Es lo que permite cobrar por las dos apps, pero antes de tener clubes usando el panel a diario no tiene a quién enganchar. |

**Al revés no funciona**: empezar por la agenda obliga al club a cambiar su forma
de trabajar un lunes por la mañana sin haberte probado nunca.

## Alcance de la fase 1 (MVP)

Decisión explícita del 2026-08-30: **se automatiza poco a propósito.** El
encargado mete los jugadores y los resultados a mano, igual que hoy. Lo que se
vende es que el resultado esté bien presentado.

Entra:

- Crear torneo (formato, fecha, pistas, duración de ronda).
- Meter jugadores a mano, o **pegando la lista tal cual está en WhatsApp/Excel**.
- **Generación automática de rondas** — **un solo formato: americano con
  rotación de compañero**. Corregible con desplegables (cambiar pareja, pista u
  hora), no con arrastrar y soltar.
- Meter resultados en dos toques desde el móvil.
- **Clasificación automática** con desempates configurables.
- **Página pública por enlace, sin cuentas**: cruces, resultados y clasificación,
  **con vista previa al pegar el enlace en WhatsApp**.
- Texto de la ronda para copiar y pegar en el grupo de WhatsApp.
- Imprimir rondas y clasificación (modo degradado si falla la conexión).

Espera a fases posteriores:

| Función | Cuándo | Por qué |
|---|---|---|
| Parejas fijas, liguilla por grupos | Fase 2 | Cada formato es otro algoritmo y otra tabla de clasificación. Uno bien hecho vale más que tres a medias. |
| Cuadro eliminatorio | Fase 3 | Se organiza bien con una pizarra; no es donde te van a valorar. |
| Agenda de pistas y reservas | Fase 2 | Se usa a diario y toca el dinero: exige confianza que aún no tienes. |
| Inscripción online del jugador | Fase 3 | Exige que 24 personas usen algo — el problema de adopción que se está evitando a propósito. |
| Avisos automáticos (WhatsApp, push) | Fase 3 | Cuestan dinero y permisos. El grupo del club ya existe. |
| Clases y escuela | Fase 3 | Encaja sobre la agenda, no antes. |
| Resultados automáticos del marcador | Fase 3 | El panel no debe depender del firmware para poder venderse ya. |
| Cuentas, perfiles y estadísticas | Fase 4 | Necesita el QR del marcador y volumen acumulado. |

**Descartado** (no está previsto ni más adelante):

- **Arrastrar y soltar** para reordenar rondas: una librería entera y una
  interacción mala en móvil, que es donde se usa el día del torneo.
- **Funcionamiento sin conexión**: una sincronización de verdad es un proyecto en
  sí. El plan B es imprimir.
- **App móvil nativa del panel**: la misma web bien hecha cubre escritorio y móvil.
- **Cobros, bonos y caja**: sólo dos campos, importe y pendiente/pagado.
- **Cualquier dependencia del hardware.** El panel funciona con cero cajas
  instaladas; el hardware es la mejora de pago, no un requisito.

**Regla para decidir dudas nuevas**: si una función exige que *el jugador* haga
algo, no es de la fase 1. Todo el MVP se opera desde una sola persona.

Sólo dos cosas se automatizan de verdad — **cuadrar rondas y llevar la
clasificación** — y son justo las dos que hoy generan discusiones. El resto del
valor es presentación.

## Decisiones cerradas

| Decisión | Elegido | Razón corta |
|---|---|---|
| Objeto central del modelo | **Ocupación de pista** (pista + rango horario + motivo) | Un torneo genera ocupaciones, una clase también, una reserva *es* una. Si está bien puesto, la agenda de la fase 2 es una pantalla nueva; si no, es una reescritura. |
| Panel: ¿app o web? | **Web responsive** | Se monta sentado con teclado y se lleva andando con el móvil. Evita dos tiendas de apps y permite desplegar un arreglo en mitad de un torneo. |
| Backend | **Supabase** | Los datos son relacionales de manual; clasificaciones y desempates son SQL corto. En Firestore serían colecciones desnormalizadas mantenidas a mano. |
| Página pública | **Sin cuenta, nunca** | En cuanto pidas registro para ver un cuadro, el club vuelve a mandar la foto del papel. |
| Formato de torneo | **Americano** primero | Es el que más se juega y el que peor sale a mano. El cuadro eliminatorio se organiza bien con una pizarra. |
| Repositorio | **Este mismo** | Mismo motivo que está en el README raíz para firmware+app: contratos compartidos que se olvidan al vivir separados. Añadir `web/` y `backend/`. |
| Cobros | **Fuera, pero con sitio** | No construir nada. Sí dejar ficha de cliente mínima y un importe con estado pendiente/pagado en cada inscripción: dos campos que evitan una migración dentro de un año. |

## Cómo va a interactuar con el marcador (fases 3-4)

El marcador **no se toca en la fase 1**, y esto es deliberado: el panel no debe
depender de ningún cambio en el firmware ni en la app de la tele, para poder
venderse mientras el hardware sigue su propio camino.

Cuando llegue el momento, la restricción que manda es que **la pista no tiene
red**. El diseño elegido evita conectarla:

- **Salida de datos**: al terminar el partido la tele muestra un **QR con el
  partido entero dentro** (id, pista, marcador, traza de puntos con tiempos y una
  firma HMAC del dispositivo). Cabe de sobra: ~380 bytes contra los ~2900 que
  admite un QR. El móvil del jugador —que sí tiene datos— hace de mensajero. Dos
  QR, uno por pareja, para saber el lado sin preguntar nada.
- La **firma por dispositivo** no es opcional: es lo que hace que «dato
  verificado» sea producto y no marketing. Sin ella cualquiera se fabrica
  partidos ganados.
- **Entrada de datos** (nombres en el marcador, qué partido toca): requiere un
  canal local del móvil a la tele (BLE, Wi-Fi Direct o punto de acceso). Es caro
  y va en la fase 3+, nunca como requisito.
- Si la tele llegase a ver internet alguna vez, que vacíe su cola sola. Como
  extra silencioso, nunca como requisito.

## Tecnologías

Nada de esto es exigente: es un formulario, una tabla y unas páginas públicas.
Las decisiones que importan son las que afectan a la página que ven los jugadores.

| Capa | Elegido | Alternativas | Por qué |
|---|---|---|---|
| Panel y página pública | **React + TypeScript, con Next.js** | React con Vite (SPA), React Router v7, SvelteKit | SSR para que la página pública cargue rápido con mala cobertura, y vista previa automática al pegar el enlace en WhatsApp. |
| Estilos | Tailwind + componentes sueltos | Sistema de diseño propio | El club juzga por el aspecto, pero un sistema de diseño desde cero se come el MVP. |
| Datos y cuentas | **Supabase** (Postgres, Auth, RLS) | Firebase, backend propio | Datos relacionales de manual; clasificaciones y desempates son SQL corto. |
| Alojamiento | Vercel | Cualquier VPS | Gratis para el piloto, despliegue con un push, nada que administrar un sábado. |
| Generador de rondas | Módulo TypeScript puro, con tests | Servicio aparte | Probable con cientos de combinaciones sin abrir el navegador. |
| Imprimir | Hoja de estilos `@media print` | Generador de PDF | Ctrl+P. Cero dependencias, cero servidor. |
| Salida a WhatsApp | Texto plano + portapapeles + `wa.me` | API de WhatsApp Business | No hay integración ni hace falta. |

**Next.js es React**, no una alternativa a React: mismos componentes, mismo JSX,
mismos hooks, con un router y renderizado en servidor encima. La elección real es
SPA contra HTML de servidor, y la decide un caso concreto: **WhatsApp no ejecuta
JavaScript** al generar la vista previa de un enlace, así que en un SPA todos los
torneos comparten el mismo HTML vacío y el enlace sale desnudo. Para el panel
(tras login, no compartible) un SPA con Vite sería más simple; el problema es que
el mismo proyecto tiene también la parte pública. Si el App Router de Next se hace
cuesta arriba, **React Router v7 en modo framework** hace lo mismo con menos
maquinaria y es igual de válido.

**Sobre Flutter Web** (la tentación obvia, dado que el marcador es Flutter): se
descarta. Manda más de un megabyte antes de pintar nada, dibuja el texto en
canvas y no genera vistas previas de enlace — penaliza justo la pantalla que más
importa, la que abren 24 jugadores en su móvil. La curva de React se paga una
vez; una página pública lenta se paga en cada torneo.

**Sobre el coste, que es la duda que siempre vuelve**: a esta escala los datos son
texto (nombres, cruces, resultados) y **los dos son gratis**. La única diferencia
real es el suelo — Firebase baja a cero si nadie lo usa; Supabase, al salir del
plan gratuito, cuesta del orden de 25 $/mes porque hay una instancia de Postgres
encendida siempre. Son ~300 $/año que cubre la suscripción de un club.

Lo que sí desaconseja Firestore para *este* producto es su modelo de cobro por
documento leído: la página pública está pensada para que la abran 24 personas
varias veces por torneo, y cada carga de la clasificación lee todos los partidos.
En Postgres eso es una consulta, y renderizada en servidor sirve a muchos
visitantes a la vez.

Y el coste que de verdad manda son las horas: la clasificación con desempates es
un `ORDER BY`; «qué jugadores no han sido compañeros» —el corazón del generador
de americanos— es una consulta trivial en SQL y un ejercicio de paciencia en
Firestore; y el corte por impago son ~40 líneas de RLS declarativo, frente a un
`get()` del club dentro de cada regla de seguridad (que además cuesta una lectura).

Se cambiaría de idea si esto fuera una app móvil con sincronización sin conexión
por usuario, que es donde Firebase gana. No es el caso.

**No hace falta**: Docker, microservicios, GraphQL, gestor de estado pesado,
sistema de diseño propio, app nativa.

**Coste de infraestructura**: 0 € con un club piloto (planes gratuitos de Vercel
y Supabase). Del orden de 20-40 €/mes con varios clubes activos. Importa porque
condiciona el precio: se puede cobrar poco por el panel sin perder dinero.

## Cómo saber si la fase 1 funciona

Dos métricas, y ninguna es "número de clubes":

1. **Tiempo desde cero hasta rondas generadas.** Objetivo: menos de 5 minutos.
2. **Porcentaje de torneos que terminan en el panel sin volver al papel.**

Si (2) es bajo, no construir nada más hasta arreglarlo.

## Riesgos vivos

- **Ser más lento que el cuaderno.** Es el riesgo número uno y se mide con
  cronómetro, no se opina.
- **El sábado es en directo**: si falla, es con 24 personas mirando y no hay
  segunda oportunidad con ese club. De ahí el modo degradado (imprimir/exportar).
- **Automatizar tan poco que no lo paguen.** La respuesta es la página pública:
  lo que se paga no es ahorrar trabajo, es parecer un club serio ante sus socios.
  Si esa página no impresiona, el argumento de venta se cae — merece más esfuerzo
  de diseño que el propio panel.
- **Datos personales**: se guardan nombres de socios desde el primer día.

## Sin decidir

- Precio del panel y del hardware.
- Mercado inicial concreto (país/ciudad) y club piloto.
- Algoritmo exacto de generación de rondas del americano — es la única pieza con
  dificultad técnica real del MVP y todavía no está bajado a detalle.
