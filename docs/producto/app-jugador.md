# App del jugador — plan

Estado: **planeado, sin empezar a construir.** Última revisión: 2026-08-31.

Es la tercera pata de Puntazo, la que en [docs/producto/README.md](README.md)
figura como **fase 4**. Este documento la baja a detalle: qué se construye, con
qué datos, en qué orden y qué se deja fuera a propósito.

Versión presentable del mismo plan, para enseñar a terceros:
<https://claude.ai/code/artifact/94b192d2-83c7-4cad-aaa7-6c8fb870bd6d>

Las otras dos patas orbitan alrededor de ésta:

| App | De quién es | Qué cubre |
|---|---|---|
| Marcador (`app/` + `firmware/`) | de la pista | lo que pasa **durante** el partido |
| Panel (`web/`) | del club | lo que el club **organiza** |
| **App del jugador** | **del jugador** | **su vida como jugador de pádel** |

---

## La corrección que manda sobre todo lo demás

La tentación es decir "ya tenemos el marcador, luego tenemos los datos". **Hoy
no los tenemos.** El marcador conoce cada punto —`ScoringState` guarda la pila
entera de `MatchScore`— pero:

- no tiene red, y así se queda ([README raíz](../../README.md));
- no sabe **quién** juega: hay equipo azul y equipo rojo, no personas;
- no exporta nada. El QR firmado está **diseñado, no construido** (fases 3-4 del
  plan de producto).

Así que el gancho bonito del que se habla siempre —*terminas de jugar y el
partido aparece solo en tu móvil*— es el **final** del camino, no el principio.

**La fuente de datos que sí existe hoy es el panel del club.** Un americano de
24 personas y 8 rondas produce 48 filas en `public.matches`, cada una con cuatro
jugadores identificados, pista, fecha y resultado. En una mañana. Eso es más
partidos por jugador que los que nadie cargaría a mano en un mes.

**Corolario**: la app del jugador no se construye sobre el hardware. Se
construye sobre los torneos, y el hardware la multiplica después.

---

## Qué se puede calcular con los datos de hoy

Con `matches` (4 jugadores + `juegos_a`/`juegos_b`) y `tournaments` (fecha,
club, minutos por ronda):

| Sale hoy | Cómo |
|---|---|
| Victorias, derrotas, % de victorias, racha | contar |
| Juegos a favor / en contra / diferencia | sumar |
| **Nivel Puntazo** | Elo sobre diferencia de juegos (abajo) |
| Compañeros: con quién, cuántas veces, % de victorias | el americano rota compañero, así que **regala** pares |
| Rivales, cara a cara, "némesis" | ídem |
| **Tu puesto en cada americano** | ya lo calcula `clasificacion.ts` en el panel |
| Ranking del club, de amigos, por categoría | `ORDER BY` |
| Resumen mensual ("wrapped") | agregación |
| Horas jugadas | **estimadas** (`rondas × minutos_por_ronda`), no medidas |

| No sale hasta el QR del marcador | Por qué |
|---|---|
| Puntos jugados y ganados, % de puntos | el panel guarda juegos, no puntos |
| Puntos de oro, tie-breaks, remontadas, mejor racha de puntos | ídem |
| Sets | el americano se juega a juegos; no hay sets que guardar |
| Duración real, hora de inicio y fin | nadie la mide |

Es decir: **de las seis funciones del brief, cinco se pueden construir ya.** La
que no —la pantalla de estadísticas finas del partido— es justo la que llega con
el QR y convierte la app de buena en única. Se diseña ahora el sitio donde va a
encajar, y se deja vacío.

---

## La pieza que decide si esto existe: la identidad

`tournament_players.nombre` es **texto libre por torneo**. "Nacho R." en el
torneo de marzo y "Ignacio Rosales" en el de abril son dos filas sin ninguna
relación entre ellas.

Sin identidad global no hay historial, ni nivel, ni ranking, ni cara a cara.
**Nada de este documento existe sin resolver esto primero.**

El diseño:

- Una tabla `players` global: la persona real, una fila para siempre.
- `tournament_players` gana una referencia opcional a `players`: sigue siendo la
  fila del torneo, pero puede apuntar a una persona.
- **El club es quien une**, no un algoritmo: el encargado ya sabe que "Nacho R."
  es Ignacio. Una pantalla de "estos nombres parecen la misma persona" en el
  panel, y confirma con un toque.
- **El teléfono es la llave.** Ya se recoge en `tournament_players.telefono`.
- El jugador reclama su ficha desde la página pública del torneo; el club lo
  aprueba. Dos vías hacia la misma fila.

### Cómo se propone una unificación

El club confirma, pero alguien tiene que ordenarle ciento veinte nombres antes.
Ese motor está en [`web/src/lib/identidad/`](../../web/src/lib/identidad/) y
funciona con cuatro señales: teléfono normalizado, nombre completo, apellido
(entero o por inicial) y nombre de pila (entero o por apodo). Devuelve una
puntuación **y los motivos en texto**, porque un porcentaje a secas no se
confirma con confianza: "mismo apellido, el nombre encaja como apodo" sí.

Tres decisiones que valen más que los pesos:

- **Dos inscritos del mismo torneo nunca son la misma persona.** Nadie juega un
  americano contra sí mismo. Sale gratis del propio modelo de datos, descarta
  media lista de falsos positivos y es la única regla del motor que no es una
  heurística.
- **Mismo teléfono y distinto apellido no une: avisa.** Es la pareja o los dos
  hermanos que se apuntan con el móvil de casa. Mezclar ahí el historial de dos
  personas es el peor error posible, y no se deshace bien.
