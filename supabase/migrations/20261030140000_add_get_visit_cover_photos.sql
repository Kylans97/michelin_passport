-- One cover photo per visit, for Friend Profile's verdict rows.
--
-- Written 2026-10-30 (launch egress pass). NOT YET APPLIED — prepared for
-- review; apply with `supabase db push --linked` once approved.
--
-- Renamed 2026-10-30, before it was applied anywhere, from
-- 20261030120000: 20261030130000 (push notifications) was named after this
-- file but reached production first, so under its old name a fresh replay
-- would have run this one first while production ran it second. The two
-- touch no common object, but the filename is the replay order, so it now
-- sorts after the migration production already has.
--
-- Until now PhotoRepository.loadCoverPhotoUrlsForVisits selected EVERY
-- public photo of every visit it was given, newest first, and kept the
-- first per visit client-side. A visit has no photo maximum, so the rows
-- downloaded grew with every photo a friend ever added, to show one each.
-- This returns exactly that first photo per visit, server-side, with the
-- same ordering: taken_at desc NULLS LAST, which is what the client sent
-- (postgrest-dart's order() defaults to nullsFirst: false, i.e.
-- `order=taken_at.desc.nullslast` — not Postgres' own DESC default), plus
-- id as a deterministic tie-break the old query lacked.
--
-- SECURITY INVOKER, deliberately: photos_read RLS (owner, or a friend's
-- 'friends'-visibility visit — 20260814120000) applies to this exactly as
-- it did to the client's own select, so the function can't widen what any
-- caller sees. It is not SECURITY DEFINER, so CLAUDE.md's revoke rule does
-- not strictly apply; the revoke is still written, because anon has no
-- use for it and PUBLIC's auto-grant would otherwise hand it out.
--
-- The client keeps working before this is applied: it falls back to the
-- old query on PostgREST's PGRST202 (function not found).
--
-- photos had no index on visit_id at all; this lookup and
-- loadPhotosForVisit (eq visit_id, order taken_at desc) both read by it.

create index if not exists photos_visit_id_taken_at_idx
  on public.photos (visit_id, taken_at desc nulls last);

create or replace function public.get_visit_cover_photos(p_visit_ids uuid[])
returns table (visit_id uuid, storage_path text)
language sql
stable
security invoker
set search_path = ''
as $$
  select distinct on (p.visit_id) p.visit_id, p.storage_path
  from public.photos p
  where p.visit_id = any (p_visit_ids)
    and p.is_public
  order by p.visit_id, p.taken_at desc nulls last, p.id
$$;

revoke execute on function public.get_visit_cover_photos(uuid[]) from public, anon;
grant execute on function public.get_visit_cover_photos(uuid[]) to authenticated;
