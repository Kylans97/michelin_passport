-- Wine regions drawn as their real shape on the globe, instead of a soft
-- patch around a point. Written 2026-11-20 (product owner: "Build the
-- outlines from each region's official list of communes, merged and
-- simplified, with the source stored per region").
--
-- outline is the union of the municipalities the region's official
-- specification lists (INAO's commune lists for France, the pliegos,
-- disciplinari and legal texts elsewhere), on Eurostat GISCO LAU 2024
-- boundaries, simplified to about 1 km by
-- scripts/build_wine_region_outlines.py. Never traced by hand. The commune
-- lists and their sources live in
-- supabase/data/enrichment/wine_regions/outlines/communes/.
--
-- Shape: a JSON array of polygons; each polygon an array of rings (outer
-- ring first, then holes); each ring an array of [longitude, latitude].
-- NULL means no outline yet: the app falls back to the patch around
-- latitude/longitude/radius_km, so a region can be published before its
-- outline is.
--
-- Additive only: the shipped build selects named columns, so new nullable
-- columns change nothing for it. Covered by the existing RLS policy and
-- select grant on wine_regions. No function is created, so there is no
-- execute grant to revoke.

alter table public.wine_regions
  add column outline jsonb,
  add column outline_source text,
  add column outline_source_url text;

alter table public.wine_regions
  add constraint wine_regions_outline_is_array
    check (outline is null or jsonb_typeof(outline) = 'array'),
  add constraint wine_regions_outline_sourced
    check (outline is null or outline_source_url is not null);

comment on column public.wine_regions.outline is
  'Polygons as [[[lng, lat], ...] rings, outer first], the union of the '
  'municipalities in the official specification, simplified to ~1 km. '
  'Built by scripts/build_wine_region_outlines.py; never hand-traced.';
comment on column public.wine_regions.outline_source is
  'How the outline was made: which list, which boundaries, which tolerance.';
comment on column public.wine_regions.outline_source_url is
  'The official commune list(s) the outline was built from.';