- **Los diminutivos regulares salen de la propia palabra** (Santi de Santiago,
  Fede de Federico). Sólo hay lista para los irregulares —Nacho, Pepe, Tincho—,
  que es una tabla para ampliar, no un algoritmo.

Para el primer día hay además un agrupador: sin ninguna persona creada todavía,
junta los inscritos sueltos de varios torneos para que el club dé de alta una
persona por grupo en vez de ciento veinte a mano.

### Esto hay que hacerlo ahora, no en la fase 4

Es el único punto de este documento con urgencia real. Las dos tablas y el
enlace cuestan poco **hoy**; retrofitear identidad sobre dos años de nombres
sueltos cuesta diez veces más y sale mal.

Si la identidad entra durante la fase 1, el día que se construya la app habrá
**meses de historial acumulado** en lugar de cero. Si no entra, la app nace
vacía y hay que pedirle al jugador que cargue partidos a mano — que es
exactamente como mueren estas aplicaciones.

Lo que hay que meter en la fase 1, y nada más:

- [x] **la unidad del resultado** — resuelta por la otra lane:
      `tournaments.unidad_marcador` (`juegos` / `sets` / `puntos`);
- [x] **`formato` como dato de verdad** — resuelto por la otra lane: ya tiene
      `check (formato in ('americano', 'parejas'))`;
- [x] **el resultado del evento con forma variable** — resuelto por la otra
      lane: `rounds.fase` da la ronda alcanzada en un cuadro, y la clasificación
      individual da el puesto en un americano;
- [x] tabla `players` + referencia desde `tournament_players` →
      [`0009_identidad_del_jugador.sql`](../../backend/migrations/0009_identidad_del_jugador.sql);
- [x] cálculo del nivel, aislado y con tests →
      [`web/src/lib/rating/`](../../web/src/lib/rating/) — hoy es **Puntazo
      Rating**, ver [puntazo-rating.md](puntazo-rating.md);
- [x] motor de unificación de nombres →
      [`web/src/lib/identidad/`](../../web/src/lib/identidad/);
- [ ] en la página pública del torneo, cada nombre es un enlace —aunque al
      principio lleve a una página tonta;
- [ ] pantalla de unificación de nombres en el panel del club (el motor ya está;
      falta la pantalla, y sus ficheros los tiene abiertos la otra lane);
- [ ] **el tope del marcador** (a 24, a 6 juegos, a tiempo): hay unidad, pero
      todavía no se sabe a cuánto se jugaba. `P` lo deduce del propio marcador,
      que es suficiente para el Elo pero no para escribir bien un resultado.

**Sobre el número de migración**: `0009` se toma sabiendo que la otra lane tiene
`0004`–`0008` en su carpeta, todavía sin commitear. La reserva de verdad se hace
en `develop` ([CLAUDE.md](../../CLAUDE.md) ▸ regla 2), así que si esa numeración
se mueve al integrar, esta migración se renumera con ella. No toca ninguna tabla
que ellas modifiquen: sólo añade `players` y una columna a `tournament_players`.

---

## Los tres orígenes de un partido

Un partido llega por una de tres vías, y **cada una tiene un permiso distinto**:

| Origen | Quién lo mete | ¿Mueve el nivel? | Qué alimenta |
|---|---|---|---|
| **Torneo** — resultado del panel | el club | **sí** | todo |
| **Amistoso** — cargado a mano | un jugador | **no** | historial, compañeros, rivales, actividad, logros |
| **Marcador** — QR firmado (fase 4c) | el hardware | **sí** | todo + estadísticas de punto a punto |

### Por qué el amistoso no puntúa, y por qué eso lo abarata

El miedo al partido cargado a mano es el fraude: alguien se fabrica victorias y
el ranking deja de significar nada. **Si el amistoso no toca el Elo, nadie tiene
motivo para mentir**, y entonces el flujo puede ser barato:

- **lo carga uno solo**, en veinte segundos, sin que los otros tres confirmen;
- los demás reciben aviso y pueden **corregir el resultado o quitarse**;
- se ve etiquetado como amistoso en todas partes. No se esconde, no puntúa.

Si en cambio los amistosos puntuaran, harían falta cuatro confirmaciones, avisos,
recordatorios y una pantalla de disputas — y la mitad de los partidos se
quedarían a medio confirmar para siempre.

### Qué gana el jugador cargando un amistoso

Si no da nivel, tiene que dar otra cosa o nadie lo carga:

- entra en el **historial** y en las horas jugadas;
- cuenta para **compañeros, rivales y cara a cara** (que es lo que se comparte);
- cuenta para los **logros de actividad** (partidos jugados, compañeros
  distintos, meses seguidos jugando);
- **no** cuenta para el porcentaje de victorias oficial ni para el ranking.

La línea es fácil de explicar en una frase, y esa frase va en la interfaz:
**lo verificado alimenta la competición; el amistoso alimenta tu actividad.**

### Y es lo que vende el hardware

Cuando llegue la fase 4c, un amistoso jugado en una pista con Puntazo **sí sube
el nivel**, porque llega firmado por el marcador. Ésa es literalmente la frase
que hace que un socio le pregunte a su club si va a poner Puntazo. La distinción
verificado/declarado no es burocracia: es el producto.

---

## Torneo, americano, mexicano, pozo: no son lo mismo

En el modelo de datos, **`tournaments` es el evento y `formato` es cómo se
juega**. Hoy sólo existe `'americano'` y la columna **no se lee en ningún
sitio** — es decorativa. En cuanto llegue la app del jugador deja de serlo,
porque el formato cambia lo que significa el resultado.

