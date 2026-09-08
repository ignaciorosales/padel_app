# Puntazo Rating

Estado: **el MVP del rating, completo en código. Sin aplicar a la base de datos
todavía** — migraciones 0014, 0015, 0016, 0018 y 0019 escritas y sin correr.
Última revisión: 2026-09-08.

Un sistema de rating propio para toda la red Puntazo, sin depender de la AUP ni
de torneos federados. Complementa [app-jugador.md](app-jugador.md), que describe
la app donde se enseña.

**El principio**: el rating es del **jugador**, nunca del club. Quien tiene 1650
lo tiene juegue donde juegue; los clubes sólo agrupan para hacer rankings
locales. Cuantos más clubes y partidos hay en la red, más preciso se vuelve el
número — y ése es exactamente el efecto de red que se busca.

**Dos conceptos, no uno**:

| | Qué es | Para qué |
|---|---|---|
| **Rating** | número continuo, la fuente de verdad | comparar de verdad, emparejar partidos |
| **División** | 1ª a 8ª, derivada del rating | decirlo en una palabra: "soy tercera" |

Un 1608 y un 1732 son los dos terceras, pero el segundo está a punto de subir.

---

## Lo construido

Todo en [`web/src/lib/rating/`](../../web/src/lib/rating/), puro y con tests:

| Fichero | Qué |
|---|---|
| [`algoritmo.ts`](../../web/src/lib/rating/algoritmo.ts) | `PuntazoRating-v1`: esperado, modificador, K por incertidumbre, confianza |
| [`divisiones.ts`](../../web/src/lib/rating/divisiones.ts) | Escala uruguaya, ascenso y descenso con histéresis, progreso |
| [`motor.ts`](../../web/src/lib/rating/motor.ts) | Procesa el historial: transacciones, divisiones, reconstrucción |
| [`simulacion.ts`](../../web/src/lib/rating/simulacion.ts) | Banco de pruebas: jugadores de fuerza conocida sobre americanos reales |
| [`consultas.ts`](../../web/src/lib/rating/consultas.ts) | Filas de Postgres ↔ motor. Puro, y la mitad que se equivoca |
| [`amistosos.ts`](../../web/src/lib/rating/amistosos.ts) | El ciclo de vida de un amistoso traducido a origen y confianza |
| [`servicio.ts`](../../web/src/lib/rating/servicio.ts) | Lee la red entera, llama al motor, guarda en una transacción |

Y el esquema, en dos migraciones:

| Migración | Qué |
|---|---|
| [`0014_esquema_del_rating.sql`](../../backend/migrations/0014_esquema_del_rating.sql) | `player_ratings`, `rating_transactions`, `player_division_history`, `club_memberships`, `matches.rating_processed_at`, `players.division_declarada` y `aplicar_rating()` |
| [`0015_confirmacion_de_resultados.sql`](../../backend/migrations/0015_confirmacion_de_resultados.sql) | `friendly_matches`, `friendly_match_confirmations`, `players.user_id` y el disparador que confirma |
| [`0016_ambitos_del_ranking.sql`](../../backend/migrations/0016_ambitos_del_ranking.sql) | `clubs.ciudad`, `clubs.pais` y las funciones de ámbito |
| [`0018_torneos_por_rating.sql`](../../backend/migrations/0018_torneos_por_rating.sql) | Rango, divisiones admitidas y la excepción del organizador |
| [`0019_pagina_publica_del_jugador.sql`](../../backend/migrations/0019_pagina_publica_del_jugador.sql) | `players.publico` y las cuatro funciones de la página pública |

Y las pantallas, todas en el panel salvo la última:

| Pantalla | Qué |
|---|---|
| `/panel/[club]/jugadores` | Unificación: quién es quién, con el motivo al lado del botón |
| `/panel/[club]/jugadores/[jugador]` | Perfil: rating, división, progreso, evolución, logros y el interruptor |
| `/panel/[club]/ranking` | Ranking en cuatro ámbitos, con el aviso de «estimado» |
| `/panel/[club]/torneo/[torneo]/nivel` | A quién está abierto el torneo y quién no encaja |
| `/j/[jugador]` | La página pública: el canal de reparto |

### Las tres decisiones que dan forma a la fórmula

