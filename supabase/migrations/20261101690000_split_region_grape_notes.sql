-- Three fields for what a grape is in a region, beside the one free note.
-- Asked for by the product owner on 2026-11-22, after the audit of every
-- region grape note (https://claude.ai/artifact/XuRXST3Vjxow9RhL5bqopi):
-- "Kies voor drie velden (naam daar, rol, smaak daar)". Written 2026-11-22
-- on claude/grapes-by-region; the number is sort order: the next after
-- 20261101680000, the highest on any branch.
--
-- The audit found the one `local_note` doing four jobs at once: the name
-- the grape goes by there, its role (main grape, share, minimum
-- percentage), a wine style, and only in 55 of 434 notes how it tastes
-- there. The region sheet is to show grape names only, and the grape
-- screen opened from a region to lead with that region's own words, each
-- in its own place:
--   local_name  the name on labels there ("Tinto Fino", "Fendant")
--   role_note   its place there: role, rules, styles made, where it grows
--   taste_note  how it tastes there, only when a source says so
--
-- `local_note` stays. Builds up to 1.9.0 (48) read it and show it on the
-- region sheet, so it is kept correct, not left stale: the data round that
-- fills these columns also rewrites it from them. It is removed only once
-- no build that reads it is in use (CLAUDE.md, three steps).
--
-- Columns only: no function, no policy change. The table's existing
-- public read policy and grants cover them.

alter table public.wine_region_grapes
  add column local_name text,
  add column role_note  text,
  add column taste_note text;

comment on column public.wine_region_grapes.local_name is
  'The name this grape goes by on labels in this region, when it differs.';
comment on column public.wine_region_grapes.role_note is
  'Its place in this region: role, rules, styles made, where it grows.';
comment on column public.wine_region_grapes.taste_note is
  'How wine from this grape tastes in this region, only from a source.';
comment on column public.wine_region_grapes.local_note is
  'Read by builds up to 1.9.0 (48). Kept as the three fields joined; to be '
  'removed once no build reads it.';
