# Puntazo Club — panel web

Panel de gestión para clubes de pádel. Next.js 16 (App Router) + Supabase.
El plan de producto y el alcance están en [`../docs/producto/README.md`](../docs/producto/README.md).

Estado: **fundación lista** — autenticación, clubes, usuarios y corte por impago.
Los torneos son el siguiente paso.

## Puesta en marcha

### 1. Proyecto de Supabase

Crea un proyecto en [supabase.com](https://supabase.com) (el plan gratuito sobra).

### 2. Esquema

Abre el editor SQL del proyecto y ejecuta enteros, **en orden de número**,
todos los ficheros de [`../backend/migrations/`](../backend/migrations/):
empezando por `0001_fundacion.sql` y terminando por el último que haya.

Sobre una base de datos que ya existe sólo hacen falta las que aún no se hayan
ejecutado. Cada fichero se puede ejecutar entero de una vez.

### 3. Variables de entorno

```bash
cp .env.example .env.local
```

Rellena los tres valores desde *Project Settings ▸ API*:

| Variable | Dónde está | Ojo |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Project URL | pública |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | anon / public | pública |
| `SUPABASE_SERVICE_ROLE_KEY` | service_role | **secreta**, se salta RLS |

### 4. Tu usuario de administrador

En *Authentication ▸ Users ▸ Add user*, créate un usuario con correo y
contraseña (marca «Auto Confirm User»). Después, en el editor SQL:

```sql
update public.profiles set is_platform_admin = true
where id = (select id from auth.users where email = 'tu@correo.com');
```

Es el único paso que se hace a mano, y a propósito: nadie puede ascenderse a sí
mismo desde la web.

### 5. Arrancar

```bash
npm install
npm run dev
```

En <http://localhost:3000> entras con tu usuario y caes en `/admin`.

## Cómo funciona el control de acceso

Tres niveles, y el que manda es el de más abajo:

1. **`src/proxy.ts`** — refresca la sesión y redirige rápido. Sólo optimista.
2. **`src/lib/auth.ts`** — `requireViewer`, `requirePlatformAdmin`,
   `requireClubAccess`. Toda página privada y toda acción de servidor empieza por
   uno de estos.
3. **Políticas RLS en Postgres** — la autorización de verdad. Aunque alguien
   llame a la API directamente, saltándose la web, las políticas deciden.

### El corte por impago

Vive en la función `can_write_club()` de la base de datos, no en la interfaz:

| Estado | Lee | Escribe |
|---|---|---|
| `trial` | sí | sí |
| `active` | sí | sí |
| `past_due` | sí | sí, con aviso en el panel |
| `suspended` | sí | **no** |

Suspender un club es cambiar un desplegable en `/admin`. El efecto es inmediato y
no borra nada: sus datos siguen ahí y vuelven al reactivarlo.

Se deja leer a propósito. Cortar también la lectura castigaría a los jugadores de
un torneo en marcha, no al club — y la palanca que importa es que no puedan
montar el torneo siguiente. Cambiarlo es editar una función SQL.

## Estructura

```
src/
├── app/
│   ├── login/            entrada con correo y contraseña
│   ├── admin/            TÚ: alta de clubes, usuarios y suscripción
│   │   └── [slug]/       ficha de un club
│   └── panel/            EL CLUB: su día a día
│       └── [club]/
├── components/           ui.tsx (piezas), shell.tsx (marco)
└── lib/
    ├── auth.ts           capa de autorización
    ├── types.ts          tipos y etiquetas de estado
    └── supabase/         cliente de servidor, de navegador y de servicio
```

## Comandos

```bash
npm run dev     # desarrollo
npm run build   # compilar
npm run lint    # eslint
npm test        # tests (runner de Node, sin dependencias)
npx tsc --noEmit
```

## El generador de americanos

`src/lib/torneo/americano.ts` es TypeScript puro: ni base de datos, ni React, ni
fechas. Entra una lista de jugadores y salen las rondas, así que se puede probar
a fondo sin levantar nada.

Repartir N jugadores en parejas distintas ronda tras ronda es el problema del
*social golfer* y no tiene solución exacta rápida. Se construye cada ronda con
una heurística voraz, se repite con 200 semillas y se guarda la mejor. Con la
misma semilla sale siempre el mismo cuadro, así que el organizador puede
regenerar sin sorpresas.

Resultados medidos (`npm test` cubre estos casos):

| Jugadores | Pistas | Rondas | Compañeros repetidos | Partidos por jugador |
|---|---|---|---|---|
| 8 | 2 | 7 | 0 | 7 |
| 16 | 4 | 7 | 0 | 7 |
| 20 | 5 | 8 | 0 | 8 |
| 24 | 6 | 8 | 0 | 8 |
| 28 | 5 | 9 | 0 | 6–7 |
| 32 | 8 | 10 | 0 | 10 |

Cero compañeros repetidos en todas, con los partidos repartidos y por debajo de
15 ms. Los rivales sí se repiten, que es inevitable y molesta mucho menos.

## Diseño

Los tokens de color y la escala tipográfica salen del plan de producto y viven en
`src/app/globals.css`: paleta fría con acento teal, colores semánticos aparte del
acento para los estados, Archivo para interfaz e IBM Plex Mono para datos.
Funciona en claro y en oscuro según la preferencia del sistema.

## La agenda del club

`src/lib/agenda/ocupacion.ts` y la migración
[`0012`](../backend/migrations/0012_ocupacion_de_pista.sql).

El objeto central del modelo no es el torneo: es la **ocupación de pista**
(pista + rango horario + motivo). Un torneo genera ocupaciones, una clase
también, y una reserva *es* una. Está puesto ahora, con la fase 1 a medio
terminar y ningún club en producción, porque es lo que decide si la agenda de la
fase 2 es una pantalla nueva o una reescritura.

Tres tablas:

| Tabla | Qué es |
|---|---|
| `courts` | Las pistas de verdad del club, las que tienen nombre en la puerta. |
| `tournament_courts` | Qué pista real es «la pista 1» de este torneo. |
| `court_occupancies` | Pista, rango horario y motivo. El calendario. |

Dos cosas no pueden ocupar la misma pista a la vez, y eso no lo vigila la
interfaz: es una restricción de exclusión (`exclude using gist`) en Postgres. El
día que alguien reserve por teléfono la pista donde hay un torneo, la base de
datos dice que no aunque la pantalla se haya despistado.

**El torneo no depende de su agenda.** El panel escribe las ocupaciones después
de generar las rondas, y si chocan con algo, el torneo funciona igual. Es
deliberado: un sábado por la mañana, con 24 personas esperando, el calendario no
puede ser lo que impida generar unas rondas.

Lo que sí hace es contarlo. `sincronizarAgenda` devuelve cuántas ocupaciones no
cupieron, y corregir la hora de una ronda lo enseña donde se corrige: «1 partido
no cabe en la agenda del club: algo ya ocupa esa pista a esa hora». La primera
versión se lo tragaba en silencio, y montando un torneo de verdad se vio lo que
costaba: retrasar la ronda 1 media hora la ponía encima de la 2 y de la 3, seis
ocupaciones desaparecían sin decir nada y el horario resultante no se podía
jugar. De ahí que **cambiar la hora de una ronda arrastre las siguientes**
(`src/lib/torneo/horario.ts`), que además es lo que quiere decir el encargado
cuando toca una hora a media mañana.

Los demás caminos —generar rondas, generar grupos, mover un partido de pista—
siguen sin enseñar ese número. Cuando exista la pantalla de agenda de la fase 2,
es su sitio natural.

Las pistas del club se crean solas la primera vez que monta un torneo
(«Pista 1», «Pista 2»…) y se renombran cuando quiera. Un formulario de alta de
pistas entre el club y sus rondas se come el objetivo de los cinco minutos.

## El dinero, que en la fase 1 es casi nada

`src/lib/torneo/cobros.ts` y la migración
[`0013`](../backend/migrations/0013_importe_de_la_inscripcion.sql).

El plan lo deja escrito: cobros fuera, pero con sitio. No hay caja, ni bonos, ni
recibos, ni pasarela. Hay dos columnas en `tournament_players` —`importe` y
`pagado`— y una frase en el panel: «120,00 € cobrados · 36,00 € de 3 personas
sin cobrar». El club cobra como cobra hoy y aquí sólo apunta si ya cobró.

El precio se pone de una vez para todos y se corrige por persona. Escribirlo
veinticuatro veces se come el objetivo de los cinco minutos.

**Lo que esas dos columnas obligaron a arreglar.** `tournament_players` la puede
leer cualquiera sin sesión cuando el torneo es público — es lo que hace
funcionar el enlace de WhatsApp. Con dinero dentro, esa puerta deja de ser
inofensiva: con la clave anónima, que viaja en el navegador, se podía preguntar
a la API cuánto debe cada socio.

Y al mirarlo se vio que la puerta ya estaba dejando pasar algo: la página
pública hacía `select *`, así que el **teléfono** de los 24 inscritos salía en
la respuesta desde la 0003. Nadie lo pintaba y daba igual.

El cierre son dos cosas, y hacen falta las dos:

| | Qué hace |
|---|---|
| Permisos de columna | `anon` sólo puede leer `id`, `tournament_id`, `nombre` y `orden`. |
| Política por rol | La lectura de torneos públicos se acota a `anon`; con sesión, sólo tu club. |

Cuidado al tocarlo: **un permiso de columna no resta de uno de tabla**. Hay que
quitar el `select` de la tabla y conceder las columnas, no revocar las que
sobran — si no, queda una migración que parece cerrar la puerta y la deja
abierta.

De rebote, `select *` con la clave anónima ahora falla en vez de devolver de
más, así que un `select *` que se cuele en el futuro se cae en desarrollo en
lugar de filtrar en producción.
