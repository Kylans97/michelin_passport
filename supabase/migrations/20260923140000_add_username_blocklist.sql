begin;

-- ============================================================
-- Username filter — reserved names + a basic hate-speech list.
-- ============================================================
--
-- One table so the list lives in exactly one place and can be extended
-- with a plain INSERT (dashboard SQL editor), no migration required:
create table public.blocked_username_terms (
  term text primary key
);

comment on table public.blocked_username_terms is
  'Lowercase terms/fragments a candidate username must not contain '
  '(substring match). Deliberately simple — a wordlist only ever '
  'catches the obvious cases; the report/block flow is the backstop '
  'for everything a fixed list misses, not this table. Add new rows '
  'directly (INSERT) — no code or migration needed to extend it.';

alter table public.blocked_username_terms enable row level security;
-- No policies at all: nobody needs to read this from the client (the
-- check happens server-side, inside a SECURITY DEFINER trigger/function
-- below), and the list itself is exactly the kind of thing that
-- shouldn't be readable by anon/authenticated — publishing it would
-- just be a cheat sheet for exactly the strings it's meant to block.

-- Reserved names. Substring match means a variant like "administrator",
-- "the_admin", or "adminmantelier" is caught for free — no need to
-- enumerate every spelling.
insert into public.blocked_username_terms (term) values
  ('admin'), ('support'), ('moderator'), ('mantelier'),
  ('help'), ('info'), ('official'), ('team');

-- Basic discriminatory/hateful terms (English + Dutch, given this
-- product's Benelux-first audience). Deliberately short list, and
-- deliberately NOT every term a fuller wordlist would include — see the
-- exclusions note below. This is a starting point the operator is
-- expected to extend, not a claim of completeness.
insert into public.blocked_username_terms (term) values
  ('nigger'), ('nigga'), ('faggot'), ('tranny'), ('retarded'),
  ('chink'), ('kike'), ('spick'), ('paki'),
  ('flikker'), ('mongool'), ('kanker'), ('kkk'), ('nazi');

-- Deliberately EXCLUDED, checked one by one for substring false-positive
-- risk before being left out (per explicit instruction: a term the
-- operator adds later is a smaller cost than blocking someone's real
-- name or an ordinary word):
--   'hoer'  (NL) -- 4-letter fragment, plausible collision inside longer
--                   Dutch compound words/surnames; excluded.
--   'kut'   (NL) -- 3-letter fragment, very common Dutch letter sequence,
--                   high collision risk; excluded.
--   'neger' (NL) -- real slur, but a live risk was not ruled out for
--                   this exact 5-letter fragment inside longer Dutch
--                   surnames; excluded pending a closer look, not
--                   forgotten.
--   'rape'  (EN) -- classic false-positive generator: substring of
--                   "grape", "drape", "therapist". Excluded as a bare
--                   fragment.
--   'coon'  (EN) -- substring of "raccoon", "cocoon", "tycoon". Excluded.
--   'dyke'  (EN) -- also an ordinary English word (embankment) and a
--                   real surname element ("Van Dyke"). Excluded.
--   'wop'   (EN) -- 3-letter fragment, generic enough to appear inside
--                   unrelated words/names; excluded.
--   'spic'  (EN) -- substring of "spice", "despicable". Excluded as a
--                   bare fragment (kept the less collision-prone 'spick'
--                   spelling above instead, still short -- worth a
--                   second look too, flagged, not fully confident).
--   'retard' (EN, bare) -- kept only the longer 'retarded' above; the
--                   shorter root risks matching inside compound English
--                   words more than the full word does.
-- None of this is a rigorous linguistic audit -- it's an editorial
-- judgment call under the "when in doubt, leave it out" instruction.
-- Revisit with real Dutch/English corpora if this list grows much
-- further.

-- ============================================================
-- Enforcement — one trigger, fires on both signup and later edits.
-- ============================================================
--
-- BEFORE INSERT OR UPDATE OF username on profiles covers both write
-- paths that ever set this column: handle_new_user()'s bootstrap INSERT
-- (Social Foundation Step 1) at signup, and ProfileRepository.
-- updateProfile's later UPDATE — both are real INSERT/UPDATE statements
-- against this table regardless of which code path issued them, so one
-- trigger here is genuinely the single enforcement point, not one of
-- two that could drift apart.
--
-- Custom SQLSTATE 'MT001' (Postgres reserves the first-letter-plus-
-- four-characters space for applications) so the Dart layer can
-- distinguish this from the pre-existing 23505 (taken) / 23514 (format)
-- cases with its own friendly message, instead of falling through to
-- the generic "Could not save changes" catch-all.
create function public.check_username_not_blocked()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.username is not null and exists (
    select 1 from public.blocked_username_terms t
    where new.username ilike '%' || t.term || '%'
  ) then
    raise exception 'That username is not allowed.'
      using errcode = 'MT001';
  end if;
  return new;
end;
$$;

create trigger profiles_username_not_blocked
  before insert or update of username on public.profiles
  for each row
  when (new.username is not null)
  execute function public.check_username_not_blocked();

-- ============================================================
-- username_available() — same check, for live typing feedback.
-- ============================================================

create or replace function public.username_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    candidate is not null
    and char_length(candidate) between 3 and 30
    and candidate ~ '^[a-z0-9]([a-z0-9]|[_.][a-z0-9])*$'
    and not exists (select 1 from public.profiles where username = candidate)
    and not exists (
      select 1 from public.blocked_username_terms t
      where candidate ilike '%' || t.term || '%'
    );
$$;

revoke execute on function public.username_available(text) from public;
grant  execute on function public.username_available(text) to anon, authenticated;

commit;
