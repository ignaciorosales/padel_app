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
