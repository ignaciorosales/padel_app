-- =============================================================================
-- Puntazo · 0004 · Página pública
-- =============================================================================
-- La 0003 ya dejó preparado casi todo: inscritos, rondas y partidos de un
-- torneo con `publico = true` los puede leer cualquiera sin sesión, porque sus
-- políticas pasan por torneo_es_publico(). La tabla `tournaments` también.
--
-- Falta una sola pieza: **clubs**. Su política de lectura es
-- `using (can_read_club(id))`, así que un visitante anónimo no puede leer la
-- fila del club — y sin ella no se puede resolver /t/<club>/<torneo>, porque
-- el slug del torneo sólo es único DENTRO de un club, ni enseñar su nombre.
--
-- No se toca esa política. Abrir `clubs` a los anónimos expondría la fila
-- entera: teléfono de contacto, notas internas y el estado de suscripción.
-- En su lugar, una función security definer que devuelve sólo los tres campos
-- que la página pública necesita, y sólo de clubes que han publicado algo.
-- =============================================================================

create or replace function public.club_publico(p_slug text)
returns table (id uuid, slug text, nombre text)
language sql
stable
security definer
set search_path = public
as $$
  select c.id, c.slug, c.name
  from public.clubs c
  where c.slug = p_slug
    and exists (
      select 1
      from public.tournaments t
      where t.club_id = c.id
        and t.publico
    );
$$;

comment on function public.club_publico(text) is
  'Resuelve un club por slug para la página pública. Devuelve sólo id, slug y '
  'nombre, y sólo si el club tiene al menos un torneo publicado. No expone '
  'contacto, notas ni estado de suscripción.';
