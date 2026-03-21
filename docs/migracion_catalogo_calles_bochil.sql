-- Migracion: catalogo de calles de Bochil + relaciones para invitaciones/perfiles/alertas
-- Objetivo:
-- 1) Crear catalogo maestro de calles
-- 2) Relacionar invitaciones_qr y perfiles_usuarios por calle_id
-- 3) Crear relacion N:M entre alertas_oficiales y calles
-- 4) Insertar calles principales de Bochil
-- 5) Backfill basico desde campos de texto existentes

begin;

-- ---------------------------------------------------------------------------
-- Funciones de normalizacion (evita problemas por mayusculas/espacios)
-- ---------------------------------------------------------------------------
create extension if not exists unaccent;

create or replace function public.normalizar_calle(input text)
returns text
language sql
immutable
as $$
  select regexp_replace(lower(unaccent(coalesce(input, ''))), '\\s+', ' ', 'g')
$$;

-- ---------------------------------------------------------------------------
-- Catalogo maestro de calles
-- ---------------------------------------------------------------------------
create table if not exists public.catalogo_calles (
  id uuid primary key default gen_random_uuid(),
  nombre_oficial varchar(180) not null,
  nombre_normalizado varchar(180) not null,
  activa boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (nombre_normalizado)
);

create index if not exists idx_catalogo_calles_activa
  on public.catalogo_calles (activa);

create or replace function public.trg_catalogo_calles_set_normalizado()
returns trigger
language plpgsql
as $$
begin
  new.nombre_oficial := trim(new.nombre_oficial);
  new.nombre_normalizado := public.normalizar_calle(new.nombre_oficial);
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_catalogo_calles_set_normalizado on public.catalogo_calles;

create trigger trg_catalogo_calles_set_normalizado
before insert or update on public.catalogo_calles
for each row
execute function public.trg_catalogo_calles_set_normalizado();

-- ---------------------------------------------------------------------------
-- Relacion con invitaciones y perfiles
-- ---------------------------------------------------------------------------
alter table public.invitaciones_qr
  add column if not exists calle_id uuid references public.catalogo_calles(id);

alter table public.perfiles_usuarios
  add column if not exists calle_id uuid references public.catalogo_calles(id);

create index if not exists idx_invitaciones_qr_calle_id
  on public.invitaciones_qr (calle_id);

create index if not exists idx_perfiles_usuarios_calle_id
  on public.perfiles_usuarios (calle_id);

-- ---------------------------------------------------------------------------
-- Relacion N:M entre alertas y calles (modelo robusto)
-- ---------------------------------------------------------------------------
create table if not exists public.alertas_calles (
  alerta_id uuid not null references public.alertas_oficiales(id) on delete cascade,
  calle_id uuid not null references public.catalogo_calles(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (alerta_id, calle_id)
);

create index if not exists idx_alertas_calles_calle_id
  on public.alertas_calles (calle_id);

-- ---------------------------------------------------------------------------
-- RLS basica para catalogo y alertas_calles
-- Ajusta politicas segun tus roles admin/coordinador en produccion.
-- ---------------------------------------------------------------------------
alter table public.catalogo_calles enable row level security;
alter table public.alertas_calles enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'catalogo_calles'
      and policyname = 'Ver catalogo calles activas'
  ) then
    create policy "Ver catalogo calles activas"
      on public.catalogo_calles
      for select
      using (activa = true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'alertas_calles'
      and policyname = 'Ver relacion alertas calles'
  ) then
    create policy "Ver relacion alertas calles"
      on public.alertas_calles
      for select
      using (true);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Insert inicial de calles principales de Bochil
