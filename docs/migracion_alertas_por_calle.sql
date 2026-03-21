-- Migracion: soporte de alertas de suministro por calle
-- Ejecutar en Supabase SQL Editor.

begin;

alter table public.perfiles_usuarios
  add column if not exists calle varchar(160);

alter table public.alertas_oficiales
  add column if not exists aplica_todas_calles boolean not null default true,
  add column if not exists calles_objetivo text[] not null default '{}';

create index if not exists idx_alertas_oficiales_calles_objetivo
  on public.alertas_oficiales using gin (calles_objetivo);

commit;

-- Ejemplo: alerta global
-- insert into public.alertas_oficiales (titulo, mensaje, activa, aplica_todas_calles)
-- values ('Corte general', 'Suspension temporal en todo Bochil', true, true);

-- Ejemplo: alerta solo para calles objetivo
-- insert into public.alertas_oficiales (titulo, mensaje, activa, aplica_todas_calles, calles_objetivo)
-- values (
--   'Suministro programado',
--   'Habra suministro de 7:00 a 10:00 para las calles indicadas.',
--   true,
--   false,
--   array['Avenida Central', 'Calle Juarez']
-- );
