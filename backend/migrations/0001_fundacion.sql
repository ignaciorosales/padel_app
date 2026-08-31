-- =============================================================================
-- Puntazo · 0001 · Fundación: clubes, usuarios, permisos y estado de pago
-- =============================================================================
-- Ejecutar en el editor SQL de Supabase (o con `supabase db push`).
--
-- Idea central: TODO cuelga de un club, y el club tiene un estado de suscripción.
-- El corte por impago no se hace en la interfaz — se hace aquí, en las políticas
-- RLS. Aunque alguien llame a la API directamente, sin pasar por la web, un club
-- suspendido no puede escribir.
-- =============================================================================

-- ---------------------------------------------------------------- tipos
create type public.subscription_status as enum (
  'trial',      -- periodo de prueba: escribe con normalidad
  'active',     -- al día: escribe con normalidad
  'past_due',   -- se retrasó el pago: escribe, pero la web avisa
  'suspended'   -- cortado: sólo lectura
);

create type public.club_role as enum ('owner', 'staff');

-- ---------------------------------------------------------------- perfiles
-- Extiende auth.users. Se crea solo con un trigger al dar de alta el usuario.
create table public.profiles (
  id                uuid primary key references auth.users (id) on delete cascade,
  email             text,
  full_name         text,
  is_platform_admin boolean not null default false,
  created_at        timestamptz not null default now()
);

comment on column public.profiles.is_platform_admin is
  'Administrador de la plataforma (tú). Se activa a mano por SQL, nunca desde la web.';

-- ---------------------------------------------------------------- clubes
create table public.clubs (
  id            uuid primary key default gen_random_uuid(),
  slug          text not null unique
                check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug) between 2 and 40),
  name          text not null check (length(trim(name)) > 0),
  status        public.subscription_status not null default 'trial',
  trial_ends_at date,
  contact_name  text,
  contact_phone text,
  notes         text,
  created_at    timestamptz not null default now()
);

create index clubs_status_idx on public.clubs (status);

-- ---------------------------------------------------------------- miembros
create table public.club_members (
  club_id    uuid not null references public.clubs (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  role       public.club_role not null default 'staff',
  created_at timestamptz not null default now(),
  primary key (club_id, user_id)
);

create index club_members_user_idx on public.club_members (user_id);

-- =============================================================================
-- Funciones de permisos
-- =============================================================================
-- SECURITY DEFINER a propósito: se consultan desde las políticas RLS de las
-- propias tablas que leen, y sin esto habría recursión infinita.

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.is_platform_admin from public.profiles p where p.id = auth.uid()),
    false
  );
$$;

create or replace function public.is_club_member(p_club uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.club_members m
    where m.club_id = p_club and m.user_id = auth.uid()
  );
$$;

-- ¿Puede este usuario LEER los datos de este club?
create or replace function public.can_read_club(p_club uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_admin() or public.is_club_member(p_club);
$$;

-- ¿Puede este usuario ESCRIBIR en este club?
-- Aquí es donde muerde el impago: 'suspended' deja de escribir.
create or replace function public.can_write_club(p_club uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_platform_admin()
    or (
      public.is_club_member(p_club)
      and (select c.status from public.clubs c where c.id = p_club)
          in ('trial', 'active', 'past_due')
    );
$$;

comment on function public.can_write_club(uuid) is
  'Puerta única del corte por impago. Todas las tablas de datos de club deben usar
   esta función en sus políticas de INSERT/UPDATE/DELETE.';

-- =============================================================================
-- Altas automáticas y protecciones
-- =============================================================================

-- Cada usuario de auth.users tiene su fila en profiles.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, nullif(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Si el usuario cambia de correo, que el perfil no se quede desfasado.
create or replace function public.sync_profile_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles set email = new.email where id = new.id;
  return new;
end;
$$;

create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row execute function public.sync_profile_email();

-- Nadie se asciende a sí mismo a administrador de plataforma.
create or replace function public.protect_platform_admin_flag()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_platform_admin is distinct from old.is_platform_admin then
    -- Sin usuario final detrás: editor SQL de Supabase, psql, migraciones o
    -- clave de servicio. Se permite, y es lo que deja nombrar al primer
    -- administrador. No abre ningún agujero: una petición anónima por la API
    -- no llega hasta aquí, la corta antes la política RLS de profiles, que
    -- exige id = auth.uid().
    if auth.uid() is null then
      return new;
    end if;

    if not public.is_platform_admin() then
      raise exception 'Sólo un administrador de plataforma puede cambiar is_platform_admin';
    end if;
  end if;
  return new;
end;
$$;

create trigger profiles_protect_admin_flag
  before update on public.profiles
  for each row execute function public.protect_platform_admin_flag();

-- =============================================================================
-- RLS
-- =============================================================================

alter table public.profiles     enable row level security;
alter table public.clubs        enable row level security;
alter table public.club_members enable row level security;

-- ---- profiles ----
create policy "perfil propio, companeros de club o admin de plataforma"
  on public.profiles for select
  using (
    id = auth.uid()
    or public.is_platform_admin()
    or exists (
      select 1
      from public.club_members mine
      join public.club_members theirs on theirs.club_id = mine.club_id
      where mine.user_id = auth.uid() and theirs.user_id = profiles.id
    )
  );

create policy "editar el perfil propio"
  on public.profiles for update
  using (id = auth.uid() or public.is_platform_admin())
  with check (id = auth.uid() or public.is_platform_admin());

-- ---- clubs ----
create policy "ver los clubes propios"
  on public.clubs for select
  using (public.can_read_club(id));

-- Crear, editar y borrar clubes es cosa de la plataforma, no del club.
-- El club no puede cambiarse a sí mismo el estado de suscripción.
create policy "la plataforma administra los clubes"
  on public.clubs for all
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- ---- club_members ----
create policy "ver los miembros del club propio"
  on public.club_members for select
  using (public.can_read_club(club_id));

create policy "la plataforma administra los miembros"
  on public.club_members for all
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- =============================================================================
-- Cómo nombrarte administrador de plataforma (una sola vez, a mano)
-- =============================================================================
-- 1. Crea tu usuario desde Authentication > Users en el panel de Supabase.
-- 2. Ejecuta aquí, con tu correo:
--
--      update public.profiles set is_platform_admin = true
--      where id = (select id from auth.users where email = 'tu@correo.com');
--
-- A partir de ahí puedes crear clubes y usuarios desde /admin en la web.
-- =============================================================================
