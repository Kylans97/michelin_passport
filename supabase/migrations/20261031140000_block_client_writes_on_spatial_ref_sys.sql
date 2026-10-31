-- Block client writes to PostGIS's spatial_ref_sys. Written 2026-10-31,
-- the follow-up the pre-launch security audit left open in
-- 20261031130000.
--
-- PostGIS is installed in public (restaurants.location / hotels.location
-- use it, so it can't simply be moved or dropped), and Supabase grants
-- anon and authenticated full rights on its spatial_ref_sys table, which
-- has no RLS. Through the public API anyone could therefore insert,
-- change or delete coordinate-system rows — deleting SRID 4326 would
-- break every geography lookup in the app.
--
-- Revoking those rights was tried first and has no effect: the table is
-- owned, and the grants were made, by supabase_admin, which the role
-- running migrations is not. That role does hold TRIGGER on the table,
-- so statement-level triggers refuse INSERT/UPDATE/DELETE/TRUNCATE when
-- the calling role is anon or authenticated. Reads are untouched;
-- PostGIS functions running as the caller still read the table, and
-- service_role/postgres (and PostGIS upgrades, run as supabase_admin)
-- can still write.
--
-- block_client_spatial_ref_sys_writes is a plain trigger function, not
-- SECURITY DEFINER: it must see the caller's own role in current_user.
-- Its execute grant is revoked from public and anon all the same;
-- a trigger fires regardless of the caller's EXECUTE privilege.

begin;

create function public.block_client_spatial_ref_sys_writes()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('anon', 'authenticated') then
    raise exception 'spatial_ref_sys is read-only for clients'
      using errcode = '42501';
  end if;
  return null;
end;
$$;

revoke execute on function public.block_client_spatial_ref_sys_writes() from public, anon;

create trigger spatial_ref_sys_block_client_writes
  before insert or update or delete on public.spatial_ref_sys
  for each statement
  execute function public.block_client_spatial_ref_sys_writes();

create trigger spatial_ref_sys_block_client_truncate
  before truncate on public.spatial_ref_sys
  for each statement
  execute function public.block_client_spatial_ref_sys_writes();

commit;