**1. Manda ganar o perder.** `S` es 1 ó 0, y el marcador sólo modula entre 0,85 y
1,15. Ganarle a una pareja fuerte importa mucho más que ganar por paliza a una
floja: un sistema que premia las palizas premia jugar contra quien no debe.

Esta decisión **arregló dos problemas de la versión anterior**, que usaba el
margen como resultado:

- Con margen, ganar 6-4 siendo favorito bajaba el rating. Había que ponerle un
  suelo artificial, y el suelo inflaba el rating medio del club unos 2 puntos por
  torneo. **Con `S` de 1 ó 0 el ganador siempre sube y el perdedor siempre baja
  por construcción**: ni suelo ni inflación. Medido: la media de la red se queda
  clavada por muchos torneos que se jueguen.
- Con margen, alguien que declaraba mal su división tardaba **240 partidos** en
  acercarse a su nivel. Ahora recorre 390 puntos en 64.

**2. La incertidumbre decide la velocidad.** Un jugador nuevo tiene que llegar
rápido a su sitio; uno asentado no puede bailar. La desviación arranca en 350 y
se estrecha con cada partido; la `K` sale de ella (80 arriba, 16 abajo).

**3. Ganar nunca baja el rating.** Ya no es una regla que haya que imponer: sale
sola de la decisión 1.

### Constantes de v1

| | Valor | Nota |
|---|---|---|
| Desviación inicial / mínima | 350 / 50 | la mínima es el suelo: nunca se sabe del todo |
| Decaimiento por partido | 0,97 | calibrado abajo |
| K máxima / mínima | 80 / 16 | interpola según la desviación |
| Provisional | < 15 partidos | no aparece en rankings |
| Modificador por marcador | 0,85 – 1,15 | 6-5 abajo, 6-0 arriba |
| Oxidación | 120 días | sin jugar sube la incertidumbre, **nunca baja el rating** |

Sobre la oxidación: quien lleva medio año parado puede haber mejorado o haberse
oxidado, y el sistema no lo sabe. Lo honesto es admitir que sabe menos, no
quitarle puntos por no aparecer — castigar la inactividad sería empujar a jugar,
y eso no es lo que este número mide.

### Confianza por origen

Configurable, porque hoy es una hipótesis:

| Origen | Confianza | Puntúa |
|---|---|---|
| `sin_puntuar` (amistoso sin confirmar) | 0 | no |
| `confirmado` (los cuatro jugadores) | 0,8 | sí |
| `club` | 0,9 | sí |
| `torneo` / `liga` | 1 | sí |
| `marcador` (QR firmado) | 1 | sí |

---

## Divisiones

Escala uruguaya, ocho divisiones. **Datos, no código**: se recalibra en cuanto
haya partidos reales, y añadir otro país es añadir un objeto.

| División | Desde | Rating de partida |
|---|---|---|
| 1ª | 1900 | 1975 |
| 2ª | 1750 | 1825 |
| 3ª | 1600 | 1675 |
| 4ª | 1450 | 1525 |
| 5ª | 1300 | 1375 |
| 6ª | 1150 | 1225 |
| 7ª | 1000 | 1075 |
| 8ª | — | 950 |

Quien dice "no sé" empieza en 1375.

**Histéresis, para que la división no baile.** Para subir hay que cruzar el
umbral **y sostenerlo 5 partidos**; un solo partido por debajo reinicia la
cuenta. Para bajar hay que caer 50 puntos por debajo del suelo propio y
sostenerlo otros 5. Rozar el límite desde arriba no descabalga a nadie, y se sube
de una división en una aunque el rating pegue un salto.

Cada cambio queda registrado con fecha, rating y tipo.

---

---

## Cómo se guarda

**Una sola puerta de escritura**: la función `aplicar_rating()`. El cliente de
Supabase no tiene transacciones —cada `insert` es la suya—, y aquí hay cuatro
escrituras que tienen que entrar juntas: un rating sin su transacción es un
número que nadie puede explicar, y un partido marcado como procesado sin su
rating se pierde para siempre. El cuerpo de una función de Postgres **es** una
transacción, así que las cuatro viven dentro.

Sólo la puede llamar `service_role`. Las tablas de rating no tienen políticas de
escritura a propósito: un rating escrito a mano es un rating que ya no se puede
reconstruir.

