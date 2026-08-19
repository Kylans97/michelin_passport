-- Lucas de Jager / Jagers Catering — first curated Private Chef.
--
-- ============================================================
-- STATUS (Step 2B): APPLIED to production 2026-08-18.
-- Production private_chefs.id = 2e2089b0-f94d-46f5-923b-4ebf9135a5a1
-- selected_at set via a follow-up UPDATE immediately after this insert.
-- ============================================================
--
-- This file is a PROPOSAL only. It has not been run against production.
-- Profile-inclusion permission has been confirmed by Lucas de Jager
-- (PROFILE_PERMISSION: APPROVED_BY_CHEF — see PROFILE_RESEARCH_REPORT.md
-- §22 / evidence.csv). That permission covers inclusion only — it is not
-- treated as confirmation of the Parkheuvel claim specifically (see
-- below). See PROFILE_RESEARCH_REPORT.md for the full evidence review and
-- publication-readiness classification, and evidence.csv for the
-- per-field source/classification behind every value below.
--
-- Deliberately contains NO private_chef_restaurant_history insert:
-- the Parkheuvel provenance claim is sourced only from Jagers
-- Catering's own website, with no independent corroboration found
-- (see proposed_provenance.csv) — it does not meet this project's
-- evidence bar for a publishable canonical-provenance row. General
-- profile-inclusion permission does not change this — it is a separate
-- question from whether the specific employment claim is independently
-- verified. The chef profile is prepared to stand on its own without
-- provenance, exactly as PRIVATE_CHEFS.md's own Step 1 architecture
-- anticipates ("the first profile may be published without provenance
-- if necessary").
--
-- No Michelin/star value is written anywhere here — private_chefs has
-- no such column, by design (PRIVATE_CHEFS.md §10).
--
-- No private_chef_photos rows accompany this insert — no rights-cleared
-- image assets exist for Lucas/Jagers Catering anywhere in this
-- repository (Step 2B, confirmed by repository search). The existing
-- avatar/hero placeholder is the expected result, not a blocker.
--
-- MANDATORY PRE-FLIGHT (run first, separately, immediately before
-- applying — do not rely on this comment's own earlier check):
--
--   select id, slug, publication_status from public.private_chefs
--   where slug = 'lucas-de-jager';
--
-- Only proceed if that returns zero rows.

begin;

insert into public.private_chefs (
  slug, display_name, business_name, biography, personalization_note,
  home_city, home_country_code, service_area_text, travel_available,
  minimum_guests, maximum_guests, wine_pairing_available, wine_note,
  price_on_request, pricing_from, pricing_currency, pricing_unit,
  instagram_url, website_url, profile_image_url, languages,
  publication_status
) values (
  'lucas-de-jager',
  'Lucas de Jager',
  'Jagers Catering',
  'Lucas de Jager cooks under his own name through Jagers Catering, a private-dining kitchen based in Breda that travels throughout the Netherlands and Belgium. His approach favours a full-service, on-site format — from first conversation to final course — built around close attention to each host''s occasion and guests. Wine plays a central role in his menus, with pairings personally selected rather than drawn from a standard list.',
  'Every menu is shaped around your dietary needs, preferences, and the occasion itself, discussed with you in advance rather than assumed.',
  'Breda',
  'NL',
  'The Netherlands and Belgium',
  true,
  null,  -- minimum_guests: NOT_FOUND, see evidence.csv
  null,  -- maximum_guests: NOT_FOUND, see evidence.csv
  true,
  'Wines are personally selected by Lucas rather than drawn from a standard list — either a pairing for each course, with a short introduction at the table, or a single bottle chosen to suit the whole meal.',
  true,  -- price_on_request: no public pricing found
  null,  -- pricing_from
  null,  -- pricing_currency
  null,  -- pricing_unit
  'https://www.instagram.com/jagerscatering/',
  'https://jagers-catering.nl',
  null,  -- profile_image_url: no rights-cleared asset exists yet
  null,  -- languages: NOT_FOUND, deliberately not inferred
  -- 'published': per the task's own instruction, an explicitly approved
  -- chef inserts directly as published (published = selected, no
  -- separate flag). Change to 'draft' before applying if the reviewer
  -- wants a further staging period instead.
  'published'
);

commit;

-- selected_at is intentionally NOT set by this insert (column default
-- is NULL). If the reviewer wants it populated as audit-only metadata
-- (PRIVATE_CHEFS.md §14 — never read for visibility), run separately
-- immediately after, with the actual approval timestamp:
--
--   update public.private_chefs
--   set selected_at = now()
--   where slug = 'lucas-de-jager';
