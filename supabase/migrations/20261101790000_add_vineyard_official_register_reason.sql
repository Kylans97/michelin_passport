-- Renumbered 2026-11-25 (was 20261101760000) before anything applied it: the vineyard
-- claims migration 20261101780000 went to production first, so this
-- prepared file moved after it to keep filename order equal to apply order.
-- A fifth reason an estate is in the catalogue: an official register names
-- it as a producer of a protected designation (a Dutch BOB document, the
-- Flemish list of appellation producers, the Walloon list, the Luxembourg
-- sector's list). Written 2026-11-25 (branch claude/vineyards-global) for
-- batch 3, the Benelux estates. The number is sort order, not a date: named
-- after the highest migration on any branch (20261101750000, venue invite
-- links).
--
-- PREPARED -- NOT APPLIED until the product owner approves.
--
-- Why not 'official_classification': that is for rankings such as Bordeaux
-- 1855, VDP or Vinos de Pago, which the product owner wants in the Wine
-- Estates collection ("only the top recognised estates"). Being registered
-- to use a BOB recognises nothing, so it must not be mistaken for one.
--
-- Only the check constraint changes; no data, no grant, no function.

begin;

alter table public.vineyards drop constraint vineyards_inclusion_reason_check;
alter table public.vineyards add constraint vineyards_inclusion_reason_check
  check (inclusion_reason in (
    'worlds_50_best_vineyards', 'official_classification', 'official_register',
    'editorial_selection', 'member_request'));

commit;
