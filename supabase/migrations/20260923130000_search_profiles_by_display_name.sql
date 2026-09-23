begin;

-- Tester feedback: searching Friends by a person's actual name found
-- nothing, because search_profiles only ever matched `username`
-- (someone searching "Kylan Scheepstra" got zero results, since that
-- account's username is "admin"). This extends the match to also
-- consider `display_name` — same is_discoverable/blocked-pair rules as
-- before, completely untouched, since this only widens *which column*
-- can satisfy the match, not the surrounding eligibility conditions.
--
-- Word-boundary matching on display_name, not a plain prefix-of-the-
-- whole-field match like username's: a name has more than one part a
-- person might search by (first name, or surname), and a plain
-- `display_name ilike query || '%'` would miss "Scheepstra" typed
-- against "Kylan Scheepstra". Splits display_name into words on the
-- (fixed, non-user-controlled) `\s+` pattern and prefix-matches the
-- query against each word individually with plain ILIKE — deliberately
-- NOT a regex built by concatenating the raw query into a pattern
-- string (`'(^|\s)' || query`), which would hand a search string
-- containing `(`, `.`, `*`, etc. straight to the regex engine and throw
-- on a malformed pattern (or, for a `~`-family injection more broadly,
-- do something other than a literal match). ILIKE's own wildcards
-- (`%`, `_`) remain live in the query here, same as the pre-existing
-- username match above — an accepted, unchanged risk, not a new one.
-- At current/near-term table size a full-column scan is a non-issue; a
-- pg_trgm index would only become relevant at a user count this app is
-- nowhere near.
--
-- CREATE OR REPLACE preserves the function's existing OID/ACL (grants)
-- since the signature (name + argument types) is unchanged — no
-- separate revoke/grant needed, but re-stated below anyway, defensively,
-- matching this file's own established precedent.
create or replace function public.search_profiles(query text)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  relationship_status text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    case
      when f.status is null then null
      when f.status = 'accepted' then 'accepted'
      when f.status = 'pending' and f.requester_id = auth.uid() then 'pending_sent'
      when f.status = 'pending' and f.addressee_id = auth.uid() then 'pending_received'
      when f.status = 'declined' then 'declined'
      else null
    end
  from public.profiles p
  left join public.friendships f
    on (f.requester_id = auth.uid() and f.addressee_id = p.id)
    or (f.addressee_id = auth.uid() and f.requester_id = p.id)
  where auth.uid() is not null
    and p.id <> auth.uid()
    and char_length(trim(query)) >= 2
    and (
      (p.username is not null and p.username ilike (trim(query) || '%'))
      or (
        p.display_name is not null
        and exists (
          select 1
          from unnest(regexp_split_to_array(p.display_name, '\s+')) as word
          where word ilike (trim(query) || '%')
        )
      )
    )
    and (f.status is null or f.status <> 'blocked')
    and (p.is_discoverable or f.status in ('accepted', 'pending'))
  order by p.username
  limit 20;
$$;

revoke execute on function public.search_profiles(text) from public;
grant  execute on function public.search_profiles(text) to authenticated;

commit;
