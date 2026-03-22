-- Migracion: habilitar actualizacion de email propio en perfiles_usuarios
-- Objetivo: sincronizar perfiles_usuarios.email con auth.users.email desde la app.

begin;

-- Asegura RLS habilitado
alter table public.perfiles_usuarios enable row level security;

-- Permiso de columna: permitir actualizar solo el campo email para usuarios autenticados
revoke update on public.perfiles_usuarios from authenticated;
grant update (email) on public.perfiles_usuarios to authenticated;

-- Politica RLS: cada usuario solo puede actualizar su propio perfil
-- (aunque el grant limite columnas a email).
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'perfiles_usuarios'
      and policyname = 'Actualizar email propio'
  ) then
    create policy "Actualizar email propio"
      on public.perfiles_usuarios
      for update
      using (auth.uid() = id)
      with check (auth.uid() = id);
  end if;
end $$;

commit;