| Formato | Compañero | Cómo se emparejan las rondas | Quién gana |
|---|---|---|---|
| **Americano** | rota cada ronda | calendario fijo: todos con todos y contra todos | un **jugador**, por puntos individuales |
| **Mexicano** | rota cada ronda | **según la clasificación en vivo**: los de arriba juegan entre ellos | un **jugador** |
| **Pozo** | según variante | por pista: se sube o se baja según el resultado | un **jugador** |
| **Parejas fijas** (liga, cuadro) | el mismo siempre | sorteo o cabezas de serie | una **pareja** |

Ojo con el vocabulario: en Argentina «pozo» se usa como sinónimo de torneo
americano; en España suele ser el de subir y bajar de pista. **El nombre del
formato es una etiqueta por región, no un enum global** — igual que las
categorías.

### Los dos, y antes de lo previsto

Cuando se escribió la primera versión de este documento el panel sólo hacía
americano: `formato` ni se preguntaba en el formulario ni se escribía en el
insert, la clasificación era la de un americano individual y no existía la pareja
como entidad. **Eso está cambiando ahora mismo en la otra lane**: el panel va a
tener los dos, americano y torneo de parejas fijas.

Es una buena noticia para el nivel —abajo, en lo de coser las escalas entre
clubes— pero **adelanta cuatro decisiones que este documento tenía aparcadas en
"fase 2, ya se verá"**. Dejan de poder esperar porque ya no son hipotéticas: en
cuanto los dos formatos escriban en las mismas tablas, cualquiera de las cuatro
mal resuelta se arregla con una migración de datos, no con un cambio de código.

**1. La unidad del resultado, que ahora es un problema de verdad.** Un americano a
24 puntos y un partido de cuadro a dos sets van a acabar los dos como dos enteros
en `matches.juegos_a`/`juegos_b`. Sin un campo que diga de qué son, el Elo compara
cosas distintas **desde el primer torneo**, no algún día. Es el único punto de
esta lista que ya rompe con lo que hay escrito hoy.

**2. La pareja como entidad, y el choque de lanes que trae.** Las parejas fijas
se inscriben por pareja, no por jugador, así que `tournament_players` cambia — y
es **la misma tabla** a la que este plan le añade la referencia al jugador global.
Dos lanes tocando esa tabla a la vez es exactamente el caso que
[CLAUDE.md](../../CLAUDE.md) manda resolver antes de escribir: **el número de
migración se reserva en `develop`**, y conviene que las dos cosas entren en la
misma migración en vez de en dos que se pisen.

**3. El resultado del evento ya no puede ser un entero.** En americano es un
puesto (3º de 24); en un cuadro es una ronda alcanzada (perdió en semifinales) o
el título. La ficha de evento del MVP (D2) nace con un resultado de forma
variable según formato, no con un `puesto int`.

**4. Cuánto vale un partido de parejas fijas para el Elo.** Ya no es una pregunta
para más adelante. Recomendación: **misma fórmula, menos peso**, porque durante
todo el torneo tu resultado y el de tu compañero son el mismo dato y el Elo
individual no puede separaros. Y guardar la pareja en el partido cuando exista,
para poder derivar un Elo de pareja más tarde sin otra migración.

Lo que sigue protegido sin hacer nada es el **Elo recalculable**: como se guarda
el `Δ` de cada partido y su orden, si el peso de las parejas fijas se elige mal se
cambia el número y se rehacen todos los niveles desde cero. Esa decisión se tomó
por otro motivo y aquí paga sola.

**Y una consecuencia buena, que compensa las cuatro anteriores**: los torneos de
parejas fijas por categoría son justamente donde se cruzan jugadores de clubes
distintos. Son los partidos que **cosen las escalas de Elo entre clubes** — el
problema más serio de todo este plan. Tenerlos desde el principio lo resuelve
mucho antes de lo que estaba previsto.

### Las cuatro consecuencias que sí tocan este plan

**1. El resultado no siempre está en juegos.** En americano y mexicano lo normal
es jugar partidos cortos **a un número fijo de puntos** (16, 24 o 32) o a tiempo,
y la clasificación suma los puntos individuales; en parejas fijas se juega a sets
y juegos. Hoy `matches.juegos_a`/`juegos_b` guarda dos enteros **sin decir de qué
son**. Un `15-9` de un partido a 24 puntos y un `6-4` a juegos son la misma fila
en la base de datos y no significan lo mismo.

> Lo que le pide al panel: que el torneo (o el partido) declare la **unidad**
> —puntos, juegos o sets— y el **tope** —a 24, a 6 juegos, a tiempo—. Es un par
> de campos. Sin ellos, el Elo no puede comparar entre formatos, y la app del
> jugador no puede ni escribir bien el resultado en pantalla.

**2. Un americano pesa ocho veces y un cuadro tres.** Una mañana de americano son
8 partidos y por tanto **8 actualizaciones de Elo**; un cuadro de parejas fijas
son 3 partidos largos. Sin corregirlo, el ranking lo dominan los americanos por
puro volumen. La corrección va en el peso, no en el formato (abajo).

**3. El americano es el mejor formato posible para alimentar un Elo
individual**, y no es casualidad: al rotar compañero cada ronda, tu resultado
deja de estar pegado al de una sola persona y el sistema puede separar lo que
aportas tú de lo que aporta tu pareja. En parejas fijas pasa lo contrario —
durante todo el torneo tu resultado y el de tu compañero son el mismo dato.
**El americano es el formato que mejor alimenta el nivel**, y es el que el panel
ya hace bien. A las parejas fijas hay que bajarles el peso (arriba) — a cambio de
que sean ellas las que conectan clubes.