**Lo que da la idempotencia es el índice único `(match_id, player_id)`**, no la
marca `rating_processed_at`. Entre leer que está a null y escribirla hay una
ventana donde caben dos procesos; los dos calcularían lo mismo y el segundo
choca con el índice, y su transacción se cae entera. La marca es el índice de
trabajo: sirve para contar lo pendiente sin recorrer la historia.

**El servicio reconstruye entero en cada pasada**, y no es un apaño. `procesar()`
acepta ratings de partida pero no un estado previo: la desviación, la cuenta de
partidos y la de la histéresis no se pueden inyectar. Pasarle sólo los partidos
nuevos devolvería a todo el mundo a la desviación de un recién llegado, y un
torneo movería los ratings el triple de lo que debe. Cuando la red no quepa en
memoria, el camino es ampliar `EntradaDelMotor` para aceptar el estado completo y
puntuar incremental sólo cuando lo nuevo sea posterior a todo lo procesado.

---

## Amistosos, y por qué no viven en `matches`

Los cuatro jugadores de `matches` son `tournament_players`: inscritos de un
torneo, con el nombre escrito a mano esa mañana. Los de un amistoso son
`players`: personas. Las claves ajenas apuntan a otra tabla, así que forzarlo
obligaría a inventar un torneo fantasma por cada partido suelto.

Lo que sí comparten es todo lo de después: las dos clases entran al mismo motor y
dejan transacciones en la misma tabla, con dos columnas anulables y la garantía
de que exactamente una está puesta.

**Un amistoso nace sin puntuar.** Pasa a `confirmado` cuando los cuatro lo
aceptan, y uno que dice que no lo tumba — asimétrico a propósito: el coste de no
puntuar un partido real es que no cuenta, el de puntuar uno inventado es que el
rating deja de significar nada.

El recuento lo hace un disparador y no la app, porque el último de los cuatro en
aceptar es el que confirma y dos móviles pueden aceptar a la vez. Y un amistoso
que carga el club no espera a nadie: es la autoridad de sus pistas, y el 0,9 de
confianza ya dice que se le cree más que a los propios jugadores.

---

## Auditoría y reconstrucción

**Nunca se toca un rating sin dejar escrito cómo se llegó a él.** Cada partido
produce una transacción por jugador: antes, después, delta, probabilidad que se
esperaba, fuerza de los rivales y **versión del algoritmo**.

De ahí salen tres cosas que no se pueden tener de otra forma:

- **explicarle a alguien por qué bajó**, que es la mitad de que se crea el número;
- el **gráfico de evolución** del perfil;
- **rehacer la historia entera** cuando cambie la fórmula — y va a cambiar. El
  rating se reconstruye, no se acumula: entra el historial, sale el estado.

Y el motor es **idempotente**: el mismo partido no puntúa dos veces, así que
reprocesar de más es inofensivo. Es lo que hace falta cuando un proceso se
reintenta.

---

## Lo que dice la simulación

Con veinticuatro jugadores de fuerza conocida jugando americanos generados por el
mismo código que usa el panel ([`lib/rating/simulacion.ts`](../../web/src/lib/rating/simulacion.ts)):

| Torneos | Orden | Escala | Media de la red | Confianza | Cambios de división |
|---|---|---|---|---|---|
| 1 | 0,946 | 1,00 | 1512,7 | 49 % | 1 |
| 4 | 0,958 | 1,08 | 1513,0 | 93 % | 9 |
| 16 | 0,990 | 1,20 | 1513,0 | 100 % | 11 |

Tres lecturas:

- **El orden es bueno desde el primer torneo** (0,95) y la escala se conserva.
- **La media no se mueve**: 1513,0 en todos los horizontes. Sin inflación.
- **La confianza llegaba al 100 % en dos meses de americanos**, que no es
  creíble. Por eso el decaimiento pasó de 0,92 a 0,97: ahora son 37 % a los
  quince partidos, 60 % a los treinta y 97 % pasados los cien.

**Lo que hay que vigilar**: la escala se ensancha con el tiempo (1,20 a los
dieciséis torneos). No es un fallo, pero si sigue creciendo con datos reales, las
bandas de 150 puntos se quedarán estrechas y habrá ascensos de más.

---

## Ya integrado con el resto

El historial y el ranking usan el motor y **la misma lista de orígenes**: si el
historial tuviera su propia idea de qué es un partido "verificado", tarde o
temprano diría del mismo partido algo distinto de lo que dice el ranking.