-- ---------------------------------------------------------------------------
insert into public.catalogo_calles (nombre_oficial)
values
  ('1era. Avenida Sur Poniente'),
  ('9na. Poniente Norte'),
  ('Avenida 1era. Norte Oriente'),
  ('Avenida 1era. Norte Poniente'),
  ('Avenida 1era. Sur Oriente'),
  ('Avenida 2da. Norte Oriente'),
  ('Avenida 2da. Norte Poniente'),
  ('Avenida 2da. Sur Oriente'),
  ('Avenida 3era. Sur Oriente'),
  ('Avenida 3era. Sur Poniente'),
  ('Avenida Central Oriente'),
  ('Avenida Central Poniente'),
  ('Avenida Segunda Norte Oriente'),
  ('Avenida Segunda Norte Poniente'),
  ('Avenida Segunda Sur Poniente'),
  ('Calle 10 de Mayo'),
  ('Calle 1era. Oriente Sur'),
  ('Calle 1era. Poniente Norte'),
  ('Calle 1era. Poniente Sur'),
  ('Calle 24 de Julio'),
  ('Calle 26 de Julio'),
  ('Calle 2da. Oriente Norte'),
  ('Calle 2da. Oriente Sur'),
  ('Calle 2da. Poniente Norte'),
  ('Calle 2da. Poniente Sur'),
  ('Calle 30 de Abril'),
  ('Calle 3era. Oriente Norte'),
  ('Calle 3era. Oriente Sur'),
  ('Calle 3era. Poniente Norte'),
  ('Calle 3era. Poniente Sur'),
  ('Calle 4ta. Oriente Norte'),
  ('Calle 4ta. Oriente Sur'),
  ('Calle 4ta. Poniente Norte'),
  ('Calle 4ta. Poniente Sur'),
  ('Calle 5 de Febrero'),
  ('Calle 5ta. Oriente Norte'),
  ('Calle 5ta. Poniente Norte'),
  ('Calle 5ta. Poniente Sur'),
  ('Calle 6ta. Oriente Norte'),
  ('Calle 6ta. Poniente Sur'),
  ('Calle 7 de Julio'),
  ('Calle 7ma. Poniente Norte'),
  ('Calle 7ma. Poniente Sur'),
  ('Calle 8va. Poniente Sur'),
  ('Calle 9na. Poniente Sur'),
  ('Calle Agustín Rubio'),
  ('Calle Agustín Rubio Montoya'),
  ('Calle Camino'),
  ('Calle Central Norte'),
  ('Calle Central Sur'),
  ('Calle Décima Poniente'),
  ('Calle Décima Poniente Sur'),
  ('Calle Emiliano Zapata'),
  ('Calle José Vasconcelos'),
  ('Calle Juan Sabines'),
  ('Calle Juvencio Robles'),
  ('Calle La Corregidora'),
  ('Calle Los Ángeles'),
  ('Calle Los Sabines'),
  ('Calle Manuel Palafox'),
  ('Calle Miguel Hidalgo'),
  ('Calle Otilio Montaño'),
  ('Calle Quinta Oriente Norte'),
  ('Calle San Sebastián'),
  ('Calle Tercera Poniente Sur'),
  ('Calle Victoriano Huerta'),
  ('Callejón Central'),
  ('Callejón Nueva Libertad'),
  ('Callejón Plan de Ayala'),
  ('Callejón Poniente'),
  ('Callejón Sur Poniente'),
  ('Carretera Villahermosa - Escopetazo'),
  ('Privada Agustín Rubio')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Backfill basico desde texto existente (si ya habia datos)
-- ---------------------------------------------------------------------------
update public.perfiles_usuarios p
set calle_id = c.id
from public.catalogo_calles c
where p.calle_id is null
  and p.calle is not null
  and public.normalizar_calle(p.calle) = c.nombre_normalizado;

update public.invitaciones_qr i
set calle_id = c.id
from public.catalogo_calles c
where i.calle_id is null
  and i.direccion is not null
  and public.normalizar_calle(split_part(i.direccion, ',', 1)) = c.nombre_normalizado;

-- Backfill de alertas_calles usando alertas_oficiales.calles_objetivo (texto[])
insert into public.alertas_calles (alerta_id, calle_id)
select a.id, c.id
from public.alertas_oficiales a
cross join lateral unnest(coalesce(a.calles_objetivo, '{}')) as t(calle_txt)
join public.catalogo_calles c
  on public.normalizar_calle(t.calle_txt) = c.nombre_normalizado
on conflict do nothing;

commit;

-- ---------------------------------------------------------------------------
-- Consultas utiles para el sitio admin
-- ---------------------------------------------------------------------------
-- 1) Autocomplete:
-- select id, nombre_oficial
-- from public.catalogo_calles
-- where activa = true
--   and nombre_oficial ilike '%' || :q || '%'
-- order by nombre_oficial
-- limit 20;

-- 2) Crear invitacion usando calle_id:
-- insert into public.invitaciones_qr (
--   curp, numero_contrato, nombre_titular, direccion, colonia, calle_id
-- ) values (
--   :curp, :numero_contrato, :nombre_titular, :direccion, :colonia, :calle_id
-- );

-- 3) Crear alerta segmentada por calles (modelo robusto):
-- insert into public.alertas_oficiales (titulo, mensaje, activa, aplica_todas_calles)
-- values (:titulo, :mensaje, true, false)
-- returning id;
--
-- insert into public.alertas_calles (alerta_id, calle_id)
-- values (:alerta_id, :calle_id_1), (:alerta_id, :calle_id_2);