**4. El mexicano empareja por clasificación en vivo.** En las últimas rondas
juegas contra quien lleva tus mismos puntos *ese día*, no contra un rival
cualquiera. Eso da partidos más informativos, pero sesga: quien va ganando se
cruza con los que van ganando, así que **el ganador de un mexicano sube menos Elo
del que parecería justo**. Es aceptable y no se corrige; se documenta.

### Y una consecuencia de producto, no técnica

En un americano **el resultado del evento no es la suma de tus partidos**: es tu
puesto en la clasificación individual. La gente dice *«salí tercero en el
americano del sábado»*, no *«gané cinco de ocho»*.

Así que el historial de la app **se agrupa por evento, no por partido**: una
ficha de americano con tu puesto, tus puntos y tus partidos dentro. Un torneo de
parejas fijas, en cambio, sí es una lista de partidos con una pareja.

---

## El nivel: un Elo, y la categoría como su traducción

> **Nota (2026-09-08).** Esta sección describe la primera versión del cálculo.
> El sistema definitivo es **Puntazo Rating**, especificado y construido aparte
> en [puntazo-rating.md](puntazo-rating.md): cambia el resultado de margen a
> ganar/perder, la escala de divisiones y el arranque en frío. Lo que sigue se
> mantiene por el razonamiento y las mediciones, que siguen valiendo.

### Por qué Elo y no puntos acumulados

Un ranking por puntos acumulados premia **jugar mucho**. En un club donde uno
juega tres torneos al mes y otro uno, sale un ranking de asistencia. El Elo mide
cómo juegas, no cuánto, y funciona con pocos partidos.

### La fórmula

- **Rating de la pareja** = media de los dos jugadores.
- **Esperado**: `E = 1 / (1 + 10^((Rrival − Rpropio) / 400))`.
- **Resultado real, con margen**: `S = a / (a + b)`, donde `a` y `b` son el
  resultado en la unidad que sea (puntos, juegos o sets). Un 6-0 vale 1,00; un
  6-4 vale 0,60; un 15-9 a 24 puntos vale 0,63. En americano casi todo se juega a
  tiempo o a puntos, así que **el margen es la única señal de "cuánto" que
  existe** y hay que usarla.
- **Ajuste**: `Δ = K × P × (S − E)`. El `(S − E)` es el mismo para los dos
  miembros de la pareja, pero **cada uno lo aplica con su propia `K`**: un
  jugador provisional tiene que moverse rápido aunque le toque de compañero un
  veterano asentado.
- **K variable**: 40 mientras el nivel es provisional, 24 después, 16 por encima
  de la primera categoría. Más movimiento cuando se sabe poco del jugador.
- **Provisional se mide en partidos equivalentes, no en partidos.** Ocho rondas
  de americano son ocho partidos pero poco más de uno de información: contarlos a
  secas daba por asentado a alguien después de un solo sábado. El umbral está en
  8 partidos equivalentes, que son unas seis mañanas de americano.
- **P, el peso del partido**: `P = min(1, tamaño / referencia)`. El tamaño se
  traduce a puntos equivalentes (1 juego ≈ 7 puntos, 1 set ≈ 70) y la referencia
  es un partido a dos sets, unos 140. Una ronda de americano a 24 puntos sale en
  **0,17**: las ocho de una mañana suman poco más de un partido de verdad. Las
  parejas fijas llevan además un `0,7` encima, por lo de arriba.

**Sin `P` el ranking lo ganan los americanos.** Una mañana de americano son ocho
partidos y por tanto ocho ajustes; un cuadro de parejas fijas son tres partidos
largos. El peso es lo que hace que ocho partidos cortos y tres largos muevan una
cantidad parecida de Elo, que es lo justo.

**Regla de producto que rompe la fórmula a propósito: ganar nunca baja el
nivel.** Con margen, ganar 6-4 siendo favorito da `S = 0,60` contra un `E = 0,70`
y el Elo baja. Es matemáticamente correcto y es indefendible en la pantalla de un
jugador que acaba de ganar.

**Dónde se pone el suelo importa más de lo que parece.** La primera versión lo
puso sobre el ajuste final: si ganabas y el `Δ` salía negativo, se sustituía por
`+1`. El efecto medido en simulación fue que en un partido de favorito **subían
los dos lados** —el ganador por el suelo, el perdedor por haber perdido mejor de
lo esperado— y el nivel medio del club crecía unos **2 puntos por torneo y
jugador**: en dos temporadas, todo el club asciende de categoría sin que nadie
haya jugado mejor.

El suelo va sobre `(S − E)`, antes de multiplicar. Así lo que gana un lado es
exactamente lo que pierde el otro, el nivel medio no se mueve ni un punto por
muchos torneos que se jueguen, y la promesa se mantiene. El precio es que el que
pierde siempre baja, aunque haya perdido mejor de lo esperado.

### El arranque en frío: la categoría es la semilla

Al reclamar la ficha, el jugador declara su categoría (o la pone el club, que la
sabe mejor). **El Elo inicial es el centro de la banda de esa categoría.** Eso
resuelve el problema de que todos empiecen en 1500 y hagan falta veinte partidos
para separarse.

Hasta llegar al umbral el nivel se muestra como **provisional** y el jugador no
aparece en el ranking.

**Y no es una comodidad: es lo que sostiene todo.** Medido en simulación, con
veinticuatro jugadores de fuerza conocida jugando americanos de verdad:

| | Sin semilla | Con semilla por categoría |
|---|---|---|
| Orden de la tabla tras 4 torneos | correcto (0,95) | correcto (0,98) |
| Escala recuperada | **4 %** | **100 %** |
| Dos clubes separados 300 puntos de verdad | los dos acaban en 1500: **diferencia 0** | diferencia **275** |

Sin semilla el orden sale bien pero **todo el mundo cae en la misma categoría**,
porque la distancia real entre jugadores no se recupera: partiendo todos del
mismo número, cada partido corto mueve tan poco que hacen falta años. Y el
ranking entre clubes que nunca se cruzan no es que sea impreciso: **dice que son
iguales cuando no lo son**.

### La escala de categorías

En pádel el nivel se habla en categorías, no en números. En Argentina la APA usa
**ocho, de 8ª a 1ª**, con subdivisión masculina y femenina; en España se usa de
1ª a 5ª o 6ª y cambia por federación y hasta por club. Así que **no es un enum en
el código, es una tabla de configuración por región**: nombre, banda de Elo,
orden — la misma decisión que con el nombre del formato.

Punto de partida sobre el reparto argentino, para calibrar con datos reales:

| Categoría | Banda de Elo |
|---|---|
| 1ra | ≥ 2050 |
| 2da | 1900 – 2050 |
| 3ra | 1750 – 1900 |
| 4ta | 1600 – 1750 |
| 5ta | 1450 – 1600 |
| 6ta | 1300 – 1450 |
| 7ma | 1150 – 1300 |
| 8va / iniciación | < 1150 |

Bandas de **150 puntos**: es el ancho que hace que la categoría de arriba gane
alrededor del 70 % de los cruces, que es aproximadamente lo que pasa en la
realidad. El número se recalibra con los primeros torneos; por eso la tabla es
datos, no código.

### Quien declara mal su categoría no se arregla solo

El otro hallazgo de la simulación, y es incómodo: un jugador de 2ª que se declara
6ª **sigue apareciendo como 5ª después de doscientos cuarenta partidos**. Subir la
`K` para corregirlo antes pondría a temblar el nivel de todos los demás, que es
peor que el problema.

La respuesta no es matemática, es de producto: **detectarlo y preguntar.** Si
alguien gana sistemáticamente más de lo que su nivel predice, su nivel de partida
está mal — y eso se ve enseguida. Medido: el impostor sale **el primero de
veinticuatro tras un solo torneo**, y a los dos torneos no hay ningún falso
positivo. Una semilla mal puesta es un problema de dato de entrada, y el club la
corrige en un toque.

**La categoría es una vista del Elo**, no un campo editable — salvo la semilla
inicial. Y con **histéresis**: se sube al cruzar el umbral, pero sólo se baja 40
puntos por debajo de él y nunca por un solo partido. Un jugador que cambia de
categoría cada sábado deja de creerse el sistema entero.

**La barra hacia la siguiente categoría es el motor de enganche.** "Te faltan 38
puntos para 3ra" es infinitamente más motivador que "1712 de Elo".

### El problema real del ranking entre clubes

El Elo sólo compara de verdad a quienes están **conectados por partidos**. Dos
clubes que nunca se cruzan tienen dos escalas distintas que *parecen* la misma:
en un americano cerrado de 24 personas la media del grupo se conserva, así que un
club fuerte y uno flojo pueden acabar con distribuciones idénticas.

Tres mitigaciones, en orden de importancia:

1. **La semilla por categoría es el ancla compartida.** La categoría ya es el
   sistema de referencia nacional que todo el mundo usa; sembrar con ella pone a
   los dos clubes en la misma escala desde el principio. Es la razón de más peso
   para acompasar el Elo a las categorías, más allá de que se entienda mejor.
2. **El ranking del club siempre es real; el ranking entre clubes se marca como
   estimado** hasta que haya suficientes partidos cruzados. Y no se decide a ojo:
   [`ranking.ts`](../../web/src/lib/jugador/ranking.ts) calcula los **grupos
   conectados** por partidos y avisa si la tabla abarca más de uno. Dentro de un
   club siempre sale uno solo —todos han jugado americanos juntos—, que es
   exactamente por lo que el del club se puede enseñar de entrada.
3. Los **torneos abiertos** y los jugadores que pertenecen a dos clubes son los
   que cosen las escalas. Cada uno de esos partidos vale por diez de los otros.

### El Elo se recalcula, nunca se acumula

Se guarda el `Δ` de cada partido y el orden en que se procesaron, para poder
**recalcular todos los niveles desde cero** cuando cambie la fórmula — y va a
cambiar. Mismo criterio que la `semilla` que ya se guarda en `tournaments` para
reproducir un cuadro. Un Elo que sólo existe como contador incremental es un
número que no se puede arreglar nunca.

El cálculo vive en el servidor, en un módulo puro con tests, como el generador de
rondas. Nunca en el cliente: es la cifra que la gente va a intentar mover.

---

## El bucle, hoy

```
el club monta el torneo (ya lo hace)
   └─► la página pública la abren 24 jugadores (fase 1, ya prevista)
          └─► "este soy yo"  ──►  ficha reclamada
                 └─► historial + nivel + ranking del club
                        └─► vuelve el sábado siguiente
```

Lo importante: **cada casilla ya iba a ocurrir sin la app del jugador.** La app
no crea tráfico, lo recoge. Los 24 móviles que abren la página del torneo son el
canal de adquisición, y es gratis.

---

## Alcance del MVP (fase 4a)

Tres pestañas: **Inicio, Historial y Perfil**. El brief propone cinco (Inicio /
Jugar / Competir / Stats / Perfil), pero "Jugar" y "Competir" estarían vacías, y
una pestaña vacía cuesta más credibilidad de la que da tenerla puesta.