- [`lib/historial/`](../../web/src/lib/historial/) — el récord oficial cuenta lo
  mismo que puntúa para el rating.
- [`lib/jugador/ranking.ts`](../../web/src/lib/jugador/ranking.ts) — ordena
  `RatingJugador`, saca la división de la escala y deja fuera a los
  provisionales.
- [`lib/jugador/desde-el-panel.ts`](../../web/src/lib/jugador/desde-el-panel.ts)
  — de las filas del panel a partidos puntuables.

## Logros

Todo en [`web/src/lib/logros/`](../../web/src/lib/logros/), calculado y no
guardado — un logro es una consulta sobre el historial, igual que el rating es una
consulta sobre los partidos. Guardarlos obligaría a migrarlos cada vez que se añade
uno, y a que un logro nuevo no exista para quien ya se lo había ganado.

**Doce de diecisiete se sacan sin ganar un solo partido.** No es un descuido: el
rating ya premia jugar bien contra gente buena, así que unos logros que premiaran
lo mismo serían una segunda tabla que sólo gana quien ya gana. Los logros premian
lo que el rating no puede premiar — aparecer, apuntar el resultado, confirmar el
del rival, jugar con gente nueva — y son la única recompensa que tiene confirmar el
amistoso de otro.

Ninguno se puede perder. Un logro que se pierde es una amenaza, y el sistema ya
tiene un número que baja.

---

## La página pública

`/j/<id>`, **apagada por defecto**. Un rating dice lo bueno que eres y con qué
frecuencia juegas; que sea interesante no lo hace público.

Lo que no enseña es tan deliberado como lo que enseña: **ningún nombre de otra
persona.** El historial de alguien lleva dentro con quién jugó, y esas otras tres
personas no han encendido nada — así que las funciones de la 0019 devuelven ids y
nunca nombres de terceros, y la página no puede enseñarlos ni por descuido porque
no los tiene.

Hoy la enciende el club desde el perfil, que es la deuda declarada del asunto: la
app del jugador no existe y el club es el único con sesión que puede preguntarle.
Cuando exista, la política se estrecha a `players.user_id = auth.uid()`.

---

## Pendiente

Lo primero, y no es código: **aplicar 0014, 0015, 0016, 0018 y 0019 a Supabase.**
La base de datos es la misma para las dos lanes, así que se avisa antes
(docs/lanes.md). Nada de lo de arriba funciona en ejecución hasta entonces: el
código está probado, el esquema no está aplicado.

Después:

1. **Pantallas de amistosos.** El esquema, la confirmación y el disparador están;
   falta dónde carga un amistoso el club y dónde lo confirman los cuatro. Vive con
   la app del jugador, porque son los jugadores los que confirman.
2. **La pantalla de después del partido.** `despuesDelPartido()` ya da el
   1532 → 1547 de los cuatro; falta pintarla donde se mete el resultado.
3. **Imagen de vista previa** de la página pública, como la que ya tiene un torneo
   (`/t/[club]/[torneo]/opengraph-image`). El enlace se comparte por WhatsApp y ahí
   la imagen es la mitad del reparto.
4. **La app del jugador**: es lo que convierte todo esto en producto. Ver
   [app-jugador.md](app-jugador.md).
5. Más adelante: matchmaking, interclubes, rating de club, temporadas.


## Sin decidir

- **Nombres en el código.** El repositorio es íntegramente español, así que el
  motor usa `RatingJugador`, `TransaccionDeRating`, `EstadoDeDivision`. Si se
  prefieren los nombres de la especificación (`PlayerRating`, `RatingTransaction`)
  hay que cambiarlos ahora, no después.
- **Divisiones femeninas y partidos mixtos**: las categorías van separadas por
  género en casi todas partes; el rating no tiene por qué. Es la misma decisión
  pendiente que en [app-jugador.md](app-jugador.md).
- **Peso de los partidos cortos.** Una ronda de americano a 24 puntos es menos
  evidencia que un partido a dos sets, y v1 los trata igual. Se midió que importa;
  se dejó fuera para no separarse de la especificación sin datos reales.
- Nada: `lib/nivel/` ya se retiró. El banco de simulación vive ahora dentro de
  `lib/rating/` y el Elo anterior se borró, para que no queden dos sistemas de
  rating conviviendo.