Y el inicio no es el perfil: el perfil no cambia, así que no se abre. El inicio
tiene que traer algo distinto cada vez.

### A · Identidad y acceso

| | Función | Nota |
|---|---|---|
| A1 | Reclamar la ficha desde la página pública del torneo | Ver nunca pide cuenta. Reclamar sí. |
| A2 | Identidad unificada entre torneos | La pieza estructural. Sin ella no hay nada. |
| A3 | Aprobación del club | El encargado confirma que esa persona es ese nombre. |
| A4 | Declarar tu categoría al entrar | **Es la semilla del Elo, y sin ella el nivel no funciona** (ver arriba). Un desplegable, una vez. |
| A5 | Aviso al club de quien parece estar en otra categoría | Una semilla mal puesta no se corrige sola; se detecta en un torneo y se arregla en un toque. |

### B · Perfil

Nada es obligatorio: la ficha funciona vacía y se va llenando. Cada campo suma
identidad, y dos de ellos además sirven para algo más adelante.

| | Campo | Por qué está |
|---|---|---|
| B1 | **Foto** | Es lo primero que hace que la ficha se sienta tuya. Con avatar de iniciales si no hay. |
| B2 | Nombre, apellido y **apodo** | En el club te llaman por el apodo, no por el DNI. |
| B3 | **Lado: drive / revés / indistinto** | Vocabulario que ya existe en el marcador (`PlayerPosition`). Alimenta "compañero ideal" en la 4b. |
| B4 | **Mano: diestro / zurdo** | Igual: barato ahora, útil después para emparejar. |
| B5 | **Pala** | Texto libre. Los jugadores hablan de su pala constantemente; es el campo que más se rellena solo. |
| B6 | Club o clubes | Determina en qué ranking sales. |
| B7 | Jugando desde | Una fecha. Da contexto al nivel. |
| B8 | **Visibilidad**: público / sólo mi club / oculto | No es un extra: es el requisito de datos personales. |

B1-B5 son cosmética útil, no motor del producto. Se meten porque cuestan poco y
porque una ficha vacía no se comparte.

### C · Nivel y categoría

| | Función | Nota |
|---|---|---|
| C1 | Nivel Elo con su movimiento (`↑ +8`) | El movimiento engancha más que el número. |
| C2 | Categoría derivada, con histéresis | Es como se habla el nivel en pádel. |
| C3 | **Barra hacia la siguiente categoría** | El motor de enganche del MVP. |
| C4 | Estado provisional hasta 10 partidos | Un nivel injusto enfada más de lo que uno justo fideliza. |
| C5 | De dónde salió cada cambio | Tocar el nivel y ver los partidos que lo movieron. Es lo que evita la sensación de caja negra. |

### D · Historial

| | Función | Nota |
|---|---|---|
| D1 | Historial **agrupado por evento**, no por partido | «3º en el Americano del sábado» es lo que la gente recuerda y cuenta. |
| D2 | Ficha de evento | Formato, puesto en la clasificación, partidos jugados, `Δ` de nivel del día. |
| D3 | Ficha de partido, dentro del evento | Los cuatro jugadores, resultado **en su unidad**, pista, hora y `Δ`. |
| D4 | Etiqueta de origen y de formato visibles | Torneo / amistoso / marcador, y americano / mexicano / parejas fijas. |
| D5 | **Cargar un amistoso** | Cuatro nombres y un resultado. Objetivo: veinte segundos. |
| D6 | Aviso a los otros tres, con corregir o quitarme | Sin confirmación obligatoria: no puntúa, no hace falta. |
| D7 | Sugerir compañeros frecuentes al cargar | Es lo que convierte veinte segundos en diez. |

### E · Números y gente

| | Función | Nota |
|---|---|---|
| E1 | Totales: partidos, victorias, %, racha, juegos | Separando verificado de amistoso. |
| E2 | Compañeros: con quién, cuántas veces, % | El americano los regala. |
| E3 | Rivales y cara a cara | "Le ganaste 7 de 11" es lo que se manda por WhatsApp. |
| E4 | Mejor compañero y némesis | Dos tarjetas, no una pantalla. |
| E5 | Ranking del club | El único con significado hasta tener varios clubes. |

### F · Logros

Ocho, no cuarenta, y **todos sobre jugar**, nunca sobre abrir la app. Existen
sobre todo porque son la única recompensa del amistoso, que no da nivel:

100 partidos · 1000 juegos · 10 compañeros distintos · racha de 5 · un mes con 10
partidos · ganar a alguien de una categoría superior · tres meses seguidos
jugando · subir de categoría.

### G · Página pública del jugador

| | Función | Nota |
|---|---|---|
| G1 | `/j/ignacio` servida desde `web/` | Nombre, foto, categoría, totales, ranking del club. |
| G2 | Vista previa al pegar el enlace en WhatsApp | El motivo por el que es web y no app. |
| G3 | "Abrir en Puntazo" | El enlace es el canal de adquisición. |
| G4 | Respeta la visibilidad del perfil | Por defecto, nombre y apellido inicial. |

### Qué hay construido ya

Todo lo que no es pantalla se puede escribir y probar antes de que exista la app,
y así se ha hecho. Cuatro módulos puros, con tests, sin base de datos y sin React
—el mismo patrón que el generador de rondas—:

| Módulo | Cubre |
|---|---|
| [`lib/identidad/`](../../web/src/lib/identidad/) | A2 y A3: proponer quién es quién |
| [`lib/rating/`](../../web/src/lib/rating/) | C1-C4 y A5: **Puntazo Rating**, divisiones con histéresis, progreso, auditoría y banco de pruebas |
| [`lib/historial/partidos.ts`](../../web/src/lib/historial/partidos.ts) | D1-D3 y E1: historial por evento, por mes, récord y rachas |
| [`lib/historial/gente.ts`](../../web/src/lib/historial/gente.ts) | E2-E4: compañeros, rivales, cara a cara y destacados |
| [`lib/jugador/desde-el-panel.ts`](../../web/src/lib/jugador/desde-el-panel.ts) | El puente: de las filas del panel a todo lo anterior, y la prueba de que encajan |
| [`lib/jugador/ranking.ts`](../../web/src/lib/jugador/ranking.ts) | E5: el ranking, y si tiene derecho a llamarse ranking |

### Lo que la base de datos guarda y la app no puede usar

El esquema del panel tiene tres cosas que un historial no admite, y ninguna es un
defecto suyo: **partidos sin resultado** (`juegos_a` nulo hasta que alguien lo
mete), **huecos y byes del cuadro** (desde los torneos de parejas, los cuatro
jugadores pueden ser nulos) e **inscritos sin unificar** (mientras nadie diga
quién es "Nacho R.", ese nombre no es una persona).

La regla del puente: **nada se descarta en silencio.** Cada fila que no pasa sale
con su motivo, porque tirar filas calladamente es exactamente como se esconde un
fallo de datos — el ranking sale raro y nadie sabe por qué. Con el motivo delante,
el panel puede decir *"faltan 12 partidos porque hay ocho personas sin
identificar"*, que además es una tarea y no un error.

Dos reglas de producto quedaron dentro del código, y conviene recordarlas aquí
porque no son decisiones técnicas:

- **La racha y el porcentaje oficial salen sólo de partidos verificados**; los
  amistosos suman en actividad, compañeros, rivales y cara a cara. La frase de la
  interfaz vale también como especificación.
- **Nadie es tu mejor compañero por haber jugado una vez.** Hace falta un mínimo
  de partidos, y el porcentaje tira suavemente hacia tu propia media, así que
  ganar cuatro de cuatro no da un 100 %: da algo alto y prudente que alguien con
  veinte partidos puede superar. Es la misma idea que "provisional" en el nivel.

### Orden de construcción dentro del MVP

**A → D1-D4 → C → B → E → G → D5-D7 → F.** La identidad primero porque no hay
nada sin ella; los amistosos casi al final porque son la única parte que no
depende de que exista el resto, y la primera que se recorta si el MVP se alarga.

### Fuera del MVP, a propósito

| Función | Cuándo | Por qué |
|---|---|---|
| Buscar partido, "nos falta uno" | 4e | Necesita masa crítica **de ciudad**, no de club. Fallar aquí quema la función para siempre. |
| Inscripción a torneos | 4d | Depende de que el panel acepte inscripción online (fase 3 del panel). |
| Reservar pista | 4e | Depende de la agenda (fase 2 del panel). |
| Amigos, resumen anual, tarjetas para compartir | 4b | Necesitan historial acumulado para no salir vacíos. |
| Estadísticas de punto a punto | 4c | Necesitan el QR firmado del marcador. |
| Ranking entre clubes como número duro | 4b | Hasta que haya partidos cruzados es una estimación, y se etiqueta como tal. |
| Chat, mensajería | — | El grupo de WhatsApp del club ya existe y funciona mejor. |
| Pagos del jugador | — | El jugador no paga. Paga el club. |

**Regla para dudas nuevas**: si una función necesita que la app tenga usuarios en
**varios** clubes para ser útil, no es del MVP.

---

## Fases

| Fase | Qué | Desbloquea |
|---|---|---|
| **4a** | Identidad, perfil, historial, nivel y categoría, amistosos, ranking de club, página pública | que exista |
| **4b** | Amigos, cara a cara destacado, resumen mensual, tarjetas para compartir, ranking entre clubes | que se comparta |
| **4c** | **QR del marcador** → partido verificado con traza de puntos; el amistoso en pista Puntazo empieza a puntuar | todas las estadísticas finas, de golpe |
| **4d** | Inscripción a torneos desde la app | cierra el círculo con el panel |
| **4e** | "Falta uno", agenda y reservas | requiere varios clubes |

La 4c es el salto de producto. Todo lo anterior lo puede copiar cualquiera con
una base de datos; **el partido verificado por el hardware, no.**

Nota sobre la 4d: el plan de producto aparta la inscripción online porque «exige
que 24 personas usen algo». Con la app del jugador ya instalada ese problema
desaparece — es exactamente el desbloqueo que justifica el orden.

---

## Decisiones

| Decisión | Elegido | Razón corta |
|---|---|---|
| App o web | **App nativa**, con página pública en web | Hace falta push, cámara para el QR y sesión persistente. La web pública es el canal de reparto, no el producto. |
| Con qué | **Flutter** | Ya hay toolchain, firma y Play Console andando (`app/` está publicada). El plan de producto descarta **Flutter Web** para páginas públicas; eso no dice nada contra Flutter en móvil. |
| Página pública del jugador | **Next.js, dentro de `web/`** | Mismo motivo ya cerrado: WhatsApp no ejecuta JavaScript al generar la vista previa. |
| Backend | **Supabase, la misma base** | La app del jugador lee lo que escribe el panel. Dos bases serían una sincronización. |
| Sistema de nivel | **Elo con margen de juegos y K variable** | Mide cómo juegas, no cuánto. Funciona con pocos partidos y es explicable. |
| Peso del partido | **`P` proporcional a lo jugado** | Sin él, una mañana de americano (8 ajustes) pesa más que un cuadro entero (3). |
| Categorías y formatos | **Tablas de configuración por región** | El número de categorías, sus nombres y hasta el significado de «pozo» cambian por país. |
| Unidad del resultado | **La declara el torneo** | `15-9` a 24 puntos y `6-4` a juegos son hoy la misma fila y no significan lo mismo. |
| Unidad del historial | **El evento, no el partido** | En un americano lo que cuenta es el puesto del día, no la suma de partidos. |
| Semilla del Elo | **La categoría declarada** | Resuelve el arranque en frío y es el ancla que hace comparables dos clubes. |
| Qué puntúa | **Sólo partidos verificados** | Un ranking corrompido no se arregla. |
| Amistosos | **Se registran, no puntúan** | Sin incentivo para mentir, el flujo puede ser de un solo toque. |
| Cálculo del nivel | **Módulo puro con tests, en el servidor, recalculable** | La fórmula va a cambiar; el Elo tiene que poder rehacerse desde cero. |
| Ranking inicial | **Del club** | Es el único con significado hasta tener varios clubes. |

### Sin decidir

- **Cómo se autentica.** El teléfono es el identificador natural (el club ya lo
  recoge), pero el SMS cuesta dinero por mensaje. Alternativas: enlace mágico por
  correo, o entrar directamente desde el enlace del torneo.
- **Categorías femeninas y partidos mixtos.** Las categorías van separadas por
  género en casi todas partes; el Elo no tiene por qué. Hay que decidir si son dos
  escalas o una escala con dos tablas de categorías, y qué pasa en los mixtos.
- **Ancho real de las bandas** (150 es una hipótesis) y cuántos partidos antes de
  dar el nivel por definitivo.
- **La referencia de `P`**: a cuánto equivale un partido «entero» y cómo se
  normalizan puntos, juegos y sets a una misma escala. La simulación dice que la
  escala se conserva con las constantes de hoy, pero eso sólo prueba la
  maquinaria: **si dos categorías reales no se separan por 150 puntos, las bandas
  están mal** y eso no se sabe hasta ver torneos de verdad.
- **Cuánto menos pesa una pareja fija.** Ya no se puede aparcar: el panel va a
  tener los dos formatos. Hay que elegir un número de partida y recalcular cuando
  haya datos.
- Si la app del jugador vive en este mismo repositorio (el argumento de los
  contratos compartidos aplica a partir de la 4c).

---

## Cómo saber si funciona

Dos métricas, y ninguna es "descargas":

1. **% de jugadores de un torneo que reclaman su ficha en 72 h.** Objetivo: más
   del 40 %. Mide si el gancho engancha.
2. **% de jugadores con ficha que abren la app en una semana en la que no han
   jugado torneo.** Mide si hay producto más allá del recuerdo del sábado. Si
   sale bajo, no construir la fase 4b: arreglar el inicio.

Y una tercera, sólo para decidir el futuro de los amistosos: **% de fichas que
cargan al menos un amistoso el primer mes**. Si baja del 15 %, la función se
queda como está y no se le dedica ni una hora más.

---

## Riesgos

- **Nacer vacía.** Es el riesgo número uno y se evita con una sola decisión:
  acumular identidad desde la fase 1. Una app que el primer día enseña 30
  partidos tuyos es otro producto que una que enseña un formulario.
- **Un nivel injusto enfada más de lo que un nivel justo fideliza.** En pádel el
  nivel es identidad social. Mitigación: provisional mientras haya poca base,
  histéresis en la categoría, ganar nunca baja el nivel, y poder ver qué partidos
  movieron la cifra.
- **Que nadie declare su categoría.** Si el campo de A4 se puede saltar, medio
  club arranca en el número por defecto y el nivel deja de significar nada — es el
  escenario "sin semilla" de la tabla de arriba. Si el jugador no la sabe, la pone
  el club.
- **El ranking entre clubes puede ser mentira** si los clubes no se cruzan. Se
  etiqueta como estimado hasta que haya partidos cruzados.
- **Comparar formatos sin normalizar.** Si un club hace americanos y otro cuadros
  de parejas fijas, y el resultado se guarda en dos unidades distintas bajo el
  mismo par de enteros, el ranking conjunto compara cosas que no son iguales. Es
  el mismo fallo que el anterior, pero por dentro del cálculo en vez de por el
  reparto de los partidos.
- **Datos personales de terceros.** Publicar el nombre de alguien que no ha pedido
  estar ahí ya pasa hoy con la página pública del torneo, y la app lo amplifica.
  Hace falta, desde el principio: nombre y apellido inicial por defecto, poder
  ocultarse, y una regla explícita para menores (los clubes tienen escuela). La
  foto sube la apuesta: es un dato personal más y necesita su propia visibilidad.
- **Los amistosos no se cargan.** Es lo más probable que pase, y por eso son lo
  último que se construye y lo primero que se recorta.
- **Adelantarla.** Sigue siendo fase 4: sin clubes usando el panel a diario no
  hay a quién enganchar. Lo que se adelanta es **la identidad**, que son dos
  tablas, no la app.

---

## Por qué merece la pena

La app del jugador no se vende: el jugador no paga. Vende hardware.

Cuando un jugador tiene su historial en Puntazo, la pregunta que le hace a su
club es **"¿esta pista tiene Puntazo? quiero que me quede el partido"**. Ése es
el único mecanismo de este plan que empuja la venta B2B desde abajo, y es la
razón de construirla.

> Llegas → te identificas → juegas → queda registrado → tu nivel se mueve →
> compites con los tuyos → entras a un torneo → encuentras el próximo partido.
